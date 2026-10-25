# cf_commonlib

## Commands

- The library has no suite of its own; Renewable Energy (`../RenewableEnergy`) and Enhanced Irrigation (`../EnhancedIrrigation`) are the test. Each loads this repository through its `dev/harness.conf`'s `LIBRARY_MODS`, so keep both checked out beside it.
- After every change, in each mod: `dev/static-check.sh`, which compiles and checks the library's Lua as that mod's published code. After a change under `Contents/`, also `dev/validate-server.sh` in each. Before pushing: `dev/run-debug-client.sh --test` and `dev/run-debug-client.sh --test --mp` in each. Agents working in parallel don't run the game; whoever merges their work runs the batch.
- After either mod's poster changes: `art/promo/compose.py`, which lays out `Contents/mods/cf_commonlib/42/poster.png` and `preview.png` from them with Renewable Energy's `dev/harness/lib/promo.py`. Never edit those images by hand.

## Rules

- The library names no mod: no item, sprite, tile, sandbox option, translation key, command module or class-name prefix of a mod appears in it. Whatever is a mod's comes in as a parameter. It ships no translations; a key a function shows is the caller's.
- Each module returns its table and defines no globals. A name the game looks up as a global (a timed action's class, an OnAddToMenu hook) is the calling mod's, declared there.
- A change to a function's signature or behaviour migrates Renewable Energy and Enhanced Irrigation in the same change, with every caller: shipped code, dev mod, tests. No aliases or shims for the old shape.
- Saves keep a Global Object System by its SYSTEM_NAME and class names and each record by its SAVED_FIELDS; the library takes those from the mod. Never change how it derives a name the mods pass in.
- Check Build 42 APIs against the installed game's Lua, scripts and decompiled Java (`../RenewableEnergy/DEVELOPMENT.md` has the command), not web docs or memory.
- Comments say why, without repeating values from the code.
- `workshop.txt` is written by hand: this repository has no harness to generate it from `README.md`. Keep its description a short summary of the README's "For players", and leave the `id` line to the game's uploader.
