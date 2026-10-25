-- What a job takes of the character, written once as data (a materials list) and read two ways:
-- as needs, which the menu shows and the refusal checks (Materials.firstUnmet), and, on the
-- authority, as what the job uses up. Reading both from one list keeps them from disagreeing.
--
-- A material is one of:
--   { perk = "Name", need = level }       a skill level (Perks[Name]); takes nothing
--   { recipe = name }                     a craftRecipe the character knows; takes nothing
--   { tool = "TAG", item = fullType }     a working tool with the ItemTag, `item` naming it in the
--                                         tooltip; `useOne` takes one use of it, as a match
--   { tag = "TAG", item = fullType }      an unbroken item with the ItemTag, taken
--   { water = litres }                    water in any carried container, poured out
--   { uses = n, item | types | tags }     n uses of unbroken drainables of the type `item`, of any
--                                         of the full types `types` or with any of the ItemTags
--                                         `tags`, drawn fullest first, as a joint takes glue
--   { item = fullType, need = n }         items of a type, taken; `types` lets any of several
--                                         types count; `keep` needs them but takes nothing
-- A `labelKey` (an IG_UI key; a water material must have one) names the material in the tooltip
-- in place of its item, and several `types` are named together when it has none.
--
-- Each need is { kind, have, need } with what names it: kind "skill" with `perk`, "recipe" with
-- `recipe` (the CraftRecipe; have 1 when known), "tool" with `tool` and `item`, "water", or "item"
-- with `item`; and `label` or `labelKey` where the material gives one. A mod may add needs of its
-- own to a list, such as `input` (an InputScript) or `anyOf` (a list of needs, one of which
-- suffices), which the menus name too.

local Items = require "cf_commonlib/Items"

local Materials = {}

local function addDrainables(list, seen, items)
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if not seen[item] and instanceof(item, "DrainableComboItem") and item:getCurrentUses() > 0
                and not item:isBroken() then
            seen[item] = true
            table.insert(list, item)
        end
    end
end

-- The drainables the material `material` names that the character carries, unbroken and not used
-- up, fullest first: the order consume draws on them.
local function drainablesOf(character, material)
    local list, seen = {}, {}
    local inventory = character:getInventory()
    for _, tag in ipairs(material.tags or {}) do
        addDrainables(list, seen, inventory:getAllTagRecurse(ItemTag[tag], ArrayList.new()))
    end
    for _, fullType in ipairs(material.types or { material.item }) do
        addDrainables(list, seen, inventory:getAllTypeRecurse(fullType))
    end
    table.sort(list, function(a, b) return a:getCurrentUses() > b:getCurrentUses() end)
    return list
end

-- The containers of water the character carries, most first.
local function waterSources(character)
    local list = {}
    local sources = character:getInventory():getAllWaterFluidSources(false)
    for i = 0, sources:size() - 1 do
        table.insert(list, sources:get(i))
    end
    table.sort(list, function(a, b)
        return a:getFluidContainer():getAmount() > b:getFluidContainer():getAmount()
    end)
    return list
end

-- Whether `material` is items taken by type, rather than a skill, recipe, tool, tag, water or uses.
local function takesItems(material)
    return material.item ~= nil and not (material.keep or material.tool or material.tag or material.uses)
end

-- The items the item material `material` takes of `inventory`, in the order consume takes them:
-- the first of its types first.
local function itemsTaken(inventory, material)
    local taken, left = {}, material.need or 1
    for _, fullType in ipairs(material.types or { material.item }) do
        if left <= 0 then
            break
        end
        local items = inventory:getSomeTypeRecurse(fullType, left)
        for i = 0, items:size() - 1 do
            table.insert(taken, items:get(i))
        end
        left = left - items:size()
    end
    return taken
end

local function haveOf(character, material)
    local inventory = character:getInventory()
    if material.perk then
        return character:getPerkLevel(Perks[material.perk])
    elseif material.recipe then
        return character:isRecipeActuallyKnown(material.recipe) and 1 or 0
    elseif material.tool then
        return Items.workingTool(character, ItemTag[material.tool]) and 1 or 0
    elseif material.tag then
        return inventory:getCountTagEvalRecurse(ItemTag[material.tag], Items.notBroken)
    elseif material.water then
        local litres = 0
        for _, item in ipairs(waterSources(character)) do
            litres = litres + item:getFluidContainer():getAmount()
        end
        return math.floor(litres * 10) / 10
    elseif material.uses then
        local uses = 0
        for _, item in ipairs(drainablesOf(character, material)) do
            uses = uses + item:getCurrentUses()
        end
        return uses
    end
    local have = 0
    for _, fullType in ipairs(material.types or { material.item }) do
        have = have + inventory:getCountTypeRecurse(fullType)
    end
    return have
end

--- What `list` (nil for nothing) takes of `character`, as needs (see the header).
function Materials.needs(character, list)
    local needs = {}
    for _, material in ipairs(list or {}) do
        local need = {
            have = haveOf(character, material),
            need = material.water or material.uses or material.need or 1,
            -- A key, not the text: the server reads needs too and has no IG_UI translations.
            labelKey = material.labelKey,
        }
        if material.perk then
            need.kind, need.perk = "skill", Perks[material.perk]
        elseif material.recipe then
            need.kind, need.recipe = "recipe", getScriptManager():getCraftRecipe(material.recipe)
        elseif material.tool then
            need.kind, need.tool, need.item = "tool", material.tool, material.item
        elseif material.water then
            need.kind = "water"
        else
            need.kind, need.item = "item", material.item
            if material.types and not material.labelKey then
                local names = {}
                for _, fullType in ipairs(material.types) do
                    table.insert(names, getItemNameFromFullType(fullType))
                end
                need.label = table.concat(names, " / ")
            end
        end
        table.insert(needs, need)
    end
    return needs
end

--- The first of `needs` the character is short of, or nil when they have them all.
function Materials.firstUnmet(needs)
    for _, need in ipairs(needs) do
        if need.have < need.need then
            return need
        end
    end
    return nil
end

--- The kind of the first of `needs` the character is short of, or nil when they have them all.
function Materials.unmetKind(needs)
    local short = Materials.firstUnmet(needs)
    return short and short.kind
end

--- The conditions of the items `list` would take of `character`, one each in the order taken:
--- what a job that keeps them can give back as worn as they went in.
function Materials.conditions(character, list)
    local inventory, conditions = character:getInventory(), {}
    for _, material in ipairs(list or {}) do
        if takesItems(material) then
            for _, item in ipairs(itemsTaken(inventory, material)) do
                table.insert(conditions, item:getCondition())
            end
        end
    end
    return conditions
end

local function pourWater(character, litres)
    local left = litres
    for _, item in ipairs(waterSources(character)) do
        local fluid = item:getFluidContainer()
        local take = math.min(left, fluid:getAmount())
        if take > 0 then
            fluid:removeFluid(take, false)
            item:syncItemFields()
            left = left - take
        end
        if left <= 0 then
            return
        end
    end
end

local function useDrainables(character, material)
    local left = material.uses
    for _, item in ipairs(drainablesOf(character, material)) do
        while left > 0 and item:getCurrentUses() > 0 do
            item:UseAndSync()
            left = left - 1
        end
        if left <= 0 then
            return
        end
    end
end

--- Takes from `character` what `list` (nil for nothing) uses up, once its needs were checked.
--- Authority only.
function Materials.consume(character, list)
    local inventory = character:getInventory()
    for _, material in ipairs(list or {}) do
        if material.water then
            pourWater(character, material.water)
        elseif material.tool then
            local tool = material.useOne and Items.workingTool(character, ItemTag[material.tool])
            if tool and instanceof(tool, "DrainableComboItem") then
                tool:UseAndSync()
            end
        elseif material.tag then
            local item = inventory:getFirstTagEvalRecurse(ItemTag[material.tag], Items.notBroken)
            if item then
                Items.takeItem(character, item)
            end
        elseif material.uses then
            useDrainables(character, material)
        elseif takesItems(material) then
            for _, item in ipairs(itemsTaken(inventory, material)) do
                Items.takeItem(character, item)
            end
        end
    end
end

--- A job row's `equip` (JobAction) holding the working tool the material `tool` names.
function Materials.holds(tool)
    return function(character)
        return Items.workingTool(character, ItemTag[tool.tool])
    end
end

--- A job row's `equip` holding the fullest of the drainables the material `drainable` names, the
--- one consume draws on first.
function Materials.holdsDrainable(drainable)
    return function(character)
        return drainablesOf(character, drainable)[1]
    end
end

return Materials
