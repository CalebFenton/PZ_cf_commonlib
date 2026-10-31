-- The telemetry channel cf_commonlib.profile: times every event handler added from here on, so a
-- hitch can be pinned on the handler that caused it. Shared Lua loads mod by mod in load order,
-- each mod's files sorted by name, so this file, sorting first in the first library, sees every
-- Events.<name>.Add of this library and of the mods that require it; vanilla's handlers, added
-- before, aren't timed. Off, nothing is wrapped.
--
-- Lines: `event=slow` for one call of SLOW_MS or more; `event=spike` for a frame gap of SPIKE_MS
-- or more, with the timed handlers that ran in it (a spike they don't account for is the game's
-- own, or code outside events: UI, MapObjects, timed actions); `event=top` every SUMMARY_MS, the
-- handlers that took the most time since the last. Times come from a millisecond clock, so one
-- quick call reads 0 or 1, but a total over many calls is unbiased.

local Telemetry = require "cf_commonlib/Telemetry"

local channel = Telemetry.channel("cf_commonlib.profile")
if not channel.on then return end

local SLOW_MS = 50
local SPIKE_MS = 250
local SUMMARY_MS = 30000
local TOP = 12

local now = getTimestampMs

-- Per handler: { id, ms, calls, maxMs }; reset after each summary.
local stats = {}
-- The calls of 1 ms or more since the last tick, as "id=ms".
local frameCalls = {}
local frameMs = 0

local function where(fn)
    local ok, file = pcall(getFilenameOfClosure, fn)
    if not ok or not file then return "?" end
    local line = getFirstLineOfClosure(fn)
    return (string.match(file, "media[/\\]lua[/\\](.*)$") or file) .. ":" .. tostring(line)
end

local function record(stat, started, ...)
    local ms = now() - started
    stat.ms, stat.calls = stat.ms + ms, stat.calls + 1
    if ms > stat.maxMs then stat.maxMs = ms end
    if ms >= 1 then
        frameMs = frameMs + ms
        frameCalls[#frameCalls + 1] = stat.id .. "=" .. ms
    end
    if ms >= SLOW_MS then
        channel:log("event", "slow", "handler", stat.id, "ms", ms)
    end
    return ...
end

local function wrap(eventName, fn)
    local stat = { id = eventName .. "@" .. where(fn), ms = 0, calls = 0, maxMs = 0 }
    stats[#stats + 1] = stat
    return function(...)
        return record(stat, now(), fn(...))
    end
end

local function gameClock()
    local time = getGameTime()
    return string.format("%d:%02d", time:getHour(), time:getMinutes())
end

local function summarize()
    table.sort(stats, function(a, b) return a.ms > b.ms end)
    local parts = {}
    for i = 1, math.min(TOP, #stats) do
        local stat = stats[i]
        if stat.ms == 0 then break end
        parts[#parts + 1] = string.format("%s=%dms/%d/max%d", stat.id, stat.ms, stat.calls, stat.maxMs)
    end
    channel:log("event", "top", "clock", gameClock(), "handlers", table.concat(parts, ","))
    for _, stat in ipairs(stats) do
        stat.ms, stat.calls, stat.maxMs = 0, 0, 0
    end
end

local lastTick, lastSummary

local function onTick()
    local tick = now()
    if lastTick and tick - lastTick >= SPIKE_MS then
        channel:log("event", "spike", "ms", tick - lastTick, "clock", gameClock(), "handlersMs", frameMs,
            "handlers", table.concat(frameCalls, ","))
    end
    lastTick = tick
    frameCalls, frameMs = {}, 0
    lastSummary = lastSummary or tick
    if tick - lastSummary >= SUMMARY_MS then
        lastSummary = tick
        summarize()
    end
end

local onTickAdd = Events.OnTick.Add
for eventName, event in pairs(Events) do
    local add, remove = event.Add, event.Remove
    if type(add) == "function" and type(remove) == "function" then
        local wrappers = {}
        event.Add = function(fn)
            wrappers[fn] = wrappers[fn] or wrap(eventName, fn)
            return add(wrappers[fn])
        end
        event.Remove = function(fn)
            return remove(wrappers[fn] or fn)
        end
    end
end
onTickAdd(onTick)
channel:log("event", "on", "slowMs", SLOW_MS, "spikeMs", SPIKE_MS, "summaryMs", SUMMARY_MS)
