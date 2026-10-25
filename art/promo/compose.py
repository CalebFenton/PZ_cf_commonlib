#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow==12.3.0"]
# ///
"""Lays out the library's poster, Contents/mods/cf_commonlib/42/poster.png, and the Workshop
preview, preview.png, from the posters of the mods that use it, with the dev harness's
lib/promo.py. The library has no harness of its own, so this reads Renewable Energy's, checked out
beside this repository as LIBRARY_MODS expects. Rerun it after either mod's poster changes:

    art/promo/compose.py
"""
import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[2]
WORKSHOP = REPO.parent
sys.path.insert(0, str(WORKSHOP / "RenewableEnergy" / "dev" / "harness" / "lib"))
import promo  # noqa: E402

# The library is the code under these mods, so its poster shows their scenes side by side.
MOD_POSTERS = [
    WORKSHOP / "RenewableEnergy" / "Contents" / "mods" / "RenewableEnergy" / "42" / "poster.png",
    WORKSHOP / "EnhancedIrrigation" / "Contents" / "mods" / "EnhancedIrrigation" / "42" / "poster.png",
]
TITLE = "cf_commonlib"
LINE = "Shared code for Caleb Fenton's mods"
ACCENT = (150, 160, 176)
POSTER_FILES = [REPO / "Contents" / "mods" / "cf_commonlib" / "42" / "poster.png", REPO / "preview.png"]


def scenes():
    """Each mod's poster scene, above its own name band, cut to a column and set side by side."""
    scene_height = promo.POSTER_SIZE - promo.POSTER_BAND
    column = promo.POSTER_SIZE // len(MOD_POSTERS)
    shot = Image.new("RGBA", (promo.POSTER_SIZE, scene_height), promo.BACKGROUND + (255,))
    for i, path in enumerate(MOD_POSTERS):
        scene = Image.open(path).convert("RGBA").crop((0, 0, promo.POSTER_SIZE, scene_height))
        left = (promo.POSTER_SIZE - column) // 2
        shot.alpha_composite(scene.crop((left, 0, left + column, scene_height)), (i * column, 0))
    return shot


promo.save_poster(promo.poster(scenes(), TITLE, LINE, ACCENT), POSTER_FILES)
