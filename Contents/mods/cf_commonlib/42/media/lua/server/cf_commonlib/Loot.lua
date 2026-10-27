-- Putting a mod's items into the game's loot lists at weights the save's options scale.
--
-- The save's sandbox options aren't loaded yet when a mod's files run, nor during the distribution
-- merge events: IsoWorld.init fires those, then loads the options, then parses the tables, and
-- only then fires OnInitGlobalModData. So each mod registers its items (Loot.register), and this
-- puts them all in there, then has ItemPickerJava parse the tables again once, as it reads the Lua
-- tables only when it parses them. A multiplayer client fills no containers, so it puts none in.

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

-- Puts `fullType` into the items list of each of `entries` at the entry's weight times
-- `multiplier`, replacing what an earlier call put there, so loading another save in the same
-- session doesn't pile entries up. A multiplier of 0 leaves the item out altogether: a zero weight
-- would still spawn through the zombie density bonus, which ItemPickerJava adds rather than
-- multiplies. A list the game lacks is skipped with a line in the log naming `modName`.
local function place(modName, fullType, entries, multiplier)
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

--- Appends to `entries` (a new table when nil) a loot entry { weight, reference } for each
--- reference of each of `groups` ({ weight, { reference, ... } } each), in order, and returns
--- `entries`.
function Loot.entries(groups, entries)
    entries = entries or {}
    for _, group in ipairs(groups) do
        for _, reference in ipairs(group[2]) do
            table.insert(entries, { group[1], reference })
        end
    end
    return entries
end

-- Each registration: { items, apply }.
local registered = {}

--- Has each of `items` ({ fullType, entries = { { weight, reference }, ... } } each) put in its
--- lists at each entry's weight times `multiplierOf(item)`, read once the save's options are
--- loaded, before the tables are parsed again; replacing what an earlier load put there, and
--- leaving out an item whose multiplier is 0. `modName` names the mod in the log line of a list the
--- game lacks. Returns the function that puts them in, for a caller that changes the options; the
--- same `items` registered again are put in once.
function Loot.register(modName, items, multiplierOf)
    for _, known in ipairs(registered) do
        if known.items == items then
            return known.apply
        end
    end
    local function apply()
        for _, item in ipairs(items) do
            place(modName, item.fullType, item.entries, multiplierOf(item))
        end
    end
    table.insert(registered, { items = items, apply = apply })
    return apply
end

Events.OnInitGlobalModData.Add(function()
    if isClient() then
        return
    end
    for _, known in ipairs(registered) do
        known.apply()
    end
    ItemPickerJava.Parse()
end)

return Loot
