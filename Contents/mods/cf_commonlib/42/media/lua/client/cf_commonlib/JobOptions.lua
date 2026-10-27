-- Options greyed out by the job module's verdict (Jobs.define), so the menu, the action's start()
-- and the authority can't disagree.

require "ISUI/ISWorldObjectContextMenu"
local Needs = require "cf_commonlib/Needs"
local Squares = require "cf_commonlib/Squares"

local JobOptions = {}

--- Greys `option`, of `job` of the job module `Jobs`, out as `verdict` (Jobs' Module.verdict, or one
--- of the same shape a batch of jobs adds up) says, in the order Jobs refuses it: too dark for a
--- job that needs light (the action's TOO_DARK), else the target's state, else the needs listed,
--- else what is wrong with `with`. Its tooltip is headed by what the job does (its row's tooltip).
function JobOptions.showVerdict(option, character, Jobs, job, verdict)
    local row = Jobs.JOBS[job]
    if row and row.tooltip then
        Needs.describe(option, row.tooltip)
    end
    local blocker = Needs.tooDark(character, Jobs.needsLight(job), Jobs.action.TOO_DARK) or verdict.blocker
    Needs.show(option, not blocker and verdict.needs or {}, blocker)
    Needs.refuse(option, not option.notAvailable and verdict.withRefusal)
end

local function jobName(Jobs, job)
    local row = Jobs.JOBS[job]
    return getText(row and row.label or Jobs.action.labelKey(job))
end

--- Adds to `menu` the option `label` (without one, the job's name: its row's `label` key, else its
--- action's labelKey(job)) that queues `job` of the job module `Jobs` (stamped by
--- JobAction.forFeatures) at `target` with `with`, greyed out as JobOptions.showVerdict says. A job
--- its target's state refuses that belongs to another state of it (hideBlocked) is left out, as is
--- one at a target this side can't read. Returns the option, or nil when left out.
function JobOptions.add(menu, playerNum, Jobs, job, target, with, label)
    local subject = Jobs.subjectOf(target)
    if not subject then
        return nil
    end
    local character = getSpecificPlayer(playerNum)
    local verdict = Jobs.verdict(character, job, subject, with)
    if verdict.hidden then
        return nil
    end
    local option = menu:addOption(label or jobName(Jobs, job), playerNum, Jobs.action.queue, Jobs.feature, job, target,
        with)
    JobOptions.showVerdict(option, character, Jobs, job, verdict)
    return option
end

--- Adds `job` done with an item carried: a submenu `label` (the job's name without) with an option
--- for each of `items`, named `nameOf(item)` (its display name without) and showing it. With none
--- carried, the job's own option without an item, which its row refuses saying what to carry.
function JobOptions.addEach(menu, playerNum, Jobs, job, target, items, label, nameOf)
    label = label or jobName(Jobs, job)
    if #items == 0 then
        JobOptions.add(menu, playerNum, Jobs, job, target, nil, label)
        return
    end
    local submenu = JobOptions.addSubMenu(menu, label)
    for _, item in ipairs(items) do
        local name = nameOf and nameOf(item) or item:getDisplayName()
        local option = JobOptions.add(submenu, playerNum, Jobs, job, target, item, name)
        if option then
            option.itemForTexture = item
        end
    end
end

--- A finder of JobOptions.onWorldMenu (JobOptions.findClicked).
function JobOptions.clicked(matches)
    return function(worldobjects)
        return JobOptions.findClicked(worldobjects, matches)
    end
end

--- Fills the world's right-click menu for what `find(worldobjects)` finds there (an
--- object, or whatever the fill reads; JobOptions.clicked finds one by a test of it):
--- `fill(context, playerNum, character, found, worldobjects)`. Nothing for a character in a
--- vehicle or when it finds nothing; the game's test pass only learns there is something. Returns
--- the handler it adds to OnFillWorldObjectContextMenu, for a test to call as the game does.
function JobOptions.onWorldMenu(find, fill)
    local function onFill(playerNum, context, worldobjects, test)
        local character = getSpecificPlayer(playerNum)
        if not character or character:getVehicle() then return end
        local found = find(worldobjects)
        if not found then return end
        if test then return ISWorldObjectContextMenu.setTest() end
        fill(context, playerNum, character, found, worldobjects)
    end
    Events.OnFillWorldObjectContextMenu.Add(onFill)
    return onFill
end

--- The first object on the right-clicked squares for which `matches(object)` is true, or nil.
function JobOptions.findClicked(worldobjects, matches)
    local seen = {}
    for _, clicked in ipairs(worldobjects) do
        local square = clicked:getSquare()
        if square and not seen[square] then
            seen[square] = true
            local found = Squares.findObjectOn(square, matches)
            if found then
                return found
            end
        end
    end
    return nil
end

--- Adds an option named `name` to `context` that opens a new submenu. Returns the submenu and the
--- option.
function JobOptions.addSubMenu(context, name)
    local submenu = ISContextMenu:getNew(context)
    local option = context:addOption(name)
    context:addSubMenu(option, submenu)
    return submenu, option
end

--- The submenu of `context`'s option named `name` (its text, as the game filled it before the
--- mod's hook ran), or nil: where a mod's options join vanilla's own for the same object.
function JobOptions.subMenuOf(context, name)
    local option = name and context:getOptionFromName(name)
    return option and option.subOption and context:getSubMenu(option.subOption) or nil
end

--- The function choosing `option` calls, as a menu finds vanilla's own options: a get-up option
--- (ISContextMenu.addGetUpOption) selects onGetUpAndThen with the handler as its first parameter.
function JobOptions.handlerOf(option)
    return option.onSelect == ISContextMenu.onGetUpAndThen and option.param1 or option.onSelect
end

return JobOptions
