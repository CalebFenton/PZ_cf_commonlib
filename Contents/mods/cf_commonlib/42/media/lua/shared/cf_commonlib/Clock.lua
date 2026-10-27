-- Game time as the world and timed actions count it.

local Clock = {}

--- The most game hours one catch-up counts unless its caller says otherwise (Clock.hoursSince): a
--- save loaded after the clock jumped would otherwise make up days at once.
Clock.LONGEST_PASS = 24 * 7

--- The world's clock in game hours, which elapsed time is measured on, so a pass comes out the same
--- at any game speed or tick rate.
function Clock.now()
    return getGameTime():getWorldAgeHours()
end

--- The game hours since `holder.lastHour`, at most `longest` (default Clock.LONGEST_PASS), and
--- none the first time; stamps `holder.lastHour` with now, so the next pass counts from here.
function Clock.hoursSince(holder, longest)
    local now = Clock.now()
    local hours = math.min(longest or Clock.LONGEST_PASS, now - (holder.lastHour or now))
    holder.lastHour = now
    return hours
end

--- An action advances by GameTime.getMultiplier() each tick (BaseAction.update), and in the same
--- tick the clock advances getMultiplier() / (2 * minutesPerDay) in-game minutes (GameTime.update),
--- so one in-game minute is 2 * minutesPerDay units at any frame rate or game speed.
function Clock.unitsPerMinute()
    return 2 * getGameTime():getMinutesPerDay()
end

--- Action units per real second at normal speed, whatever the day length: an in-game minute is
--- Clock.unitsPerMinute() units and lasts minutesPerDay / 24 real seconds.
function Clock.unitsPerSecond()
    return 48
end

return Clock
