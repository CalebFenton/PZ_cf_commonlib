# cf_commonlib

Shared code for Caleb Fenton's Project Zomboid Build 42 mods,
[Renewable Energy](https://github.com/CalebFenton/PZ_RenewableEnergy) and
[Enhanced Irrigation](https://github.com/CalebFenton/PZ_EnhancedIrrigation).

## For players

This is a dependency: the mods that need it list it as a required item, and Steam subscribes you
to it with them. It adds nothing to the game by itself: no items, recipes, tiles, options or
translations. Enable it in the mod list above the mods that use it; the game loads it first
either way. A dedicated server lists it in its `Mods` and `WorkshopItems` like any other mod.

## For modders

The Lua lives under `Contents/mods/cf_commonlib/42/media/lua/{shared,client,server}/cf_commonlib/`.
Each module returns its table and defines no globals, so a mod takes one with
`local Jobs = require "cf_commonlib/Jobs"`. Nothing in it names a mod's items, sprites, settings,
translation keys or commands; a mod passes those in. Every function's doc comment is its contract.

| Module | Side | What it does |
|---|---|---|
| `Squares` | shared | the first matching object on a square, whether an object is still in the world, whether a character stands within reach of a target (vehicles too), the walk over to a square |
| `Clock` | shared | game hours since a record's last pass, capped; timed-action units per in-game minute |
| `Tables` | shared | deep comparison of plain values |
| `Items` | shared | taking, giving, adding, removing and dropping items so clients see it; working tools; the input a build consumed |
| `Tiles` | shared | an object's tile (sent only when it changes), its entity's tile, its overlays |
| `GeneratorReach` | shared | a vanilla generator's reach as the save's options set it |
| `Materials` | shared | a job's materials list read as tooltip needs and as what it uses up |
| `Jobs` | shared | job modules: one refusal for the menu, the action and the authority, and how the authority does a job |
| `JobAction` | shared | the base timed action of a job at an object or vehicle, and one action class for many job modules |
| `GlobalObjects` | shared | reading a Global Object System feature's summary and record from any side |
| `RecipeLearning` | shared | recipes learned by AutoLearn skill level, build recipes included, on both sides of a server |
| `ClientObjects` | client | a Global Object System feature's client system and its tiles' local setup |
| `Needs` | client | right-click options greyed out with what is missing |
| `JobOptions` | client | the right-click option of a job, and the world menu hook |
| `OpenAction` | client | walk over to an object, then open its window |
| `ObjectSystem` | server | a Global Object System feature's server system, record base and job site |
| `Loot` | server | a mod's items in the loot lists, scaled by its options, replaced rather than piled up |

A save keeps a Global Object System by its name and each record by its saved fields, so the
library takes a mod's class-name prefix and system name rather than choosing its own.

This repository has no tests of its own; the mods that use it are the test (`AGENTS.md`).

Versions follow semantic versioning, MAJOR.MINOR.PATCH, and `CHANGELOG.md` says what each one
changes for a mod that calls the library.
