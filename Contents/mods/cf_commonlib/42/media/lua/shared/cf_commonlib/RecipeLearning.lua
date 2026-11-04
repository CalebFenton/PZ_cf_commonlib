-- Teaching mods' recipes by skill level (their AutoLearnAny and AutoLearnAll), and by the
-- literature a character has read. Shared: vanilla's own AutoLearn check runs wherever LevelPerk
-- fires (XpUpdate.lua, which every side loads).
--
-- Vanilla's check (ScriptManager.checkAutoLearn) walks only the craftRecipe scripts, and an
-- entity's build recipe is not one of them (CraftRecipeComponentScript.load builds it apart), so
-- without this no build recipe is ever learned by level. The craftRecipes are checked here too, so
-- that a level up on a multiplayer server that teaches one reaches the client whichever LevelPerk
-- hook runs first. Every mod that registers shares one set of hooks and one catch-up command, so
-- a level up sends the known recipes once however many mods learn by it.
--
-- Vanilla teaches a magazine's LearnedRecipes on the first read only: ISReadABook:complete skips
-- ReadLiterature for a title the character has read, and a magazine's title is its full type
-- (ItemCodeOnCreate.onCreateRecipeMagazine). A recipe a mod adds to a magazine's list after a
-- character read it would never reach that character, so the catch-up teaches what each read
-- magazine lists now.

local RecipeLearning = {}

-- The recipes with an AutoLearn skill of every registered prefix, and the perks those skills name,
-- by perk id.
local AUTO_LEARN, AUTO_LEARN_PERKS, PREFIXES = {}, {}, {}

-- The recipes of every registered prefix that each item teaches when read (its script's
-- LearnedRecipes), by the item's full type.
local READ_TEACHES = {}

-- The packet field of sendSyncPlayerFields that sends the known recipes (SyncPlayerFieldsPacket).
local SYNC_RECIPES = 1

--- The client command that asks the server to catch a joining character up (RecipeLearning.catchUp).
RecipeLearning.COMMAND_MODULE, RecipeLearning.CATCH_UP = "cf_commonlib", "catchUpRecipes"

local function notePerks(recipe)
    for i = 0, recipe:getAutoLearnAnySkillCount() - 1 do
        AUTO_LEARN_PERKS[recipe:getAutoLearnAnySkill(i):getPerk():getId()] = true
    end
    for i = 0, recipe:getAutoLearnAllSkillCount() - 1 do
        AUTO_LEARN_PERKS[recipe:getAutoLearnAllSkill(i):getPerk():getId()] = true
    end
end

--- Has the craftRecipes and build recipes whose names start with `prefix` learned by their
--- AutoLearn skills, and by any literature listing them that the character has read. Read from the
--- scripts, which each side loads before its Lua, so a mod calls this as its file loads. A prefix
--- registered again adds nothing.
function RecipeLearning.register(prefix)
    if PREFIXES[prefix] then return end
    PREFIXES[prefix] = true
    local scripts = getScriptManager()
    for _, recipes in ipairs({ scripts:getAllCraftRecipes(), scripts:getAllBuildableRecipes() }) do
        for i = 0, recipes:size() - 1 do
            local recipe = recipes:get(i)
            if recipe:getName():sub(1, #prefix) == prefix
                    and recipe:getAutoLearnAnySkillCount() + recipe:getAutoLearnAllSkillCount() > 0 then
                table.insert(AUTO_LEARN, recipe)
                notePerks(recipe)
            end
        end
    end
    local items = scripts:getAllItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local learned = item:getLearnedRecipes()
        for j = 0, (learned and learned:size() or 0) - 1 do
            local name = learned:get(j)
            if name:sub(1, #prefix) == prefix then
                local fullType = item:getFullName()
                READ_TEACHES[fullType] = READ_TEACHES[fullType] or {}
                table.insert(READ_TEACHES[fullType], name)
            end
        end
    end
end

-- Teaches `character` each registered recipe whose AutoLearn skills it has, through the recipe's
-- own check, so the Inventive trait counts as it does for vanilla's recipes.
local function autoLearn(character)
    for _, recipe in ipairs(AUTO_LEARN) do
        recipe:checkAutoLearnAnySkills(character)
        recipe:checkAutoLearnAllSkills(character)
    end
end

-- Teaches `character` every registered recipe that literature it has read lists, by vanilla's two
-- records of a read: the items whose recipes it read (ISReadABook:complete) and the titles it read.
-- Returns whether it taught any.
local function readLearn(character)
    local taught, known, read = false, character:getKnownRecipes(), character:getAlreadyReadBook()
    for fullType, names in pairs(READ_TEACHES) do
        if read:contains(fullType) or character:isLiteratureRead(fullType) then
            for _, name in ipairs(names) do
                if not known:contains(name) then
                    character:learnRecipe(name)
                    taught = true
                end
            end
        end
    end
    return taught
end

-- By the CraftRecipe, so a recipe known through its MetaRecipe counts.
local function knownCount(character)
    local count = 0
    for _, recipe in ipairs(AUTO_LEARN) do
        if character:isRecipeActuallyKnown(recipe) then
            count = count + 1
        end
    end
    return count
end

--- Teaches `character` what its levels and the literature it has read already earn, and on a
--- multiplayer server sends its client what that changed. A server runs no check of its own when a
--- player joins (IsoWorld.init checks the local player only, and no event marks a join on the
--- server), so a character who earned a recipe before a mod was added, or before this check
--- existed, or read a magazine before a mod added a recipe to it, would otherwise know it only on
--- its client, or not at all, and the server would refuse the build. The client asks for this as it
--- enters the world; the server judges by its own copy's levels and reads.
function RecipeLearning.catchUp(character)
    local before = knownCount(character)
    autoLearn(character)
    local taught = readLearn(character)
    if isServer() and (taught or knownCount(character) ~= before) then
        sendSyncPlayerFields(character, SYNC_RECIPES)
    end
end

-- When vanilla checks its own AutoLearn: on every level up (XpUpdate.levelPerk) and when the
-- local player enters the world (IsoWorld.init), here OnCreatePlayer, which on a multiplayer client
-- also asks the server to catch up.
--
-- On a multiplayer server, a level up of a perk the AutoLearn skills name sends the client its
-- known recipes: the server's level up teaches only its own copy of the character, since the
-- client's copy gets the new level in PlayerXpPacket, which fires no LevelPerk, and learnRecipe
-- sends nothing (ISResearchRecipe sends what it taught the same way). It is sent whether or not
-- this hook taught anything: vanilla's own hook may have taught a craftRecipe first, and a level up
-- can teach a recipe of a lower level that the character was never taught.
Events.LevelPerk.Add(function(character, perk)
    autoLearn(character)
    if isServer() and AUTO_LEARN_PERKS[perk:getId()] then
        sendSyncPlayerFields(character, SYNC_RECIPES)
    end
end)
Events.OnCreatePlayer.Add(function(playerNum)
    local character = getSpecificPlayer(playerNum)
    autoLearn(character)
    readLearn(character)
    if isClient() then
        sendClientCommand(character, RecipeLearning.COMMAND_MODULE, RecipeLearning.CATCH_UP, {})
    end
end)
Events.OnClientCommand.Add(function(module, command, player)
    if module == RecipeLearning.COMMAND_MODULE and command == RecipeLearning.CATCH_UP then
        RecipeLearning.catchUp(player)
    end
end)

return RecipeLearning
