-- The right-click option of a job of a JobAction.forFeatures class, greyed out as its job module
-- would refuse it, so the menu, the action's start() and the authority can't disagree; the world
-- menu's hook for an object's options; and how a menu reads an option of vanilla's.

require "ISUI/ISWorldObjectContextMenu"
local Needs = require "cf_commonlib/Needs"

local JobOptions = {}

--- Adds to `menu` the option `label` (without one, the text of the class's Action.labelKey(job))
--- that queues `feature`'s `job` of the action class `Action` (JobAction.forFeatures) at `target`
--- with `with`, its tooltip headed by what the job does (its row's tooltip): greyed out saying it's
--- too dark for a job that needs light (Action.TOO_DARK), else with the target's state when that
--- refuses it, else with the needs listed when the character lacks any, else with what is wrong
--- with `with`. A job its target's state refuses that belongs to another state of it
--- (hideBlocked) is left out, as is one at a target this side can't read. Returns the option, or
--- nil when left out.
function JobOptions.add(menu, playerNum, Action, feature, job, target, with, label)
    local jobs = Action.jobsOf(feature)
    local subject = jobs.subjectOf(target)
    if not subject then
        return nil
    end
    local character = getSpecificPlayer(playerNum)
    local blocker = jobs.blocker(character, job, subject, with)
    local row = jobs.JOBS[job]
    if blocker and row and row.hideBlocked then
        return nil
    end
    blocker = Needs.tooDark(character, jobs.needsLight(job), Action.TOO_DARK) or blocker
    local text = label or getText(Action.labelKey(job))
    local option = menu:addOption(text, playerNum, Action.queue, feature, job, target, with)
    if row and row.tooltip then
        Needs.describe(option, row.tooltip)
    end
    Needs.show(option, jobs.needs(character, job, subject, with), blocker)
    Needs.refuse(option, not option.notAvailable and jobs.withRefusal(character, job, subject, with))
    return option
end

--- Adds `job` done with an item carried: a submenu `label` with an option for each of `items`,
--- named `nameOf(item)` (its display name without) and showing it. With none carried, the job's own
--- option without an item, which its blocker refuses saying what to carry.
function JobOptions.addEach(menu, playerNum, Action, feature, job, target, items, label, nameOf)
    if #items == 0 then
        JobOptions.add(menu, playerNum, Action, feature, job, target, nil, label)
        return
    end
    local submenu = Needs.addSubMenu(menu, label)
    for _, item in ipairs(items) do
        local name = nameOf and nameOf(item) or item:getDisplayName()
        local option = JobOptions.add(submenu, playerNum, Action, feature, job, target, item, name)
        if option then
            option.itemForTexture = item
        end
    end
end

--- The first item of each of `fullTypes` that `character` carries, bags included, in that order;
--- with `keep(fullType)`, of those it accepts only.
function JobOptions.firstOfEach(character, fullTypes, keep)
    local inventory, found = character:getInventory(), {}
    for _, fullType in ipairs(fullTypes) do
        local item = (not keep or keep(fullType)) and inventory:getFirstTypeRecurse(fullType)
        if item then
            table.insert(found, item)
        end
    end
    return found
end

--- Fills the world's right-click menu for the first clicked object `isObject(object)` accepts:
--- `fill(context, playerNum, character, object, worldobjects)`. Nothing for a character in a
--- vehicle; the game's test pass only learns there is something. Returns the handler it adds to
--- OnFillWorldObjectContextMenu, for a test to call as the game does.
function JobOptions.onWorldMenu(isObject, fill)
    local function onFill(playerNum, context, worldobjects, test)
        local character = getSpecificPlayer(playerNum)
        if not character or character:getVehicle() then return end
        local object = Needs.findClicked(worldobjects, isObject)
        if not object then return end
        if test then return ISWorldObjectContextMenu.setTest() end
        fill(context, playerNum, character, object, worldobjects)
    end
    Events.OnFillWorldObjectContextMenu.Add(onFill)
    return onFill
end

--- The function choosing `option` calls, as a menu finds vanilla's own options: a get-up option
--- (ISContextMenu.addGetUpOption) selects onGetUpAndThen with the handler as its first parameter.
function JobOptions.handlerOf(option)
    return option.onSelect == ISContextMenu.onGetUpAndThen and option.param1 or option.onSelect
end

return JobOptions
