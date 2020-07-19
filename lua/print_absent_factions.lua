local helper = wesnoth.require("lua/helper.lua")
local result = {}

-- split input string with provided separator
function split(str, separator)
    local parts = {}
    local pattern = string.format("([^%s]+)", separator)
    str:gsub(pattern, function(c) parts[#parts + 1] = c end)
    return parts
end

-- normalization means sorting recruit list in alphabetical order
-- Wesnoth APIs don't guarantee the recruit list order
-- normalization is required to compare recruit lists returned by different APIs
function normalize_recruit_table(recruit_list_table)
    table.sort(recruit_list_table)
    return table.concat(recruit_list_table, ",")
end

function normalize_recruit_list(recruit_list_str)
    local recruit_list_table = split(recruit_list_str, ",")
    return normalize_recruit_table(recruit_list_table)
end

result.print = function(args)
    local absent_factions = {}
    local recruit_list_to_faction_id = {}
    local faction_id_to_name = {}

    -- first of all fill this table with all possible factions
    for faction in helper.child_range(wesnoth.game_config.era, "multiplayer_side") do
        -- exclude random faction definition
        if not faction.random_faction then
            local faction_id = tostring(faction.id)
            absent_factions[faction_id] = true

            -- store the faction id - name mapping, since the name is translatable string
            -- and we can't rely on in, especially considering we will sort those values alphabetically later on
            faction_id_to_name[faction_id] = tostring(faction.name)

            -- store the recruit list - faction id mapping for the map picker,
            -- since it overrides faction id to "Custom"
            if faction.recruit ~= nil and faction.recruit ~= "" then
                local recruit_list = normalize_recruit_list(faction.recruit)
                recruit_list_to_faction_id[recruit_list] = faction_id
            end
        end
    end

    -- mark existing factions with false value
    for _, side in ipairs(wesnoth.sides) do
        -- exclude hidden sides
        if not side.hidden then
            local faction_id = tostring(side.faction)
            -- workaround for the map picker, since it overrides faction id to "Custom"
            if faction_id == "Custom" then
                local recruit_list = normalize_recruit_table(side.recruit)
                local faction_id_by_recruits = recruit_list_to_faction_id[recruit_list]
                -- may be nil, e.g. in ANL
                if faction_id_by_recruits ~= nil then
                    faction_id = faction_id_by_recruits
                end
            end
            absent_factions[faction_id] = false
        end
    end

    -- convert absent factions table to array
    local absent_factions_array = {}
    local i = 1
    for faction_id, is_absent in pairs(absent_factions) do
         if is_absent then
            absent_factions_array[i] = faction_id
            i = i + 1
         end
    end

    -- sort it alphabetically, since LUA doesn't guarantee table (set) ordering
    -- and then finally replace faction ids with names
    table.sort(absent_factions_array)
    for i = 1, #absent_factions_array do
        absent_factions_array[i] = faction_id_to_name[absent_factions_array[i]]
    end

    -- choose n of absent factions to show
    local absent_factions_to_show = {}
    local n = math.min(args.value, #absent_factions_array)
    for i = 1, n do
        local random_index = wesnoth.random(#absent_factions_array)
        table.insert(absent_factions_to_show, absent_factions_array[random_index])
        table.remove(absent_factions_array, random_index)
    end

    -- create and print the message
    local title = "Absent Factions"
    local message
    if n == 0 then
        message = "All possible factions are present in this game"
    elseif n == 1 then
        message = "There is no " .. absent_factions_to_show[1] .. " in this game"
    else
        message = "There are no " .. table.concat(absent_factions_to_show, ", ", 1, #absent_factions_to_show - 1)
        message = message .. " and " .. absent_factions_to_show[#absent_factions_to_show] .. " in this game"
    end
    wesnoth.show_popup_dialog(title, message)
    wesnoth.message(title, message)
end
return result
