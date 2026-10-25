-- A vanilla generator's reach as the save's options set it.

local GeneratorReach = {}

-- The map's lowest and highest levels (IsoChunk.getGridSquare).
local LOWEST_LEVEL, HIGHEST_LEVEL = -32, 31

--- A generator's reach: GeneratorTileRange squares between square middles and
--- GeneratorVerticalPowerRange levels, as IsoGenerator.isPoweringSquare measures it. That one reads
--- copies of the options taken only as a generator is built, so this reads the options.
function GeneratorReach.range()
    return SandboxVars.GeneratorTileRange, SandboxVars.GeneratorVerticalPowerRange
end

--- Whether the square x, y, z is in a generator's reach of the square ox, oy, oz.
function GeneratorReach.covers(ox, oy, oz, x, y, z)
    local radius, levels = GeneratorReach.range()
    local dx, dy, dz = x - ox, y - oy, z - oz
    return z >= LOWEST_LEVEL and z <= HIGHEST_LEVEL and math.abs(dz) <= levels and dx * dx + dy * dy <= radius * radius
end

--- Calls `fn(square)` for every loaded square in a generator's reach of the square x, y, z
--- (GeneratorReach.covers).
function GeneratorReach.eachSquare(x, y, z, fn)
    local radius, levels = GeneratorReach.range()
    local cell = getCell()
    local radiusSquared = radius * radius
    for squareZ = math.max(LOWEST_LEVEL, z - levels), math.min(HIGHEST_LEVEL, z + levels) do
        for squareX = x - radius, x + radius do
            local dxSquared = (squareX - x) * (squareX - x)
            for squareY = y - radius, y + radius do
                local square = dxSquared + (squareY - y) * (squareY - y) <= radiusSquared
                    and cell:getGridSquare(squareX, squareY, squareZ)
                if square then
                    fn(square)
                end
            end
        end
    end
end

return GeneratorReach
