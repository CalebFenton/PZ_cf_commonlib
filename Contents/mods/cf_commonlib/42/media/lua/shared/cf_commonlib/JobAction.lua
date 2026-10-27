-- The base of hands-on jobs at a world object or a vehicle. In multiplayer the client runs start()
-- and perform(), and the server rebuilds the action from new()'s parameters and runs complete();
-- single player runs both. NetTimedAction finds a job class by its Type among the globals and
-- reads the parameter names off the class's own `new`, so each job class is a global the mod
-- names, derived as `X = X or JobAction:derive("X")` so a reloaded file keeps the class the
-- queue's actions hold, with a `new` of its own (JobAction.forFeatures gives one). A class gives:
-- - REACH: how far from the middle of the target's square, on each axis, the character may work,
--   unless reach() says otherwise.
-- - TOO_DARK: the translation key a job that needs light (its row's `light`) shows in the dark.
-- - target(): the object or vehicle worked at.
-- - row(): the job's row: `light`; `metabolics`, the exertion it keeps the character at; how it
--   looks: `begin(self)`, which starts its animation, else `anim`, else the "Loot" reach, with
--   LootPosition `position` ("Low" for the reach unless it says); `sound` while it runs and
--   `doneSound` once done.
-- - units(): its length in action units.
-- - keeps(): what the job needs from moment to moment, cheap enough for isValid to ask every tick.
--   These are what another player or the world can take away mid-job, and the character's own
--   copy of the world shows them, so a multiplayer client asks them too.
-- - canPerform(): every rule of the job, as this side knows it.
-- - findItems(): looks the inventory items the job works with up again by their IDs.
-- - REPORTS_LOOT, if set: the "Loot" reach also reports EventLootItem.

require "TimedActions/ISBaseTimedAction"
local Squares = require "cf_commonlib/Squares"
local Clock = require "cf_commonlib/Clock"
local Jobs = require "cf_commonlib/Jobs"

local JobAction = ISBaseTimedAction:derive("cf_commonlib_JobAction")

function JobAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return self:units()
end

--- Whether the character stands where the menu would have walked them for the job
--- (Squares.withinReach).
function JobAction:atJob()
    return Squares.withinReach(self.character, self:target(), self:reach())
end

function JobAction:reach()
    return self.REACH
end

--- Whether the authority may take the character as at the job. The server never calls isValid()
--- and NetTimedAction checks no distance, so a modified client could otherwise send a job for any
--- object in the world.
function JobAction:atJobForAuthority()
    return not isServer() or self:atJob()
end

function JobAction:isValid()
    -- Past here the server's complete() may already have moved what the job works with while this
    -- client's action is still finishing; failing then would stop the action and empty the
    -- player's queue (ISBaseTimedAction.stop). Vanilla stops checking there too
    -- (ISInstallVehiclePart.isValid).
    if self.action and self.action:getJobDelta() >= 0.9 then
        return true
    end
    -- The game asks every tick (IsoGameCharacter.update), so this asks only what can change
    -- mid-job and is cheap to see. The rest waits for start() and complete().
    if not self:keeps() then
        return false
    end
    -- The server can't tell whether a remote player stands in the dark
    -- (IsoPlayer.tooDarkToRead), so the player's own side checks the light.
    if self:row().light and self.character:tooDarkToRead() then
        HaloTextHelper.addBadText(self.character, getText(self.TOO_DARK))
        return false
    end
    return self:atJob()
end

function JobAction:waitToStart()
    self.character:faceThisObject(self:target())
    return self.character:shouldBeTurning()
end

function JobAction:update()
    self.character:faceThisObject(self:target())
    local metabolics = self:row().metabolics
    if metabolics then
        self.character:setMetabolicTarget(metabolics)
    end
end

function JobAction:startJob()
    local row = self:row()
    if row.begin then
        row.begin(self)
        return
    end
    self:setActionAnim(row.anim or "Loot")
    if not row.anim then
        self.character:SetVariable("LootPosition", row.position or "Low")
        if self.REPORTS_LOOT then
            self.character:reportEvent("EventLootItem")
        end
    elseif row.position then
        self.character:SetVariable("LootPosition", row.position)
    end
    if row.sound then
        self.sound = self.character:playSound(row.sound)
    end
end

function JobAction:start()
    -- Single player checks every rule once here, and again in complete(), as vanilla's crafting
    -- checks its recipe in start() and leaves isValid to whether the bench is still in use
    -- (ISHandcraftAction). A multiplayer client leaves them to the server's complete().
    if not isClient() and not self:canPerform() then
        self:forceStop()
        return
    end
    -- Server syncs can replace the item objects while the action waits in the queue.
    if isClient() then
        self:findItems()
    end
    self:startJob()
end

-- A sound that already ended may have been reused for another, which stopping would cut off.
function JobAction:stopSound()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
end

function JobAction:stop()
    self:stopSound()
    ISBaseTimedAction.stop(self)
end

function JobAction:perform()
    self:stopSound()
    local doneSound = self:row().doneSound
    if doneSound then
        self.character:playSound(doneSound)
    end
    ISInventoryPage.renderDirty = true
    ISBaseTimedAction.perform(self)
end

-- Whether `with` is an inventory item the character works with, rather than a world object or a
-- string.
local function isItem(with)
    return with ~= nil and instanceof(with, "InventoryItem")
end

--- Makes the job class `Action` (a JobAction) the action of every job of several features, each a
--- job module (Jobs.define) of jobs at one kind of object or vehicle. `FEATURES[feature]`:
--- isTarget(target), the objects or vehicles it works at; jobs, its job module, which gets
--- `action` (Action) and `feature` (the name) for the menus (JobOptions); site, if any, its side of
--- the jobs on the authority (Jobs.perform), where the shared files can give it; reach, if any,
--- its own in place of the class's REACH. A row's length is `minutes` of game time or `units`,
--- action units as vanilla times its own jobs: a number, or a function(target, with, character) of
--- one. A `with` that is an inventory item is carried, or with the row's `inTarget` in the target's
--- container. A row's `wield`: `with` is the tool, held in the primary hand for the whole job; its
--- `equip`, if any, a function(character, target, with) of another tool to hold: an item, or a
--- predicate the first carried match of which is held. At a vehicle, the row's `area(vehicle,
--- with)` names the vehicle area the job is done from. Gives Action:
--- - jobsOf(feature), the job module of `feature`;
--- - targetOn(feature, square), the topmost object on `square` `feature` works at, or nil: an
---   object standing on a floor comes before the floor, which some features work at too;
--- - serve(sites), which gives each feature `sites` names its site: the server files' way, as they
---   load after the shared ones;
--- - new(character, feature, job, target, with), nil for a feature or job there is none of: those
---   come from the client, every later step looks them up, and the server turns down a request
---   whose new() gives no action (NetTimedActionPacket.processServer);
--- - completeJob(character, feature, job, target, with), the job done on the authority as complete()
---   does it once the character is found at it (Jobs.perform); returns whether it was done, never
---   for a feature no site serves;
--- - queue(playerNum, feature, job, target, with), which walks the character over, keeping their
---   queue, and queues the job there holding its tool. Client only;
--- and the methods JobAction asks for, with complete(), which does the job.
function JobAction.forFeatures(Action, FEATURES)
    -- On the class, which a reload of its file keeps, as the server files served it only once.
    local sites = Action.sites or {}
    Action.sites = sites
    for feature, entry in pairs(FEATURES) do
        entry.jobs.action, entry.jobs.feature = Action, feature
        sites[feature] = entry.site or sites[feature]
    end

    local function rowOf(feature, job)
        local entry = FEATURES[feature]
        return entry and entry.jobs.JOBS[job]
    end

    function Action.jobsOf(feature)
        return FEATURES[feature].jobs
    end

    function Action.targetOn(feature, square)
        local isTarget = FEATURES[feature].isTarget
        local objects = square:getObjects()
        for i = objects:size() - 1, 0, -1 do
            local object = objects:get(i)
            if isTarget(object) then
                return object
            end
        end
        return nil
    end

    function Action.serve(served)
        for feature, site in pairs(served) do
            sites[feature] = site
        end
    end

    function Action:row()
        return rowOf(self.feature, self.job)
    end

    function Action:units()
        local row = self:row()
        local length = row.units or row.minutes
        if type(length) == "function" then
            length = length(self.object, self.with, self.character)
        end
        return row.units and length or length * Clock.unitsPerMinute()
    end

    function Action:target()
        return self.object
    end

    function Action:reach()
        return FEATURES[self.feature].reach or self.REACH
    end

    -- The container an item `with` is kept in: the target's for a row with inTarget, else the
    -- character's inventory; nil for a `with` that is no item, or a target without its container.
    local function holderOf(self)
        if not isItem(self.with) then
            return nil
        elseif self:row().inTarget then
            return self.object:getContainer()
        end
        return self.character:getInventory()
    end

    function Action:keeps()
        if not (Squares.onSquare(self.object) and FEATURES[self.feature].isTarget(self.object)) then
            return false
        elseif not isItem(self.with) then
            return not self:row().wield
        end
        local holder = holderOf(self)
        return holder ~= nil and holder:containsRecursive(self.with)
            and (not self:row().wield or self.character:isPrimaryHandItem(self.with))
    end

    function Action:canPerform()
        return self:keeps() and not FEATURES[self.feature].jobs.refusal(self.character, self.job, self.object, self.with)
    end

    function Action:findItems()
        local holder = holderOf(self)
        if holder then
            self.with = holder:getItemWithIDRecursiv(self.with:getID())
        end
    end

    function Action.completeJob(character, feature, job, target, with)
        local entry, site = FEATURES[feature], sites[feature]
        if not (entry and site) then
            return false
        end
        return Jobs.perform(entry.jobs, site, character, job, target, with)
    end

    -- The job's own rules are rechecked by Jobs.perform, after it catches the target up.
    function Action:complete()
        if not (self:keeps() and self:atJobForAuthority()) then
            return false
        end
        return Action.completeJob(self.character, self.feature, self.job, self.object, self.with)
    end

    -- Parameter names match the fields: the multiplayer server rebuilds the action by passing them
    -- to new() in order (NetTimedAction).
    function Action:new(character, feature, job, object, with)
        if not rowOf(feature, job) then
            return nil
        end
        local o = ISBaseTimedAction.new(self, character)
        o.feature = feature
        o.job = job
        o.object = object
        o.with = with
        o.maxTime = o:getDuration()
        return o
    end

    function Action.queue(playerNum, feature, job, target, with)
        local row = rowOf(feature, job)
        local character = getSpecificPlayer(playerNum)
        local function queueThere()
            local tool = row.wield and with or row.equip and row.equip(character, target, with)
            if tool then
                local twoHands = type(tool) ~= "function" and instanceof(tool, "HandWeapon") and tool:isTwoHandWeapon()
                ISWorldObjectContextMenu.equip(character, character:getPrimaryHandItem(), tool, true, twoHands)
            end
            ISTimedActionQueue.add(Action:new(character, feature, job, target, with))
        end
        if instanceof(target, "BaseVehicle") then
            ISTimedActionQueue.add(ISPathFindAction:pathToVehicleArea(character, target, row.area(target, with)))
            queueThere()
        else
            Squares.queueBeside(character, target:getSquare(), queueThere)
        end
    end
end

return JobAction
