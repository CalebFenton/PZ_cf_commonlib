-- Item filters on placed objects' containers (a container's AcceptItemFunction). A filter is
-- neither saved with its container nor sent, and a server's sendObjectChange(CONTAINERS) replaces
-- the clients' containers without theirs (IsoObject.loadChange), so every side sets it on its own
-- copy: as the object loads, as it is added, before anything is dropped in through the loot
-- window, and for an object built in code that nothing announces (Containers.adopt).

local Tiles = require "cf_commonlib/Tiles"

local Containers = {}

-- Each filter: { isObject, accept }.
local filters = {}

-- Gives `container` the filter `accept` names for it, unless it has one.
local function adoptContainer(container, accept)
    local path = type(accept) == "table" and accept[container:getType()] or accept
    if type(path) == "string" and container:getAcceptItemFunction() == nil then
        container:setAcceptItemFunction(path)
    end
end

local function adoptWith(filter, isoObject)
    for i = 0, isoObject:getContainerCount() - 1 do
        adoptContainer(isoObject:getContainerByIndex(i), filter.accept)
    end
end

--- Gives the containers of `isoObject` the filters Containers.filter declared for it, leaving any
--- filter a container has. For an object built in code before its first load.
function Containers.adopt(isoObject)
    for _, filter in ipairs(filters) do
        if filter.isObject(isoObject) then
            adoptWith(filter, isoObject)
        end
    end
end

--- Has every side set the filters of the containers of the objects of the tiles `spec.sprites`
--- (names) that `spec.isObject(isoObject)` accepts. `spec.accept` is the path, from the global
--- table, of the filter function (ItemContainer.isItemAllowed finds it by that name), for every
--- container of the object; or a table of such paths by container type.
function Containers.filter(spec)
    local filter = { isObject = spec.isObject, accept = spec.accept }
    table.insert(filters, filter)
    Tiles.onLoad(spec.sprites, function(isoObject)
        adoptWith(filter, isoObject)
    end, { matches = spec.isObject, added = true })
end

Events.OnRefreshInventoryWindowContainers.Add(function(page, state)
    if state ~= "buttonsAdded" then return end
    for _, button in ipairs(page.backpacks or {}) do
        local container = button.inventory
        local parent = container and container:getParent()
        if parent then
            for _, filter in ipairs(filters) do
                if filter.isObject(parent) then
                    adoptContainer(container, filter.accept)
                end
            end
        end
    end
end)

return Containers
