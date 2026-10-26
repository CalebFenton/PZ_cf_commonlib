# Changelog

What each version changes for a mod that calls the library. Versions follow semantic versioning
(`AGENTS.md`, Versions); until 1.0.0, a breaking change raises the minor version.

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
