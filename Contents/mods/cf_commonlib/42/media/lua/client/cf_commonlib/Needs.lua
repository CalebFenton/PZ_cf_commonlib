-- An option's tooltip saying why it is greyed out, and what it does.
--
-- Vanilla explains a greyed-out option two ways. One state or tool holding it back is a plain
-- sentence (Needs.refuse), as the generator's options say. A job that takes several things lists
-- them as vanilla lists what fixing an item takes (ISInventoryPaneContextMenu, "Needs" over a line
-- per need) and the mechanics window colours it (ISVehicleMechanics.doMenuTooltip): "<what>
-- <have>/<need>" in the good colour when the character has enough and the bad colour when short
-- (Needs.show). Both take what a job's shared refusal functions return, translation keys and need
-- lists (Materials.needs), so the menu greys an option exactly when the job's action and the
-- authority refuse it.

require "ISUI/ISWorldObjectContextMenu"
require "Vehicles/ISUI/ISVehicleMechanics"
local Materials = require "cf_commonlib/Materials"

local Needs = {}

local function nameOf(need)
    if need.label then
        return need.label
    elseif need.labelKey then
        return getText(need.labelKey)
    elseif need.perk then
        return need.perk:getName()
    elseif need.item then
        return getItemNameFromFullType(need.item)
    end
    return need.input:getPossibleInputItems():get(0):getDisplayName()
end

local function colourOf(need)
    return need.have >= need.need and ISVehicleMechanics.ghs or ISVehicleMechanics.bhs
end

local function counted(need)
    return colourOf(need) .. nameOf(need) .. " " .. need.have .. "/" .. need.need
end

-- One need's line; a recipe gets vanilla's recipe line, which has no count, and a need any of
-- several meets (`anyOf`) gets theirs in a row, each in its own colour, joined by the crafting
-- window's "or" (ISWidgetTitleHeader). Rich text drops the space before a tag and starts the next
-- words where the last ones end (ISRichTextPanel.paginate), so each colour change mid-line comes
-- after a <SPACE> tag, which keeps the gap.
local function line(need)
    if need.recipe then
        return " " .. colourOf(need) .. " " .. getText("Tooltip_vehicle_requireRecipe", need.recipe:getTranslationName()) .. " <LINE>"
    end
    if need.anyOf then
        local options = {}
        for _, option in ipairs(need.anyOf) do
            table.insert(options, counted(option))
        end
        return " " .. table.concat(options, " <SPACE> " .. colourOf(need) .. getText("IGUI_CraftingWindow_Or") .. " <SPACE> ") .. " <LINE>"
    end
    return " " .. counted(need) .. " <LINE>"
end

-- Sets `option`'s tooltip to `text`, under what the option does when Needs.describe said it.
local function setTooltip(option, text)
    local about = option.about
    option.toolTip = option.toolTip or ISWorldObjectContextMenu.addToolTip()
    option.toolTip.description = about and text and (about .. " <LINE> <LINE> " .. text) or about or text
end

--- Heads `option`'s tooltip with what it does, the sentence of the translation key `key`, as
--- vanilla's crafting recipes say above what they take; a refusal or needs shown later go under it.
function Needs.describe(option, key)
    option.about = getText(key)
    setTooltip(option, nil)
end

--- Greys `option` out with the sentence of the translation key `key` (`...` its arguments). Does
--- nothing when `key` is nil or false, so a refusal function's answer passes straight in.
function Needs.refuse(option, key, ...)
    if not key then return end
    option.notAvailable = true
    setTooltip(option, getText(key, ...))
end

--- `key` (the mod's "too dark" translation key) when the job needs light to see by (`needsLight`)
--- and `character` stands in the dark, else nil. Only the player's own side can tell
--- (IsoPlayer.tooDarkToRead is false for a remote player), so the menu checks it, not a refusal.
function Needs.tooDark(character, needsLight, key)
    if needsLight and character:tooDarkToRead() then
        return key
    end
    return nil
end

--- An option whose job takes several things (skill, tools, materials) lists them all with have and
--- need, so the character sees everything they lack at once, and is greyed out while any is short.
--- A `blocker` (a translation key) that no amount of carrying fixes replaces the list with its
--- sentence.
function Needs.show(option, needs, blocker)
    if blocker then
        Needs.refuse(option, blocker)
        return
    end
    if #needs == 0 then return end
    option.notAvailable = Materials.firstUnmet(needs) ~= nil
    local text = getText("Tooltip_craft_Needs") .. " : <LINE>"
    for _, need in ipairs(needs) do
        text = text .. line(need)
    end
    setTooltip(option, text)
end

return Needs
