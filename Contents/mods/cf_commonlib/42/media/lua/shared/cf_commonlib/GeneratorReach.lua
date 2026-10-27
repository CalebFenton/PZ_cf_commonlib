-- Vanilla generators: which IsoGenerators are one, the reach the save's options give them, and
-- what mods' own machines draw from whatever powers them. Mods meet here rather than through each
-- other's globals, so each works without the other.

local GeneratorReach = {}

-- Tests of IsoGenerators that are a mod's own machine (GeneratorReach.excludeGenerators).
local excluded = {}
-- Mods' answers of what their placed objects draw (GeneratorReach.addDraw), in the order added.
local draws = {}

--- Has `isOwn(generator)` tell IsoGenerators that are a mod's own machine, such as a battery bank
--- built as one, and no vanilla generator (isVanillaGenerator).
function GeneratorReach.excludeGenerators(isOwn)
    table.insert(excluded, isOwn)
end

--- Whether `object` is a vanilla generator: an IsoGenerator no mod claims (excludeGenerators).
function GeneratorReach.isVanillaGenerator(object)
    if object == nil or not instanceof(object, "IsoGenerator") then
        return false
    end
    for _, isOwn in ipairs(excluded) do
        if isOwn(object) then
            return false
        end
    end
    return true
end

--- Has `draw(object)` say what a mod's placed object draws, for a mod that bills placed loads, as
--- vanilla's getGeneratorPowerConsumption says for an appliance: the kind a status lists it as (the
--- mod's own translation key) and the generator fuel an hour it would draw now in vanilla's units,
--- powered or not; or nil while it draws nothing.
---@param draw fun(object: IsoObject): string?, number?
function GeneratorReach.addDraw(draw)
    table.insert(draws, draw)
end

--- The first answer of addDraw's for `object` that draws: its kind and fuel an hour; or nil.
function GeneratorReach.drawOf(object)
    for _, draw in ipairs(draws) do
        local kind, fuel = draw(object)
        if kind and fuel and fuel > 0 then
            return kind, fuel
        end
    end
    return nil
end

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

--- Lets this side's chunks go of the squares a running generator at x, y, z powered, as the
--- generator switching off does (IsoGenerator.setSurroundingElectricity); otherwise they stay
--- powered here until their chunks reload. For a client whose copy of a running generator left
--- before the server's switch-off could reach it. A running generator's position is listed in
--- every chunk its reach touches (IsoChunk.addGeneratorPos).
function GeneratorReach.release(x, y, z)
    local radius = GeneratorReach.range()
    local chunkSquares = getChunkSizeInSquares()
    local cell = getCell()
    for wx = math.floor((x - radius) / chunkSquares), math.floor((x + radius) / chunkSquares) do
        for wy = math.floor((y - radius) / chunkSquares), math.floor((y + radius) / chunkSquares) do
            local chunk = cell:getChunk(wx, wy)
            if chunk then
                chunk:removeGeneratorPos(x, y, z)
            end
        end
    end
end

return GeneratorReach
