-- Places and the objects on squares, and whether a character stands where a job at one is done.

local Squares = {}

--- An object's square as { x, y, z }: how commands, statuses and records name a place.
function Squares.positionOf(isoObject)
    return { x = isoObject:getX(), y = isoObject:getY(), z = isoObject:getZ() }
end

--- Whether two places, anything with x, y and z, are the same square; false if either is nil.
function Squares.samePosition(a, b)
    return a ~= nil and b ~= nil and a.x == b.x and a.y == b.y and a.z == b.z
end

--- Whether `position` is a { x, y, z } place, as a command argument from a client must be.
function Squares.isPosition(position)
    return type(position) == "table" and type(position.x) == "number" and type(position.y) == "number"
        and type(position.z) == "number"
end

--- Calls `fn(square)` for every loaded square on level `z` within `radius` squares of x, y on each
--- axis, x, y included, until one call returns a value other than nil, which this returns.
function Squares.eachAround(x, y, z, radius, fn)
    for squareX = x - radius, x + radius do
        for squareY = y - radius, y + radius do
            local square = getSquare(squareX, squareY, z)
            local result = square and fn(square)
            if result ~= nil then
                return result
            end
        end
    end
    return nil
end

--- The first object on `square` for which `matches(object)` is true, or nil. Takes a nil square.
function Squares.findObjectOn(square, matches)
    local objects = square and square:getObjects()
    for i = 0, (objects and objects:size() or 0) - 1 do
        local object = objects:get(i)
        if matches(object) then
            return object
        end
    end
    return nil
end

--- Whether `object` is still in the world, rather than a copy left behind by a removal or a
--- chunk reload. A vehicle is on no square's object list, so it counts until it leaves the world.
function Squares.onSquare(object)
    if instanceof(object, "BaseVehicle") then
        return not object:isRemovedFromWorld()
    end
    return object ~= nil and object:getObjectIndex() ~= -1
end

--- Whether `character` stands within `reach` squares on each axis of the middle of `target`'s
--- square, on its level: where a menu walks them for a job (luautils.walkAdj), with room for drift
--- and client lag. A vehicle `target` adds half its longest side, as the menu walks to one of its
--- areas (ISPathFindAction.pathToVehicleArea). The authority checks it before doing a job, since
--- NetTimedAction checks no distance.
function Squares.withinReach(character, target, reach)
    if instanceof(target, "BaseVehicle") then
        local extents = target:getScript():getExtents()
        local around = math.max(extents:x(), extents:z()) / 2 + reach
        return IsoUtils.DistanceTo(character:getX(), character:getY(), target:getX(), target:getY()) <= around
            and math.abs(character:getZ() - target:getZ()) < 1
    end
    local square = target:getSquare()
    return square ~= nil and math.abs(character:getX() - (square:getX() + 0.5)) <= reach
        and math.abs(character:getY() - (square:getY() + 0.5)) <= reach
        and math.abs(character:getZ() - square:getZ()) < 1
end

--- Queues the walk of `character` to beside `square`, keeping their queue (luautils.walkAdj), and
--- there `queueThere()`, which queues what they do once there. Returns false, queueing nothing,
--- when no square beside it can be reached. Client only.
function Squares.queueBeside(character, square, queueThere)
    if not luautils.walkAdj(character, square, true) then
        return false
    end
    queueThere()
    return true
end

return Squares
