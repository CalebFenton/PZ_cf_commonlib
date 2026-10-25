-- The authority's side of features kept in a Global Object System: a system per feature that saves
-- each object's record with the world, runs every record each ten minutes loaded or not, and sends
-- every client its summary; a base for the records; and their side of the jobs players do at them
-- (Jobs.perform). Each side reads them through the accessors of GlobalObjects.addAccessors.
--
-- A save keeps each system by its SYSTEM_NAME and each record by the fields its class's
-- SAVED_FIELDS names, so a mod's names for them must never change.

if isClient() then return end

require "Map/SGlobalObjectSystem"
require "Map/SGlobalObject"
local Clock = require "cf_commonlib/Clock"
local Tables = require "cf_commonlib/Tables"

local ObjectSystem = {}

--- The base of a feature's records. A record is its global object's table, so the fields its
--- class's SAVED_FIELDS names are saved with the world. A class defines advance(hours), what the
--- time does to it; afterChange(), which shows and tells what changed; and buildSummary(), what
--- every client keeps of it. A class whose time can't be told while parts of it are unloaded
--- overrides catchUp() to wait for them.
local Object = SGlobalObject:derive("cf_commonlib_Object")
ObjectSystem.Object = Object

--- Brings the record up to now: what the game hours since it last caught up did to it, at most its
--- system's longestPass.
function Object:catchUp()
    self:advance(Clock.hoursSince(self, self.luaSystem.longestPass))
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

--- A system class <spec.prefix><spec.name>System keeping the records of `spec.owner` (its shared
--- module: SYSTEM_NAME; it gets serverSystem, for GlobalObjects' accessors) in class `spec.Object`,
--- for the isoObjects `spec.isObject` says are its: each record is saved by Object.SAVED_FIELDS and
--- sends clients its summary. Not registered: ObjectSystem.define does that, or the mod.
function ObjectSystem.deriveSystem(spec)
    local System = SGlobalObjectSystem:derive(spec.prefix .. spec.name .. "System")
    System.owner = spec.owner

    function System:new()
        return SGlobalObjectSystem.new(self, spec.owner.SYSTEM_NAME)
    end

    function System:initSystem()
        spec.owner.serverSystem = self
        self.system:setObjectModDataKeys(spec.Object.SAVED_FIELDS)
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
        return spec.isObject(isoObject)
    end

    function System:newLuaObject(globalObject)
        return spec.Object:new(self, globalObject)
    end

    return System
end

--- Defines and registers a feature's system (ObjectSystem.deriveSystem), whose records are
--- ObjectSystem.Object's, run each ten minutes and loaded as their tiles load. `spec` adds:
--- sprites, its tiles' names; loadPriority, the mod's for them (MapObjects.OnLoadWithSprite keeps
--- one function per sprite and priority); longestPass, the most game hours one catch-up counts, as
--- a save loaded after the clock jumped would otherwise make up days at once; and loadOnCreate,
--- for System.OnCreate(params), a build menu OnCreate that gives the built tile its record. Returns
--- the class.
function ObjectSystem.define(spec)
    local System = ObjectSystem.deriveSystem(spec)
    System.longestPass = spec.longestPass

    if spec.loadOnCreate then
        -- On the authority: the build adds the tile to the square before this runs and sends it to
        -- the clients after, and nothing else announces a built entity to the system.
        function System.OnCreate(params)
            local thumpable = params.thumpable
            if thumpable and thumpable:getSquare() then
                System.instance:loadIsoObject(thumpable)
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

    local function load(isoObject)
        if spec.isObject(isoObject) then
            System.instance:loadIsoObject(isoObject)
        end
    end
    for _, name in ipairs(spec.sprites) do
        MapObjects.OnLoadWithSprite(name, load, spec.loadPriority)
    end
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
