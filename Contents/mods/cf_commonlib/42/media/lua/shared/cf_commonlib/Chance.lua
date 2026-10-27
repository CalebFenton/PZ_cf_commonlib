-- Chances and random picks. Every one draws on Chance.roll, looked up on this table as it runs, so
-- a test can set the roll and check either side of a chance instead of rolling it many times.

local Chance = {}

--- A roll, 0 up to but not including 1.
function Chance.roll()
    return ZombRandFloat(0, 1)
end

--- Whether a chance of `chance` (0 to 1) comes up: a roll below it.
function Chance.hit(chance)
    return Chance.roll() < chance
end

--- A number from `min` up to but not including `max`, any as likely.
function Chance.within(min, max)
    return min + (max - min) * Chance.roll()
end

--- A whole number from `min` to `max`, both included, each as likely.
function Chance.between(min, max)
    return min + math.floor(Chance.roll() * (max - min + 1))
end

--- One of the entries of the non-empty `list`, each as likely.
function Chance.pick(list)
    return list[Chance.between(1, #list)]
end

--- One value of the non-empty `entries`, { value, weight } pairs, each as likely as its weight.
function Chance.pickWeighted(entries)
    local total = 0
    for _, entry in ipairs(entries) do
        total = total + entry[2]
    end
    local roll = Chance.roll() * total
    for _, entry in ipairs(entries) do
        roll = roll - entry[2]
        if roll < 0 then
            return entry[1]
        end
    end
    return entries[#entries][1]
end

--- `count` of the entries of `list`, all of them if it has fewer, each picked at random.
function Chance.pickSome(list, count)
    local left, picked = {}, {}
    for i, entry in ipairs(list) do
        left[i] = entry
    end
    for _ = 1, math.min(count, #left) do
        table.insert(picked, table.remove(left, Chance.between(1, #left)))
    end
    return picked
end

--- The chance that something with a chance of `perHour` in each hour happens in `hours`.
function Chance.overHours(perHour, hours)
    return 1 - (1 - math.min(1, perHour)) ^ hours
end

return Chance
