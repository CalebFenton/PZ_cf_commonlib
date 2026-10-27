# Changelog

What each version changes for a mod that calls the library. Versions follow semantic versioning
(`AGENTS.md`, Versions); until 1.0.0, a breaking change raises the minor version.

## Unreleased

- `GlobalObjects.declare(owner, { prefix, name, isObject, sprites, decorate?, accept? })` replaces
  `addAccessors`: a feature's identity is declared once, as `owner.feature`, and read by
  `ObjectSystem.define(owner, { Object, loadOnCreate? })`,
  `ObjectSystem.deriveSystem(owner, Object)` and `ClientObjects.define(owner)` (no more prefix,
  name, isObject, sprites, loadPriority or longestPass arguments; `decorate` is optional;
  `adoptCopy`, `adoptContainer` and `ClientObjects.adopt` are gone: a mod sets up its own client
  copies with `Tiles.onLoad`). New accessors `owner.objectAt`, `owner.each(fn)` and
  `owner.summaryAt(x, y, z)`; `summaryOf` and `summaryAt` read the record on the authority (single
  player included), else the client copy.
- `ObjectSystem.deriveSystem` adds `lastHour` to the record class's `SAVED_FIELDS` and stamps it on
  new records (saved key unchanged); `ObjectSystem.Object:catchUp` counts at most
  `Clock.hoursSince`'s default longest pass.
- `Containers` (new, shared): `Containers.filter{ sprites, isObject, accept }` sets container
  filters on every side; `Containers.adopt(isoObject)` for an object built in code.
  `GlobalObjects.declare`'s `accept` declares one.
- `Tiles.onLoad(sprites, fn, { matches?, added?, first? })`: one MapObjects loader per sprite for
  every mod, so mods choose no load priority; `first` runs a system's record loader before the
  rest. `Tiles.newEntity(square, sprite)`: a new thumpable with its tile's entity.
- `Chance` (new, shared): roll, hit, within, between, pick, pickWeighted, pickSome, overHours, all
  drawing on `Chance.roll`.
- `Clock.now()`, `Clock.unitsPerSecond()`; `Clock.hoursSince`'s `longest` is optional, a week by
  default.
- `GeneratorReach.excludeGenerators(isOwn)`, `isVanillaGenerator(object)`, `addDraw(draw)` and
  `drawOf(object)`: mods tell their own generators and placed loads apart without each other's
  globals.
- `Loot.register(modName, items, multiplierOf)` takes the items (`{ fullType, entries }`) and
  returns the function that puts them in; `Loot.place` is no longer public. `Loot.entries(groups)`
  builds entries from `{ weight, { reference, ... } }` groups.
- `Squares.positionOf`, `samePosition`, `isPosition`, `eachAround`.
- `Items.firstInput(craftRecipeData, matches)`; `Items.takeItems` removed.
- `Jobs`: a row's `with = isKind(item)` (with `withMissing`, `withOptional`) refuses a `with` the
  character doesn't carry, after the needs; `Jobs.carries` is private. `Module.verdict(character,
  job, subject, with)` gives `{ blocker, hidden }` or `{ needs, withRefusal }` in the one refusal
  order (blocker, needs, then `with`), which `refusalAt` now follows too; `Module.blocker` and
  `Module.withRefusal` are gone. A row's `label` names it in a menu. `Jobs.targetSite`'s `DO[job]`
  is `(character, row, target, with, materials)`, without the always-nil place.
- `JobAction.forFeatures`: a feature's site is no longer given in `FEATURES`; every file gives its
  own with `Action.serve({ feature = site })`, and `completeJob` refuses a feature no site serves.
  Each job module gets `action` and `feature`.
- `JobOptions.add(menu, playerNum, Jobs, job, target, with, label?)` and
  `addEach(menu, playerNum, Jobs, job, target, items, label?, nameOf?)` take the job module in
  place of the action class and feature; the label defaults to the row's `label`, else the
  action's `labelKey(job)`. `JobOptions.showVerdict` greys an option by a verdict (a batch's too).
  `onWorldMenu(find, fill)` takes any `find(worldobjects)`; `JobOptions.clicked(matches)`
  is the finder of the first clicked object a test accepts. `findClicked`, `addSubMenu` and
  `subMenuOf` moved here from `Needs`; `firstOfEach` moved to `Items`.
- `Needs` is tooltip rendering only; a tool need is named by its material's `item`.
- `Squares.queueBeside(character, square, queueThere)` replaces `Squares.walkTo` and returns
  nothing.
- `OpenAction.show(windows, playerNum, window)` and `OpenAction.close(windows, playerNum, window)`:
  one window of a family per player, with the controller's focus while open.
- `Materials.unmetKind` removed.
- `Materials`: a `{ craft = name, twins, except }` material is a craftRecipe done in place: its
  needs are the recipe known, its skills and its inputs (twin recipes differing in one input are
  one `anyOf` need); `consume` pays the inputs as the craft does (scaled drainables across items,
  MayDegrade wear on kept tools) and teaches the recipe's XP. A job row's `needs` function is gone:
  rows give `materials` only, and `Jobs.perform` pays a craft on success.
- `Items.conditionMaxOf(fullType)`: an item type's script ConditionMax, cached.
- `Tiles.addToWorld(square, isoObject, { index?, beforeSend?, afterSend?, announce? })`: adds an
  object made in code to the square and publishes it (send to clients, then OnObjectAdded).
- `VehicleParts` (new, shared): `VehicleParts.isOpen(vehicle, partId)`, whether a door part leaves
  what it covers open.
- `GeneratorReach.release(x, y, z)`: lets this side's chunks go of the squares a running generator
  there powered, for a client whose copy left before the server's switch-off reached it.
- `JobAction.forFeatures` gives `Action.targetOn(feature, square)`: the topmost object on the
  square the feature works at, or nil.

## 0.3.1

- `Materials`: water in carried bags, including nested bags, counts toward a job and is consumed
  fullest first alongside main-inventory water. Tainted water remains excluded.
- `Materials.needs` counts water and drainable uses without sorting; consumption and equipment
  retain fullest-first selection. Java-list copying reuses `Tables.fromList`.
- `JobOptions.add` skips material counting when a blocker or darkness already refuses the job.

## 0.3.0

Breaking:

- `JobAction.forFeatures`: `canPerform` and `complete` also check `keeps` (the target is still
  the feature's kind, an item `with` still carried), so a job whose target or item went away
  stops instead of completing.
- `JobAction.forFeatures`: `Action.queue`'s fourth argument is the target, which may be a
  vehicle (see `area`).

Added:

- `JobAction.forFeatures`: `Action.completeJob(character, feature, job, target, with)` does a
  job as the action's `complete` does; a feature's `reach`; row `units` (action units, in place
  of `minutes`), `wield` (`with` is the tool kept in the primary hand), `inTarget` (`with` lies in
  the target's container) and `area(vehicle, with)` (the job is at a vehicle's area).
- `JobAction:reach()`, which `atJob` uses.
- `Jobs.define`: `short` is optional; without it an unmet need refuses with its kind. A row may
  give `needs(character, subject, with)` in place of `materials`.
- `JobOptions.add`: the label defaults to the action's label key. `JobOptions.onWorldMenu`
  returns the handler it registers.
- `Items.ofType`, `Items.toolFor(character, isTool)`, `Tables.fromList(list, keep, into)`.
- `Squares.onSquare` counts a vehicle as present until it leaves the world.

## 0.2.1

- `Needs.show` and `Needs.refuse` after `Needs.describe` reuse the option's tooltip instead of
  taking a second one from the game's tooltip pool.

## 0.2.0

- `Jobs`: a row's optional `tooltip`, the translation key of what the job does. `JobOptions.add`
  heads the option's tooltip with it, above the needs or the refusal, as a crafting recipe's
  Tooltip reads.
- `Needs.describe(option, key)`: the same for any option; `Needs.show` and `Needs.refuse` add
  under it.

## 0.1.1

- `Needs.show`: a need any of several meets keeps a space on both sides of the "or" between
  them; the tooltip ran the words together, as the game's rich text drops the space before a
  colour tag.

## 0.1.0

The first version: the code Renewable Energy and Enhanced Irrigation had each carried, merged.

- `Squares`, `Clock`, `Tables`, `Items`, `Tiles`, `GeneratorReach`: object lookup, reach, the
  walk to a square, hours since a pass, taking and giving items, tiles and overlays, a vanilla
  generator's reach.
- `Materials`, `Jobs`, `JobAction`, `JobOptions`, `Needs`, `OpenAction`: jobs with one refusal
  for the menu, the action and the authority, and right-click options greyed out with what is
  missing.
- `GlobalObjects`, `ClientObjects`, `ObjectSystem`: Global Object System features on every side,
  under the mod's own system and class names.
- `Loot`: a mod's items in the loot lists, scaled by its options.
- `RecipeLearning`: recipes learned by AutoLearn skill level, build recipes included, on both
  sides of a server.
