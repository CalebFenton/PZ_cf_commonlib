-- Opens a window at an object once the character stands at it, as vanilla's info actions do
-- (ISGeneratorInfoAction, ISOvenUITimedAction): the walk over, then a timed action of no length.
-- This client's alone, with no complete(): opening a window is nothing the server does. And the
-- life of such a window: one of its family per player, the controller's focus while open, and
-- closed once the character walks off (OpenAction.inReach).

require "TimedActions/ISBaseTimedAction"
local Squares = require "cf_commonlib/Squares"

local OpenAction = ISBaseTimedAction:derive("cf_commonlib_OpenAction")

-- How far from the object, in squares on each axis, its window stays open: vanilla closes a
-- trailer's or a hutch's animal window past this (ISVehicleAnimalUI, ISAnimalUI).
local WINDOW_REACH = 4

--- Whether `object`'s window stays open for `playerNum`: the object still on its square and their
--- living character within reach of it on its level, as vanilla's animal windows measure it.
function OpenAction.inReach(playerNum, object)
    local character = getSpecificPlayer(playerNum)
    return Squares.onSquare(object) and character ~= nil and not character:isDead()
        and Squares.withinReach(character, object, WINDOW_REACH)
end

--- Shows `window` as `playerNum`'s one window of the family `windows` (a table of them by player
--- number), in place of the one open, which its close() closes, and gives it the controller.
function OpenAction.show(windows, playerNum, window)
    if windows[playerNum] then
        windows[playerNum]:close()
    end
    window:addToUIManager()
    windows[playerNum] = window
    if JoypadState.players[playerNum + 1] then
        setJoypadFocus(playerNum, window)
    end
end

--- Takes `playerNum`'s `window` of the family `windows` off the screen and the controller, as
--- vanilla's info windows let go of it (ISGeneratorInfoWindow.close). A window's close() calls it.
function OpenAction.close(windows, playerNum, window)
    window:removeFromUIManager()
    if windows[playerNum] == window then
        windows[playerNum] = nil
    end
    if JoypadState.players[playerNum + 1] then
        setJoypadFocus(playerNum, nil)
    end
end

function OpenAction:isValid()
    return Squares.onSquare(self.object)
end

function OpenAction:waitToStart()
    self.character:faceThisObject(self.object)
    return self.character:shouldBeTurning()
end

function OpenAction:update()
    self.character:faceThisObject(self.object)
end

function OpenAction:start()
end

function OpenAction:perform()
    self.open(self.character, self.object)
    -- Removes the action from the queue and starts the next.
    ISBaseTimedAction.perform(self)
end

function OpenAction:new(character, object, open)
    local o = ISBaseTimedAction.new(self, character)
    o.object = object
    o.open = open
    o.maxTime = 0
    return o
end

--- Walks `character` over to `object`, keeping their queue, and there calls `open(character,
--- object)`, which opens its window as things stand then.
function OpenAction.queue(character, object, open)
    Squares.queueBeside(character, object:getSquare(), function()
        ISTimedActionQueue.add(OpenAction:new(character, object, open))
    end)
end

return OpenAction
