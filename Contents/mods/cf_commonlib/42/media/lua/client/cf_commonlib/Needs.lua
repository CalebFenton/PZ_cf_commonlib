-- The idioms every right-click menu shares: finding the clicked object, a submenu, and an option
-- greyed out saying why.
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
local Squares = require "cf_commonlib/Squares"
local Materials = require "cf_commonlib/Materials"

local Needs = {}

-- An item to name for each tool tag, as vanilla names the wrench its jobs take.
local TOOL_ITEMS = { WRENCH = "Base.Wrench", SCREWDRIVER = "Base.Screwdriver" }

local function nameOf(need)
    if need.label then
        return need.label
    elseif need.labelKey then
        return getText(need.labelKey)
    elseif need.perk then
        return need.perk:getName()
    elseif need.tool then
        return getItemNameFromFullType(TOOL_ITEMS[need.tool] or need.item)
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

local function setTooltip(option, description)
    option.toolTip = ISWorldObjectContextMenu.addToolTip()
    option.toolTip.description = description
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
--- sentence. A job that takes nothing gets no tooltip.
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

--- Adds an option named `name` to `context` that opens a new submenu. Returns the submenu and the
--- option.
function Needs.addSubMenu(context, name)
    local submenu = ISContextMenu:getNew(context)
    local option = context:addOption(name)
    context:addSubMenu(option, submenu)
    return submenu, option
end

--- The submenu of `context`'s option named `name` (its text, as the game filled it before the
--- mod's hook ran), or nil: where a mod's options join vanilla's own for the same object.
function Needs.subMenuOf(context, name)
    local option = name and context:getOptionFromName(name)
    return option and option.subOption and context:getSubMenu(option.subOption) or nil
end

--- The first object on the right-clicked squares for which `matches(object)` is true, or nil.
function Needs.findClicked(worldobjects, matches)
    local seen = {}
    for _, clicked in ipairs(worldobjects) do
        local square = clicked:getSquare()
        if square and not seen[square] then
            seen[square] = true
            local found = Squares.findObjectOn(square, matches)
            if found then
                return found
            end
        end
    end
    return nil
end

return Needs
