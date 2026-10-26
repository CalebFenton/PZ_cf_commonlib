-- Comparing plain Lua values, and copying Java lists into them.

local Tables = {}

--- Whether two values are the same, tables by what they hold, at any depth. Summaries compare so,
--- to send only what changed.
function Tables.sameValue(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return a == b
    end
    for key, value in pairs(a) do
        if not Tables.sameValue(value, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

--- Appends to `into` (a new table when nil) each value of the Java list `list` that `keep(value)`
--- passes, or every value without `keep`, in the list's order, and returns `into`.
function Tables.fromList(list, keep, into)
    into = into or {}
    for i = 0, list:size() - 1 do
        local value = list:get(i)
        if not keep or keep(value) then
            table.insert(into, value)
        end
    end
    return into
end

return Tables
