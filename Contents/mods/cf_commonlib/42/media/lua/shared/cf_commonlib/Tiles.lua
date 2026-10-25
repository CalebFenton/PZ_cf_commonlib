-- How a placed object looks: its tile, its entity and its overlays, changed on the authority and
-- sent on to the clients.

local Tables = require "cf_commonlib/Tables"

local Tiles = {}

--- The game entity script whose SpriteConfig names the tile `spriteName`, or nil: what an object
--- on that tile is, found as vanilla's MORainCollectorBarrel finds it.
function Tiles.tileEntity(spriteName)
    local info = SpriteConfigManager.getObjectInfoFromSprite(spriteName)
    return info and info:getScript():getParent()
end

-- The tile's own sprite, with its properties; setSprite(name) would make a bare texture.
local function setTileSprite(isoObject, spriteName)
    isoObject:setSprite(getSprite(spriteName))
end

--- Shows `isoObject` as the tile `spriteName` and sends the change to the clients (a server's
--- transmitUpdatedSpriteToClients; nothing in single player), unless it shows that tile already.
--- Authority only.
function Tiles.showTile(isoObject, spriteName)
    local sprite = isoObject:getSprite()
    if sprite and sprite:getName() == spriteName then return end
    setTileSprite(isoObject, spriteName)
    isoObject:transmitUpdatedSpriteToClients()
end

--- Shows the entity `isoObject` as the tile `spriteName` and makes it that tile's entity
--- (tileEntity). A SpriteConfig takes only its own entity's tiles: one left on another tile is
--- disowned with a warning wherever the object loads, on each client and after each reload
--- (SpriteConfig.initObjectInfo). Authority only; the caller sends the object on.
function Tiles.setEntityTile(isoObject, spriteName)
    setTileSprite(isoObject, spriteName)
    local script = Tiles.tileEntity(spriteName)
    if not script or isoObject:getEntityScript() == script then return end
    -- By type, as removing one shifts the others' indexes; CreateIsoObjectEntity wants none left.
    local types = {}
    for i = 0, isoObject:componentSize() - 1 do
        table.insert(types, isoObject:getComponentForIndex(i):getComponentType())
    end
    for _, componentType in ipairs(types) do
        GameEntityFactory.RemoveComponentType(isoObject, componentType)
    end
    GameEntityFactory.CreateIsoObjectEntity(isoObject, script, true)
end

--- Shows `wanted` (a list of sprite names, in drawing order) as the overlays of the kind
--- `isKind(name)` tells on `isoObject`, and sends the tile on when that changes it. Authority only.
function Tiles.showOverlays(isoObject, isKind, wanted)
    local attached = isoObject:getAttachedAnimSprite()
    local count = attached and attached:size() or 0
    local shown = {}
    for i = 0, count - 1 do
        local name = attached:get(i):getName()
        if isKind(name) then
            table.insert(shown, name)
        end
    end
    if Tables.sameValue(shown, wanted) then return end
    for i = count - 1, 0, -1 do
        if isKind(attached:get(i):getName()) then
            isoObject:RemoveAttachedAnim(i)
        end
    end
    for _, name in ipairs(wanted) do
        isoObject:addAttachedAnimSpriteByName(name)
    end
    isoObject:transmitUpdatedSpriteToClients()
end

--- Shows `wanted` (a sprite name, or nil for none) as the one overlay of the kind `isKind(name)`
--- tells on `isoObject`, as showOverlays does.
function Tiles.showOverlay(isoObject, isKind, wanted)
    Tiles.showOverlays(isoObject, isKind, wanted and { wanted } or {})
end

return Tiles
