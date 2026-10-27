-- A feature the authority keeps in a Global Object System: who it is, which both sides' systems
-- read (server/cf_commonlib/ObjectSystem.lua and client/cf_commonlib/ClientObjects.lua, which set
-- owner.serverSystem and owner.clientSystem), and what every side reads of it: its summary, which
-- the server sends every client, and on the authority its record.

local Containers = require "cf_commonlib/Containers"

local GlobalObjects = {}

--- Declares `owner` (a feature's shared module, with SYSTEM_NAME) a Global Object System feature.
--- `identity`, kept as owner.feature: prefix and name, which the systems' class names are made of
--- and saves keep; isObject(isoObject), whether an object is one; sprites, the names of its tiles;
--- decorate(summary, isoObject), if given, adds to each summary read what this side's copies of
--- the object's containers hold now (every side has those copies, and the summary is only as
--- fresh as the authority's last pass, so values that follow from the containers aren't sent);
--- accept, if given, its containers' filters (Containers.filter). The mod may add its own fields.
---
--- Adds to `owner`:
--- owner.objectAt(x, y, z), this side's table of the object there: its record on the authority,
--- else this client's copy; nil for none. Single player reads the record, whose summary the
--- client's copy gets a tick later.
--- owner.each(fn), fn(object) for each such table, until it returns true;
--- owner.summaryAt(x, y, z) and owner.summaryOf(isoObject), the summary this side has, or nil;
--- owner.recordAt(x, y, z) and owner.recordOf(isoObject), its record on the authority, loaded or
--- not, nil elsewhere;
--- owner.currentSummary(isoObject), the summary as this side knows it now: the authority builds it
--- from its record, which a job may have changed since the last summary went out.
function GlobalObjects.declare(owner, identity)
    owner.feature = identity
    local decorate = identity.decorate
    if identity.accept then
        Containers.filter({ sprites = identity.sprites, isObject = identity.isObject, accept = identity.accept })
    end

    local function system()
        local sideSystem = owner.serverSystem or owner.clientSystem
        return sideSystem and sideSystem.system
    end

    function owner.objectAt(x, y, z)
        local objects = system()
        local globalObject = objects and objects:getObjectAt(x, y, z)
        return globalObject and globalObject:getModData() or nil
    end

    function owner.each(fn)
        local objects = system()
        for i = 0, (objects and objects:getObjectCount() or 0) - 1 do
            if fn(objects:getObjectByIndex(i):getModData()) then
                return
            end
        end
    end

    -- `summary`, the system's own table, which the authority replaces only when it changes; or a
    -- decorated copy of it, when the feature decorates and the object is here.
    local function decorated(summary, isoObject)
        if not (summary and decorate and isoObject) then
            return summary
        end
        local copy = {}
        for key, value in pairs(summary) do
            copy[key] = value
        end
        decorate(copy, isoObject)
        return copy
    end

    function owner.summaryOf(isoObject)
        local object = owner.objectAt(isoObject:getX(), isoObject:getY(), isoObject:getZ())
        return decorated(object and object.summary, isoObject)
    end

    function owner.summaryAt(x, y, z)
        local object = owner.objectAt(x, y, z)
        return decorated(object and object.summary, object and decorate and object:getIsoObject())
    end

    function owner.recordAt(x, y, z)
        local serverSystem = not isClient() and owner.serverSystem
        return serverSystem and serverSystem:getLuaObjectAt(x, y, z) or nil
    end

    function owner.recordOf(isoObject)
        return owner.recordAt(isoObject:getX(), isoObject:getY(), isoObject:getZ())
    end

    function owner.currentSummary(isoObject)
        local record = owner.recordOf(isoObject)
        if not record then
            return owner.summaryOf(isoObject)
        end
        return decorated(record:buildSummary(), isoObject)
    end
end

return GlobalObjects
