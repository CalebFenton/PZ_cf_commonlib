-- Moving items into and out of characters and containers on the authority so the clients see it,
-- and finding the working tools a job takes.
--
-- The sends act only in multiplayer (LuaManager's sendAddItemToContainer and
-- sendRemoveItemFromContainer), so single player needs no guard around them.

local Items = {}

function Items.notBroken(item)
    return not item:isBroken()
end

--- A test of whether an item is of `fullType`, for what takes one (a job row's `with`,
--- Tables.fromList).
function Items.ofType(fullType)
    return function(item) return item:getFullType() == fullType end
end

--- The first working tool with `tag` (an ItemTag value) `character` carries, bags included, or nil.
function Items.workingTool(character, tag)
    return character:getInventory():getFirstTagEvalRecurse(tag, Items.notBroken)
end

--- The tool of those `isTool(item)` accepts that `character` would work with: the one in their
--- primary hand, else the first they carry, bags included; nil when they carry none.
function Items.toolFor(character, isTool)
    local held = character:getPrimaryHandItem()
    if held and isTool(held) then
        return held
    end
    return character:getInventory():getFirstEvalRecurse(isTool)
end

--- The first item of each of `fullTypes` that `character` carries, bags included, in that order;
--- with `keep(fullType)`, of those it accepts only.
function Items.firstOfEach(character, fullTypes, keep)
    local inventory, found = character:getInventory(), {}
    for _, fullType in ipairs(fullTypes) do
        local item = (not keep or keep(fullType)) and inventory:getFirstTypeRecurse(fullType)
        if item then
            table.insert(found, item)
        end
    end
    return found
end

--- Takes `item` out of the container that holds it, if any, and tells the clients. Authority only.
function Items.removeItem(item)
    local container = item:getContainer()
    if container then
        container:Remove(item)
        sendRemoveItemFromContainer(container, item)
    end
end

--- Puts `itemOrType`, an item or a full type, in `container` and tells the clients. Returns the
--- item, or nil when the type names none. Authority only.
function Items.addItem(container, itemOrType)
    local item = container:AddItem(itemOrType)
    if item then
        sendAddItemToContainer(container, item)
    end
    return item
end

--- Takes `item` from `character`: out of their hands and out of the container that holds it, and
--- tells the clients. Authority only.
function Items.takeItem(character, item)
    character:removeFromHands(item)
    Items.removeItem(item)
end

--- Gives `character` `count` (default 1) of `itemOrType`, an item or a full type, dropping on
--- their square what doesn't fit (Actions.addOrDropItem, which also syncs). Authority only.
function Items.giveItems(character, itemOrType, count)
    for _ = 1, count or 1 do
        local item = type(itemOrType) == "string" and instanceItem(itemOrType) or itemOrType
        Actions.addOrDropItem(character, item)
    end
end

--- Drops `itemOrType`, an item or a full type, on `square` at a random spot, as dropped items lie.
--- Returns the item. The spot draws on ZombRandFloat rather than Chance.roll, so a test's set
--- rolls go only to the chances it means. Authority only.
function Items.dropOn(square, itemOrType)
    return square:AddWorldInventoryItem(itemOrType, ZombRandFloat(0.2, 0.8), ZombRandFloat(0.2, 0.8), 0)
end

--- The first item a build consumed, by its recipe data `craftRecipeData` (an entity's OnCreate
--- params.craftRecipeData; nil for a build the world made), for which `matches(item)` holds, or
--- nil: which of the inputs the build menu let the player choose went in.
function Items.firstConsumed(craftRecipeData, matches)
    local used = craftRecipeData and craftRecipeData:getAllConsumedItems()
    for i = 0, (used and used:size() or 0) - 1 do
        if matches(used:get(i)) then
            return used:get(i)
        end
    end
    return nil
end

--- The first input of a craft, by its recipe data `craftRecipeData` (a craft's OnCreate argument),
--- for which `matches(item)` holds, or nil: which of the items the recipe let the player choose
--- went in.
function Items.firstInput(craftRecipeData, matches)
    local inputs = craftRecipeData:getAllInputItems()
    for i = 0, inputs:size() - 1 do
        if matches(inputs:get(i)) then
            return inputs:get(i)
        end
    end
    return nil
end

-- Item ConditionMax by full type, read once from the item scripts.
local CONDITION_MAX = {}

--- The ConditionMax of items of `fullType`, as its item script gives it; 100 for a type with none.
function Items.conditionMaxOf(fullType)
    if not CONDITION_MAX[fullType] then
        local script = getScriptManager():FindItem(fullType)
        CONDITION_MAX[fullType] = script and script:getConditionMax() or 100
    end
    return CONDITION_MAX[fullType]
end

return Items
