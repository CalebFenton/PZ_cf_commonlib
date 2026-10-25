-- Putting a mod's items into the game's loot lists at weights the save's options scale.
--
-- The save's sandbox options aren't loaded yet when a mod's files run, nor during the distribution
-- merge events: IsoWorld.init fires those, then loads the options, then parses the tables, and
-- only then fires OnInitGlobalModData. So each mod registers what puts its entries in
-- (Loot.register), and this runs them all there, then has ItemPickerJava parse the tables again
-- once, as it reads the Lua tables only when it parses them. A multiplayer client fills no
-- containers, so it runs none.

require "Items/Distributions"
require "Items/ProceduralDistributions"
require "Vehicles/VehicleDistributions"

local Loot = {}

-- The items-list holder each prefix of a list reference names, by the name after the prefix. Read
-- as they are when asked: other mods may replace the tables while the game loads.
local LIST_HOLDERS = {
    -- A ProceduralDistributions list, or "<list>.junk" for its junk.
    proc = function(name)
        local lists = ProceduralDistributions.list
        local listName = string.match(name, "^([^.]+)%.junk$")
        if listName then
            return lists[listName] and lists[listName].junk
        end
        return lists[name]
    end,
    veh = function(name)
        return VehicleDistributions[name]
    end,
    -- A dotted path into SuburbsDistributions.
    sub = function(name)
        local holder = SuburbsDistributions
        for part in string.gmatch(name, "[^.]+") do
            holder = type(holder) == "table" and holder[part] or nil
        end
        return holder
    end,
}

--- The loot table a "proc:", "veh:" or "sub:" reference names, the one whose `items` the
--- reference's entries go into ("proc:<list>.junk": the list's junk table), or nil if the game has
--- no such table.
---@param reference string
---@return table?
function Loot.resolveTable(reference)
    local prefix, name = string.match(reference, "^(%a+):(.+)$")
    local holderOf = LIST_HOLDERS[prefix]
    local holder = holderOf and holderOf(name)
    return type(holder) == "table" and holder or nil
end

--- The items list a "proc:", "veh:" or "sub:" reference names, or nil if the game has no such list.
---@param reference string
---@return table?
function Loot.resolveItemList(reference)
    local holder = Loot.resolveTable(reference)
    return holder and holder.items or nil
end

-- Items lists are flat name, weight pairs.
local function unlist(items, fullType)
    for i = #items - 1, 1, -2 do
        if items[i] == fullType then
            table.remove(items, i + 1)
            table.remove(items, i)
        end
    end
end

--- Puts `fullType` into the items list of each of `entries` ({ weight, reference } each) at the
--- entry's weight times `multiplier`, replacing what an earlier call put there, so loading another
--- save in the same session doesn't pile entries up. A multiplier of 0 leaves the item out
--- altogether: a zero weight would still spawn through the zombie density bonus, which
--- ItemPickerJava adds rather than multiplies. A list the game lacks is skipped with a line in the
--- log naming `modName`.
function Loot.place(modName, fullType, entries, multiplier)
    for _, entry in ipairs(entries) do
        local items = Loot.resolveItemList(entry[2])
        if items then
            unlist(items, fullType)
            if multiplier > 0 then
                table.insert(items, fullType)
                table.insert(items, entry[1] * multiplier)
            end
        else
            print(modName .. ": missing loot list " .. entry[2] .. " for " .. fullType .. ", skipped")
        end
    end
end

local APPLIERS = {}

--- Has `apply()` put a mod's entries in (Loot.place) once the save's options are loaded, before
--- the tables are parsed again. A function registered again is run once.
function Loot.register(apply)
    for _, known in ipairs(APPLIERS) do
        if known == apply then return end
    end
    table.insert(APPLIERS, apply)
end

Events.OnInitGlobalModData.Add(function()
    if isClient() then
        return
    end
    for _, apply in ipairs(APPLIERS) do
        apply()
    end
    ItemPickerJava.Parse()
end)

return Loot
