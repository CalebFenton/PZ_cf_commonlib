# cf_commonlib

## Commands

- The library has no suite of its own; Renewable Energy (`../RenewableEnergy`) and Enhanced Irrigation (`../EnhancedIrrigation`) are the test. Each loads this repository through its `dev/harness.conf`'s `LIBRARY_MODS`, so keep both checked out beside it.
- After every change, in each mod: `dev/static-check.sh`, which compiles and checks the library's Lua as that mod's published code. After a change under `Contents/`, also `dev/validate-server.sh` in each. Then one `dev/run-debug-client.sh --test --changed` per batch in each mod, not after each edit. Before pushing: `dev/run-debug-client.sh --test` in each; before a release, also `--test --mp`. Agents working in parallel don't run the game; whoever merges their work runs the batch.
- `art/mod_icon.py` draws the mod list icon, `Contents/mods/cf_commonlib/42/cf_commonlib_icon.png`. `art/promo/compose.py` lays out `Contents/mods/cf_commonlib/42/poster.png` and `preview.png` from `art/promo/scene.png` with Renewable Energy's `dev/harness/lib/promo.py`. Never edit those images by hand.

## Rules

- The library names no mod: no item, sprite, tile, sandbox option, translation key, command module or class-name prefix of a mod appears in it. Whatever is a mod's comes in as a parameter. It ships no translations; a key a function shows is the caller's.
- Each module returns its table and defines no globals. A name the game looks up as a global (a timed action's class, an OnAddToMenu hook) is the calling mod's, declared there.
- A change to a function's signature or behaviour migrates every mod that requires the library in the same change, with every caller: shipped code, dev mod, tests. No aliases or shims for the old shape; the version says it breaks (Versions).
- Saves keep a Global Object System by its SYSTEM_NAME and class names and each record by its SAVED_FIELDS; the library takes those from the mod. Never change how it derives a name the mods pass in.
- Check Build 42 APIs against the installed game's Lua, scripts and decompiled Java (`../RenewableEnergy/DEVELOPMENT.md` has the command), not web docs or memory.
- Comments say why, without repeating values from the code.
- `workshop.txt` is written by hand: this repository has no harness to generate it from `README.md`. Keep its description a short summary of the README's "For players", and leave the `id` line to the game's uploader.

## Versions

The library follows semantic versioning, MAJOR.MINOR.PATCH. Every published mod that requires it runs whatever version the player's Steam last downloaded, so the version tells the mods' maintainers what an update may break.

- Every change under `Contents/` gets the next version in the same commit: `modversion` in `Contents/mods/cf_commonlib/42/mod.info`, and an entry at the top of `CHANGELOG.md` that says what changed for a mod calling the library. Tag the commit `v<version>`.
- MAJOR: a mod written against the previous version can break. A module, function, field or parameter removed or renamed; a parameter newly required; a return value or behaviour changed that a caller relies on; a name a save keeps derived differently.
- MINOR: something added that old callers don't notice: a module, a function, an optional parameter, a new field in a returned table.
- PATCH: a fix that leaves every documented contract as it was.
- Until the first Workshop release, which is 1.0.0, a breaking change raises MINOR instead of MAJOR.
- A MAJOR or MINOR version that a mod needs goes to the Workshop before that mod's update does. After a MAJOR version, upload every mod that requires the library together with it, since each player's Steam updates them all at once.
- The mods that require the library: Renewable Energy (`../RenewableEnergy`) and Enhanced Irrigation (`../EnhancedIrrigation`). Add a mod here when its `mod.info` starts requiring `cf_commonlib`, and add the library rule from their `AGENTS.md` to its own.
