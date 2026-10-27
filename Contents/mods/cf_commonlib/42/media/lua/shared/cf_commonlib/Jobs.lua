-- The one shape every hands-on job takes, so the menu (JobOptions), the action's start()
-- (JobAction) and the authority (Jobs.perform) read the same refusal and can't disagree.
--
-- A job module is a table with JOBS, a row for each job by name, which Jobs.define gives its
-- functions. Beside how the job looks and how long it takes (JobAction), a row has:
-- - blocker(character, subject, with): the state of the target that refuses the job, as a
--   translation key, or nil. hideBlocked: a menu leaves the job out, rather than greyed, while its
--   blocker refuses it, as it belongs to another state of the target.
-- - with = isKind(item), if the job works with an inventory item: `with` must be one the character
--   carries, bags included, of a kind isKind accepts, else `withMissing` (a translation key; the
--   spec's unknown without one) refuses it. withOptional: the job may also be done with none.
-- - withRefusal(character, subject, with), if any: what else refuses `with`, asked once it passed
--   the row's `with`.
-- - materials: what it takes of the character (Materials, a craft done in place included), or a
--   function(character, subject, with) of them, which must answer for any subject, refused or not;
--   absent when it takes nothing.
-- - xp: { perk = "Name", amount }, what it teaches once done.
-- - label: the translation key of the job's name in a menu, where the action's labelKey(job)
--   doesn't give it (JobOptions).
-- - tooltip: the translation key of a sentence saying what the job does, which heads its option's
--   tooltip (JobOptions), as a crafting recipe's Tooltip does.
-- - light: it needs light to see by. Only the player's own side can tell (IsoPlayer.tooDarkToRead
--   is false for a remote player), so the menu and the action's isValid check it, not refusal.
-- `subject` is what the rows read of the target worked at (the module's subjectOf), and `with` is
-- what the job works with: an inventory item, a second object, or a string a client may send.
--
-- A job is refused in one order everywhere (Module.verdict): the target's state (blocker), then
-- what the character lacks (needs), then what is wrong with `with`, so a menu lists the needs
-- before it says anything of `with`.

local Materials = require "cf_commonlib/Materials"

local Jobs = {}

-- Whether `item` is an inventory item `character` carries, bags included, of a kind `isKind(item)`
-- accepts.
local function carries(character, item, isKind)
    return instanceof(item, "InventoryItem") and isKind(item) and character:getInventory():containsRecursive(item)
end

--- Why a job is refused: `blocker` (a translation key) if any, else, while any of `needs` is unmet,
--- `short`, or without it the kind of the first unmet need, else nil.
function Jobs.refusalOf(blocker, needs, short)
    local unmet = not blocker and Materials.firstUnmet(needs)
    return blocker or unmet and (short or unmet.kind) or nil
end

--- Gives the job module `Module` its functions, each also taking the `character`, the `job`, the
--- target's subject and `with`: Module.materials, needs, verdict and refusalAt;
--- Module.needsLight(job); Module.subjectOf(target); and Module.refusal(character, job, target,
--- with), which reads the subject itself. `spec`:
--- - short, if any: the refusal while a need is unmet (a translation key the mod defines), in
---   place of the unmet need's kind;
--- - unknown: the refusal of a job no row has, which only a client that made one up asks for;
--- - subjectOf(target), if the rows read something other than the target itself: what they read
---   of it, or nil when there is none to work at, which `missing` refuses.
--- Each of unknown and missing stands in for the other when only one is given.
function Jobs.define(Module, spec)
    local unknown, missing = spec.unknown or spec.missing, spec.missing or spec.unknown
    local subjectOf = spec.subjectOf or function(target) return target end

    Module.subjectOf = subjectOf

    function Module.materials(character, job, subject, with)
        local row = Module.JOBS[job]
        local materials = row and row.materials
        if type(materials) == "function" then
            return materials(character, subject, with)
        end
        return materials or {}
    end

    function Module.needs(character, job, subject, with)
        return Materials.needs(character, Module.materials(character, job, subject, with))
    end

    function Module.needsLight(job)
        local row = Module.JOBS[job]
        return row ~= nil and row.light == true
    end

    local function withRefusal(character, row, subject, with)
        if row.with and not (with == nil and row.withOptional) and not carries(character, with, row.with) then
            return row.withMissing or unknown
        end
        return row.withRefusal and row.withRefusal(character, subject, with) or nil
    end

    --- How the job stands at `subject`, in the order it is refused: { blocker }, the target's
    --- state, with `hidden` when the row hides it (hideBlocked); else { needs, withRefusal }, what
    --- it takes of the character and, once they have it all, what is wrong with `with`.
    function Module.verdict(character, job, subject, with)
        local row = Module.JOBS[job]
        if not row then
            return { blocker = unknown }
        end
        local blocker = row.blocker and row.blocker(character, subject, with)
        if blocker then
            return { blocker = blocker, hidden = row.hideBlocked == true }
        end
        local needs = Module.needs(character, job, subject, with)
        return {
            needs = needs,
            withRefusal = not Materials.firstUnmet(needs) and withRefusal(character, row, subject, with) or nil,
        }
    end

    --- What refuses the job at `subject`, a translation key or nil (Module.verdict's order).
    function Module.refusalAt(character, job, subject, with)
        local verdict = Module.verdict(character, job, subject, with)
        return Jobs.refusalOf(verdict.blocker, verdict.needs, spec.short) or verdict.withRefusal
    end

    --- What refuses `character` doing `job` at `target` with `with`, as this side knows it now.
    function Module.refusal(character, job, target, with)
        if not Module.JOBS[job] then
            return unknown
        end
        local subject = target and subjectOf(target)
        if not subject then
            return missing
        end
        return Module.refusalAt(character, job, subject, with)
    end
end

--- Does `job` of the job module `Module` for `character` at `target` with `with`, on the authority
--- once its timed action finished. `site` is the feature's side of its jobs there:
--- - open(target, with), if any: brings what the jobs work on up to now and returns it, the
---   `place`, or nil when there is none;
--- - act(character, job, place, row, target, with, materials): does the job, beyond taking its
---   materials (read before it acts) and giving its XP; returns true when it was done;
--- - tell(place, target, done), if any: shows and sends what changed.
--- In this order: catch up, so the time before counts at the old state; recheck the job as the
--- authority knows it now; read what it takes before doing it, since doing it can change that; do
--- it; only once it was done take what it takes and give its row's XP, so a job not done costs and
--- teaches nothing; tell, done or not, since catching up changed it too. Returns whether it was
--- done.
function Jobs.perform(Module, site, character, job, target, with)
    local place = site.open and site.open(target, with)
    local row = Module.JOBS[job]
    local subject = row and target and Module.subjectOf(target)
    local done = false
    if subject and not Module.refusalAt(character, job, subject, with) then
        local materials = Module.materials(character, job, subject, with)
        done = site.act(character, job, place, row, target, with, materials) == true
        if done then
            Materials.consume(character, materials)
            if row.xp then
                addXp(character, Perks[row.xp.perk], row.xp.amount)
            end
        end
    end
    if site.tell then
        site.tell(place, target, done)
    end
    return done
end

--- A site of Jobs.perform for jobs that work on the target itself, with nothing to bring up to
--- now: `DO[job](character, row, target, with, materials)` does one and returns true when it was
--- done.
function Jobs.targetSite(DO)
    return {
        act = function(character, job, place, row, target, with, materials)
            return DO[job](character, row, target, with, materials)
        end,
    }
end

return Jobs
