# cf_commonlib

## Commands

- The library has no suite of its own; the mods that require it are the test. They are the sibling repositories whose `mod.info` requires it: `grep -ls 'require=.*cf_commonlib' ../*/Contents/mods/*/42/mod.info`. Each loads this repository through its `dev/harness.conf`'s `LIBRARY_MODS`.
- After every change, in each of those mods: `dev/static-check.sh`, which compiles and checks the library's Lua as that mod's published code, and after a change under `Contents/`, `dev/validate-server.sh`. Then one `dev/run-debug-client.sh --test --changed` per batch in each, not after each edit. Before pushing: `dev/run-debug-client.sh --test` in each; before a release, also `--test --mp`.
- After committing a change to `Contents/`: `dev/package.sh` in any one of those mods, which rebuilds `~/Nextcloud/ProjectZomboid/mods.zip`, every mod with its libraries and dev mods, which the user tests with. Never zip mods by hand.

## Rules

- The library names no mod: no item, sprite, tile, sandbox option, translation key, command module or class-name prefix of a mod appears in it. Whatever is a mod's comes in as a parameter, and a translation key a function shows is the caller's.
- Each module returns its table and defines no globals. A name the game looks up as a global (a timed action's class, an OnAddToMenu hook) is the calling mod's, declared there.
- A change to a function's signature or behaviour migrates every mod that requires the library in the same change, with every caller: shipped code, dev mod, tests. No aliases or shims for the old shape; the version says it breaks.
- Saves keep a Global Object System by its system and class names and each record by its saved fields, which the library takes from the mod. Never change how it derives a name the mods pass in: their players' saves would lose those objects.
- Check Build 42 APIs against the installed game's Lua, scripts and decompiled Java (`../RenewableEnergy/DEVELOPMENT.md` has the command), not web docs or memory.
- Comments say why, without repeating values from the code.
- `workshop.txt` is written by hand, since no harness here generates it: keep its description a short summary of the README's "For players", and leave its `id` line to the game's uploader.

## Versions

A player's Steam runs whatever version of the library it last downloaded under every mod that requires it, so the version, MAJOR.MINOR.PATCH, tells those mods what an update may break.

- Every change under `Contents/` gets the next version in the same commit: `modversion` in `Contents/mods/cf_commonlib/42/mod.info`, and an entry at the top of `CHANGELOG.md` saying what changed for a mod calling the library. Tag the commit `v<version>`.
- MAJOR: a mod written against the previous version can break: a module, function, field or parameter removed or renamed, a parameter newly required, a return value or behaviour a caller relies on changed, or a name a save keeps derived differently. Before the first Workshop release, 1.0.0, such a change raises MINOR instead.
- MINOR: something added that old callers don't notice: a module, a function, an optional parameter, a field in a returned table.
- PATCH: a fix that leaves every documented contract as it was.
- Upload a version a mod needs to the Workshop before that mod's update. After a MAJOR version, upload every mod that requires the library with it, since each player's Steam updates them all at once.

## STOP

- Hand edits to `Contents/mods/cf_commonlib/42/cf_commonlib_icon.png`, `poster.png` or `preview.png`: `art/mod_icon.py` and `art/promo/compose.py` write them.
