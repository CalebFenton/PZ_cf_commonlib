-- Finding objects on squares, and whether a character stands where a job at one is done.

local Squares = {}

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

--- Queues the walk of `playerNum`'s character to beside `square`, keeping their queue, and returns
--- the character, or nil when no square beside it can be reached (luautils.walkAdj). Client only.
function Squares.walkTo(playerNum, square)
    local character = getSpecificPlayer(playerNum)
    return luautils.walkAdj(character, square, true) and character or nil
end

return Squares
