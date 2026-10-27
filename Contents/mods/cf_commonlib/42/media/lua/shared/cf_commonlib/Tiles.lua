-- Placed objects' tiles: what runs as they load, what entity a tile is, and how an object looks
-- (its tile, its entity and its overlays), changed on the authority and sent on to the clients.

local Tables = require "cf_commonlib/Tables"

local Tiles = {}

--- The game entity script whose SpriteConfig names the tile `spriteName`, or nil: what an object
--- on that tile is, found as vanilla's MORainCollectorBarrel finds it.
function Tiles.tileEntity(spriteName)
    local info = SpriteConfigManager.getObjectInfoFromSprite(spriteName)
    return info and info:getScript():getParent()
end

--- A new thumpable of the tile `spriteName` on `square`, with the entity that owns the tile
--- (tileEntity) and its components, as the build menu makes one (ISBuildIsoEntity); not yet added
--- to the square, nor sent. Nil when no entity owns the tile.
function Tiles.newEntity(square, spriteName)
    local script = Tiles.tileEntity(spriteName)
    if not script then
        return nil
    end
    local thumpable = IsoThumpable.new(square:getCell(), square, spriteName, false, nil)
    GameEntityFactory.CreateIsoObjectEntity(thumpable, script, true)
    return thumpable
end

--- Adds `isoObject`, made in code on the authority, to `square` as a special object, at
--- `options.index` on it (on top if nil), and publishes it in the order the engine needs:
--- `options.beforeSend(isoObject)` finishes it on the square; the clients get it (a server's
--- transmitCompleteItemToClients; nothing in single player); `options.afterSend(isoObject)` makes
--- the changes that sync by its index on the square, which a client drops for an object it hasn't
--- got yet; then OnObjectAdded fires, which the game fires only for an object a client sends
--- (AddItemToMapPacket), as vanilla's TrapBO fires it. `options.announce == false` leaves that to
--- the caller's own code, such as a build menu OnCreate that fires it. Authority only. Returns
--- isoObject.
function Tiles.addToWorld(square, isoObject, options)
    options = options or {}
    square:AddSpecialObject(isoObject, options.index or -1)
    if options.beforeSend then
        options.beforeSend(isoObject)
    end
    isoObject:transmitCompleteItemToClients()
    if options.afterSend then
        options.afterSend(isoObject)
    end
    if options.announce ~= false then
        triggerEvent("OnObjectAdded", isoObject)
    end
    return isoObject
end

-- The priority of the library's one loader per sprite: above vanilla's own loaders (MapObjects/*).
local LOAD_PRIORITY = 6

-- Per sprite name, what its tiles run as they load: { first = { fn, ... }, rest = { fn, ... } }.
local loaders = {}

-- The tile an object shows, as MapObjects reads it.
local function tileOf(isoObject)
    local sprite = isoObject:getSprite()
    return sprite and sprite:getName() or isoObject:getSpriteName()
end

-- Runs `fns` on `isoObject`, stopping once one takes it off its square or changes its tile from
-- `name`; returns whether none did.
local function runLoaders(fns, isoObject, name)
    for _, fn in ipairs(fns) do
        fn(isoObject)
        if isoObject:getObjectIndex() == -1 or tileOf(isoObject) ~= name then
            return false
        end
    end
    return true
end

local function loadersOf(name)
    local entry = loaders[name]
    if not entry then
        entry = { first = {}, rest = {} }
        loaders[name] = entry
        MapObjects.OnLoadWithSprite(name, function(isoObject)
            if runLoaders(entry.first, isoObject, name) then
                runLoaders(entry.rest, isoObject, name)
            end
        end, LOAD_PRIORITY)
    end
    return entry
end

--- Runs `fn(isoObject)` for each object of the tiles `sprites` (names) as its chunk loads on this
--- side. MapObjects.OnLoadWithSprite keeps one function per sprite and priority, so every caller's
--- goes through one function per sprite: those with `options.first` (a system loading the record
--- the others read) run before the rest, each group in the order added, and one that takes the
--- object off its square or changes its tile ends the object's run, as MapObjects does.
--- `options.matches(isoObject)`, if given, limits fn to the objects it accepts; with
--- `options.added` fn also runs for each accepted object added later (OnObjectAdded).
function Tiles.onLoad(sprites, fn, options)
    options = options or {}
    local matches = options.matches
    local run = matches and function(isoObject)
        if matches(isoObject) then
            fn(isoObject)
        end
    end or fn
    for _, name in ipairs(sprites) do
        table.insert(loadersOf(name)[options.first and "first" or "rest"], run)
    end
    if options.added then
        Events.OnObjectAdded.Add(run)
    end
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
