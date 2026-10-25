# Changelog

What each version changes for a mod that calls the library. Versions follow semantic versioning
(`AGENTS.md`, Versions); until 1.0.0, a breaking change raises the minor version.

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
