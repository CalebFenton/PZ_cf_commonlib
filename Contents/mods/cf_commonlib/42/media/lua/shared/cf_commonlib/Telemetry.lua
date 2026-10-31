-- Named channels of diagnostic lines in console.txt, for working out what a mod did and how long it
-- took, in a test run or a player's game. Every channel is off until the switch file, Telemetry.FILE
-- in the Lua folder of the game's cache dir (Zomboid/Lua), names it on a line of its own, or holds
-- a line `*` for every channel. Lines starting with `#` are comments. The file is read once, as
-- the first channel is made, so a change to it takes effect when the game next starts.
--
-- Off, a channel costs a field read: a caller tests `channel.on` before it works out what to log.
-- On, each line reads `TELEMETRY <channel> key=value ...`, so grep finds a channel and a key.

local Telemetry = {}

Telemetry.FILE = "cf_telemetry.txt"

-- The channel names the switch file turns on, or true for every channel; nil until read.
local switched

local function trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function readSwitch()
    switched = {}
    local reader = getFileReader(Telemetry.FILE, false)
    if not reader then return end
    local line = reader:readLine()
    while line do
        local name = trim(line)
        if name == "*" then
            switched = true
            break
        elseif name ~= "" and name:sub(1, 1) ~= "#" then
            switched[name] = true
        end
        line = reader:readLine()
    end
    reader:close()
end

local function format(value)
    if type(value) == "number" then
        if value == math.floor(value) and math.abs(value) < 1e15 then
            return string.format("%d", value)
        end
        return string.format("%.4f", value)
    end
    return tostring(value)
end

-- Prints `channel`'s line of the key, value pairs `...`, in order.
local function log(channel, ...)
    if not channel.on then return end
    local parts = { "TELEMETRY", channel.name }
    local count = select("#", ...)
    for i = 1, count, 2 do
        local key, value = select(i, ...)
        table.insert(parts, key .. "=" .. format(value))
    end
    print(table.concat(parts, " "))
end

--- The channel `name` (the caller's, prefixed with its mod's): `channel.on` says whether the switch
--- file turns it on, and `channel:log(key, value, ...)` prints a line of the pairs, in order.
function Telemetry.channel(name)
    if switched == nil then
        readSwitch()
    end
    return { name = name, on = switched == true or switched[name] == true, log = log }
end

--- Real milliseconds now, for a line's durations.
function Telemetry.now()
    return getTimestampMs()
end

return Telemetry
