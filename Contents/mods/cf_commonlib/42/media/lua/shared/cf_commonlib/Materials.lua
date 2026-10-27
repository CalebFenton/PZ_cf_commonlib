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
--   { craft = name, twins, except }       a craftRecipe done in place rather than in the crafting
--                                         window: known, its required skills and its inputs but
--                                         those `except(input)` leaves out (what the job works
--                                         on), paid as the craft pays them; it teaches the
--                                         recipe's XP. `twins`, if any, lists it and recipes that
--                                         differ from it in one input only, in the order tried:
--                                         the first the character carries every input of pays.
-- A `labelKey` (an IG_UI key; a water material must have one) names the material in the tooltip
-- in place of its item, and several `types` are named together when it has none.
--
-- Each need is { kind, have, need } with what names it: kind "skill" with `perk`, "recipe" with
-- `recipe` (the CraftRecipe; have 1 when known), "tool" with `tool` and `item`, "water", or "item"
-- with `item`, or a craft's `input` (an InputScript) or `anyOf` (its twins' needs for the input
-- they differ in, one of which suffices); and `label` or `labelKey` where the material gives one.

local Items = require "cf_commonlib/Items"
local Tables = require "cf_commonlib/Tables"

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
-- up; ordered only when a job draws on or equips them, not when a menu counts them.
local function drainablesOf(character, material, ordered)
    local list, seen = {}, {}
    local inventory = character:getInventory()
    for _, tag in ipairs(material.tags or {}) do
        addDrainables(list, seen, inventory:getAllTagRecurse(ItemTag[tag], ArrayList.new()))
    end
    for _, fullType in ipairs(material.types or { material.item }) do
        addDrainables(list, seen, inventory:getAllTypeRecurse(fullType))
    end
    if ordered then
        table.sort(list, function(a, b) return a:getCurrentUses() > b:getCurrentUses() end)
    end
    return list
end

local function isBag(item)
    return instanceof(item, "InventoryContainer")
end

-- Keep the game's clean/carbonated-water policy, but include every carried bag: the native
-- water-source query, unlike the other material queries, doesn't recurse.
local function waterSources(character, ordered)
    local inventory = character:getInventory()
    local list = Tables.fromList(inventory:getAllWaterFluidSources(false))
    local bags = inventory:getAllEvalRecurse(isBag)
    for i = 0, bags:size() - 1 do
        Tables.fromList(bags:get(i):getInventory():getAllWaterFluidSources(false), nil, list)
    end
    if ordered then
        table.sort(list, function(a, b)
            return a:getFluidContainer():getAmount() > b:getFluidContainer():getAmount()
        end)
    end
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
        Tables.fromList(inventory:getSomeTypeRecurse(fullType, left), nil, taken)
        left = (material.need or 1) - #taken
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
    elseif material.water or material.uses then
        local have = 0
        local sources = material.water and waterSources(character) or drainablesOf(character, material)
        for _, item in ipairs(sources) do
            have = have + (material.water and item:getFluidContainer():getAmount() or item:getCurrentUses())
        end
        return material.water and math.floor(have * 10) / 10 or have
    end
    local have = 0
    for _, fullType in ipairs(material.types or { material.item }) do
        have = have + inventory:getCountTypeRecurse(fullType)
    end
    return have
end

-- As CraftRecipeData.processKeepInputItem wears kept tools: the factor for each MayDegrade flag.
local function wearOf(input)
    if input:mayDegradeHeavy() then return 1 end
    if input:mayDegrade() then return 2 end
    if input:mayDegradeLight() then return 3 end
    if input:mayDegradeVeryLight() then return 6 end
    return nil
end

-- The rounding CraftRecipeData.consumeInputFromItems forgives when scaled uses pay an input.
local PAID_TOLERANCE = 1e-5

-- What `recipe` takes of the character's inventory, bags included, but the inputs `except(input)`
-- leaves out: the items that pay its inputs, nil when one is missing, and each input as a need.
-- As CraftRecipeData.consumeInputFromItems and processDestroyAndUsedItems do, several part-used
-- drainables add up to one input, each giving the uses it has until the input is paid.
local function craftInputs(recipe, character, except)
    local inputs = recipe:getInputs()
    local picks, taken, needs, complete = {}, {}, {}, true
    for i = 0, inputs:size() - 1 do
        local input = inputs:get(i)
        if not (except and except(input)) then
            local amount = input:getIntAmount()
            local needed = amount
            local candidates = character:getInventory():getAllEvalRecurse(function(item)
                return not taken[item] and CraftRecipeManager.isItemValidForInputScript(input, item, character)
            end)
            for j = 0, candidates:size() - 1 do
                if needed <= PAID_TOLERANCE then break end
                local item = candidates:get(j)
                if instanceof(item, "DrainableComboItem") then
                    -- A line such as [Base.Epoxy;2:Base.Glue] takes more uses of some items.
                    local scale = input:getRelativeScale(item:getFullType())
                    local uses = math.min(item:getCurrentUses(), math.ceil(needed * scale))
                    if uses > 0 then
                        table.insert(picks, { item = item, uses = uses, keep = input:isKeep() })
                        taken[item], needed = true, needed - uses / scale
                    end
                else
                    table.insert(picks, { item = item, keep = input:isKeep(), wear = wearOf(input) })
                    taken[item], needed = true, needed - 1
                end
            end
            local paid = needed <= PAID_TOLERANCE
            table.insert(needs, { kind = "item", input = input, have = paid and amount or math.floor(amount - needed), need = amount })
            complete = complete and paid
        end
    end
    return complete and picks or nil, needs
end

-- What the craft material `material` takes of the character's inventory: the items of the first
-- twin the character carries every input of, each { item, uses, keep, wear } (nil when none is
-- paid), and the inputs as needs, an input the twins differ in being one need any of theirs meets.
-- Since they differ in that input only, it is met exactly when a twin is.
local function craftPayment(character, material)
    local paid, byRecipe = nil, {}
    for _, name in ipairs(material.twins or { material.craft }) do
        local picks, needs = craftInputs(getScriptManager():getCraftRecipe(name), character, material.except)
        paid = paid or picks
        table.insert(byRecipe, needs)
    end
    local needs = {}
    for i, need in ipairs(byRecipe[1]) do
        local options, met, same = {}, false, true
        for _, recipeNeeds in ipairs(byRecipe) do
            local option = recipeNeeds[i]
            table.insert(options, option)
            met = met or option.have >= option.need
            same = same and option.input:getOriginalLine() == need.input:getOriginalLine()
        end
        table.insert(needs, same and need or { kind = "item", anyOf = options, have = met and 1 or 0, need = 1 })
    end
    return paid, needs
end

-- The craft material's needs onto `needs`: the recipe known, its skills, its inputs.
local function addCraftNeeds(needs, character, material)
    local recipe = getScriptManager():getCraftRecipe(material.craft)
    table.insert(needs, { kind = "recipe", recipe = recipe, have = character:isRecipeKnown(recipe) and 1 or 0, need = 1 })
    for i = 0, recipe:getRequiredSkillCount() - 1 do
        local skill = recipe:getRequiredSkill(i)
        table.insert(needs, { kind = "skill", perk = skill:getPerk(), have = character:getPerkLevel(skill:getPerk()), need = skill:getLevel() })
    end
    local _, inputs = craftPayment(character, material)
    for _, need in ipairs(inputs) do
        table.insert(needs, need)
    end
end

-- Pays the craft material's inputs as its craft would: kept tools may wear as its craft wears
-- them, the rest are used up; then teaches the recipe's XP.
local function payCraft(character, material)
    local recipe = getScriptManager():getCraftRecipe(material.craft)
    for _, pick in ipairs(craftPayment(character, material) or {}) do
        if pick.keep and pick.wear then
            local skill = recipe:getHighestRelevantSkillLevel(character) + pick.item:getMaintenanceMod(character)
            pick.item:damageCheck(skill, pick.wear, false)
            pick.item:syncItemFields()
        elseif not pick.keep then
            for _ = 1, pick.uses or 1 do
                pick.item:UseAndSync()
            end
        end
    end
    recipe:addXP(character)
end

local function needOf(character, material)
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
    return need
end

--- What `list` (nil for nothing) takes of `character`, as needs (see the header).
function Materials.needs(character, list)
    local needs = {}
    for _, material in ipairs(list or {}) do
        if material.craft then
            addCraftNeeds(needs, character, material)
        else
            table.insert(needs, needOf(character, material))
        end
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
    for _, item in ipairs(waterSources(character, true)) do
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
    for _, item in ipairs(drainablesOf(character, material, true)) do
        while left > 0 and item:getCurrentUses() > 0 do
            item:UseAndSync()
            left = left - 1
        end
        if left <= 0 then
            return
        end
    end
end

--- Takes from `character` what `list` (nil for nothing) uses up, once its needs were checked, and
--- teaches a craft's XP. Authority only.
function Materials.consume(character, list)
    local inventory = character:getInventory()
    for _, material in ipairs(list or {}) do
        if material.craft then
            payCraft(character, material)
        elseif material.water then
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
        return drainablesOf(character, drainable, true)[1]
    end
end

return Materials
