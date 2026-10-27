-- The client's side of the features the authority keeps in a Global Object System: the system that
-- receives each object's summary (also in single player, where it loops back).

require "Map/CGlobalObjectSystem"
require "Map/CGlobalObject"

local ClientObjects = {}

--- Defines and registers the client system of `owner`'s feature (owner.feature,
--- GlobalObjects.declare), which the authority keeps in a Global Object System
--- (ObjectSystem.define): classes <prefix>Client<name> and <prefix>Client<name>System; owner gets
--- clientSystem. Returns the system class.
function ClientObjects.define(owner)
    local feature = owner.feature
    local ClientObject = CGlobalObject:derive(feature.prefix .. "Client" .. feature.name)
    local System = CGlobalObjectSystem:derive(feature.prefix .. "Client" .. feature.name .. "System")

    function System:new()
        return CGlobalObjectSystem.new(self, owner.SYSTEM_NAME)
    end

    function System:initSystem()
        owner.clientSystem = self
    end

    function System:isValidIsoObject(isoObject)
        return feature.isObject(isoObject)
    end

    function System:newLuaObject(globalObject)
        return ClientObject:new(self, globalObject)
    end

    -- The server sends no system commands, and vanilla's default raises an error for any command.
    function System:OnServerCommand(command, args)
    end

    CGlobalObjectSystem.RegisterSystemClass(System)
    return System
end

return ClientObjects
