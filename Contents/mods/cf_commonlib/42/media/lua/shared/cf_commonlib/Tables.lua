-- Comparing plain Lua values.

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

return Tables
