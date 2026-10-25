#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow==12.3.0"]
# ///
"""Lays out the library's poster, Contents/mods/cf_commonlib/42/poster.png, and the Workshop
preview, preview.png, from art/promo/scene.jpg with the dev harness's lib/promo.py. The library has
no harness of its own, so this reads Renewable Energy's, checked out beside this repository as
LIBRARY_MODS expects. Rerun it after the scene changes:

    art/promo/compose.py

The scene is a generated picture, not a game screenshot: the golden bookcase of the mod list icon
(art/mod_icon.py) in a survivor's workshop. It was made with ChatGPT's image generation from a
prompt describing that, 1536 x 1024, and saved as a JPEG to keep the repository small.
"""
import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO.parent / "RenewableEnergy" / "dev" / "harness" / "lib"))
import promo  # noqa: E402

SCENE = REPO / "art" / "promo" / "scene.jpg"
TITLE = "cf_commonlib"
LINE = "Shared code for Caleb Fenton's mods"
# The bookcase's gold.
ACCENT = (236, 184, 44)
POSTER_FILES = [REPO / "Contents" / "mods" / "cf_commonlib" / "42" / "poster.png", REPO / "preview.png"]

promo.save_poster(promo.poster(Image.open(SCENE).convert("RGBA"), TITLE, LINE, ACCENT), POSTER_FILES)
