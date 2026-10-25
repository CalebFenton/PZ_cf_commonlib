-- Game time as the world and timed actions count it.

local Clock = {}

--- The game hours since `holder.lastHour`, at most `longest`, and none the first time; stamps
--- `holder.lastHour` with now, so the next pass counts from here. The cap keeps a save loaded after
--- the clock jumped from making up days at once.
function Clock.hoursSince(holder, longest)
    local now = getGameTime():getWorldAgeHours()
    local hours = math.min(longest, now - (holder.lastHour or now))
    holder.lastHour = now
    return hours
end

--- An action advances by GameTime.getMultiplier() each tick (BaseAction.update), and in the same
--- tick the clock advances getMultiplier() / (2 * minutesPerDay) in-game minutes (GameTime.update),
--- so one in-game minute is 2 * minutesPerDay units at any frame rate or game speed.
function Clock.unitsPerMinute()
    return 2 * getGameTime():getMinutesPerDay()
end

return Clock
