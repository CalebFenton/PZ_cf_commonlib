-- The authority's side of features kept in a Global Object System: a system per feature that saves
-- each object's record with the world, runs every record each ten minutes loaded or not, and sends
-- every client its summary; a base for the records; and their side of the jobs players do at them
-- (Jobs.perform). Each feature is declared once (GlobalObjects.declare), which every side reads.
--
-- A save keeps each system by its SYSTEM_NAME and each record by the fields its class's
-- SAVED_FIELDS names, so a mod's names for them must never change.

if isClient() then return end

require "Map/SGlobalObjectSystem"
require "Map/SGlobalObject"
local Clock = require "cf_commonlib/Clock"
local Containers = require "cf_commonlib/Containers"
local Tables = require "cf_commonlib/Tables"
local Tiles = require "cf_commonlib/Tiles"

local ObjectSystem = {}

--- The base of a feature's records. A record is its global object's table, so the fields its
--- class's SAVED_FIELDS names are saved with the world, with lastHour, when time last reached it,
--- which the system adds. A class defines advance(hours), what the time does to it; afterChange(),
--- which shows and tells what changed; and buildSummary(), what every client keeps of it. A class
--- whose time can't be told while parts of it are unloaded overrides catchUp() to wait for them.
local Object = SGlobalObject:derive("cf_commonlib_Object")
ObjectSystem.Object = Object

--- Brings the record up to now: what the game hours since it last caught up did to it, at most
--- Clock.hoursSince's longest pass.
function Object:catchUp()
    self:advance(Clock.hoursSince(self))
end

--- Brings the record up to now, then shows and tells what changed.
function Object:update()
    self:catchUp()
    self:afterChange()
end

--- Whether the record is still its system's: removing its object takes the record away and clears
--- its x, y, z.
function Object:isCurrent()
    return self.x ~= nil and self.luaSystem:getLuaObjectAt(self.x, self.y, self.z) == self
end

--- Sends the clients the summary, if it changed.
function Object:sendSummary()
    local summary = self:buildSummary()
    if not Tables.sameValue(summary, self.summary) then
        self.summary = summary
        self:updateOnClient()
    end
end

local function listed(list, value)
    for _, entry in ipairs(list) do
        if entry == value then
            return true
        end
    end
    return false
end

--- A system class <prefix><name>System of `owner`'s feature (owner.feature, GlobalObjects.declare)
--- keeping its records in class `Object`; owner gets serverSystem. Each record is saved by
--- Object.SAVED_FIELDS, to which this adds lastHour, stamped now on a new record, and sends the
--- clients its summary. Not registered: ObjectSystem.define does that, or the mod.
function ObjectSystem.deriveSystem(owner, Object)
    local feature = owner.feature
    local System = SGlobalObjectSystem:derive(feature.prefix .. feature.name .. "System")
    System.owner = owner
    if not listed(Object.SAVED_FIELDS, "lastHour") then
        table.insert(Object.SAVED_FIELDS, "lastHour")
    end

    function System:new()
        return SGlobalObjectSystem.new(self, owner.SYSTEM_NAME)
    end

    function System:initSystem()
        owner.serverSystem = self
        self.system:setObjectModDataKeys(Object.SAVED_FIELDS)
        self.system:setObjectSyncKeys({ "summary" })
    end

    -- The summary isn't saved; each record gets it before any client connects.
    function System:initLuaObjects()
        SGlobalObjectSystem.initLuaObjects(self)
        for i = 1, self:getLuaObjectCount() do
            local record = self:getLuaObjectByIndex(i)
            record.summary = record:buildSummary()
        end
    end

    function System:isValidIsoObject(isoObject)
        return feature.isObject(isoObject)
    end

    -- A saved record has its lastHour; a new one's time starts now.
    function System:newLuaObject(globalObject)
        local record = Object:new(self, globalObject)
        record.lastHour = record.lastHour or Clock.now()
        return record
    end

    return System
end

--- Defines and registers the system of `owner`'s feature (ObjectSystem.deriveSystem), whose
--- records are `spec.Object`'s (an ObjectSystem.Object), run each ten minutes and loaded as their
--- tiles load. `spec.loadOnCreate`: System.OnCreate(params), a build menu OnCreate that gives the
--- built tile its record. Returns the class.
function ObjectSystem.define(owner, spec)
    local System = ObjectSystem.deriveSystem(owner, spec.Object)

    if spec.loadOnCreate then
        -- On the authority: the build adds the tile to the square before this runs and sends it to
        -- the clients after, and nothing else announces a built entity to the system or the
        -- container filters. The record may add containers, which get theirs too.
        function System.OnCreate(params)
            local thumpable = params.thumpable
            if thumpable and thumpable:getSquare() then
                System.instance:loadIsoObject(thumpable)
                Containers.adopt(thumpable)
            end
        end
    end

    -- Every record, loaded or not, each ten minutes; a pass removes none.
    local function updateAll()
        local self = System.instance
        for i = 1, self:getLuaObjectCount() do
            self:getLuaObjectByIndex(i):update()
        end
    end

    Tiles.onLoad(owner.feature.sprites, function(isoObject)
        System.instance:loadIsoObject(isoObject)
    end, { matches = owner.feature.isObject, first = true })
    Events.EveryTenMinutes.Add(updateAll)
    SGlobalObjectSystem.RegisterSystemClass(System)
    return System
end

--- The authority's side of the jobs at a feature's tiles (a site of Jobs.perform), whose records
--- are `owner`'s: each job works on the record of the tile worked at, brought up to now first, and
--- `DO[job](character, record, row, isoObject, with, materials)` does it, returning true when it
--- was done. A tile without a record has nothing for a job to work on. Once done or not, the record
--- shows and tells what changed, unless the job took it away.
function ObjectSystem.jobSite(owner, DO)
    return {
        open = function(isoObject)
            local record = owner.recordOf(isoObject)
            if record then
                record:catchUp()
            end
            return record
        end,
        act = function(character, job, record, row, isoObject, with, materials)
            return record ~= nil and DO[job](character, record, row, isoObject, with, materials)
        end,
        tell = function(record)
            if record and record:isCurrent() then
                record:afterChange()
            end
        end,
    }
end

return ObjectSystem
