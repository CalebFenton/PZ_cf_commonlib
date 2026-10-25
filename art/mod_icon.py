#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow==12.3.0"]
# ///
"""Draws the mod list icon, Contents/mods/cf_commonlib/42/cf_commonlib_icon.png: the game's
bookcase seen straight on, cast in shining gold, its three shelves full of books in the game's
cover colours, with a glint on its top corner.

    art/mod_icon.py

It is drawn pixel by pixel at the harness's MOD_ICON size, like the mods' icons (one object, a dark
one-pixel outline, no background), and saved doubled with hard edges by lib/promo.py's
save_mod_icon. The library has no harness of its own, so this reads Renewable Energy's, checked out
beside this repository as LIBRARY_MODS expects. It is drawn from the shapes below rather than kept
as an edited image, so a rerun writes the same file. It needs uv (https://docs.astral.sh/uv/).
"""
import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO.parent / "RenewableEnergy" / "dev" / "harness" / "lib"))
import promo  # noqa: E402

ICON = REPO / "Contents/mods/cf_commonlib/42/cf_commonlib_icon.png"
SIZE = promo.MOD_ICON

# Darker than the item icons' outline, as the mods' icons: the mod list is dark.
OUTLINE = (22, 24, 28)
# Gold from its glint down to its shade; metal reads as metal by the jump between them.
GOLD_WHITE = (255, 250, 214)
GOLD_LIGHT = (255, 226, 112)
GOLD = (236, 184, 44)
GOLD_MID = (198, 140, 24)
GOLD_DARK = (138, 90, 12)
# The case's back, in the shadow of its shelves.
BACK = (84, 54, 10)
BACK_SHADE = (58, 36, 6)

# The game's book covers: its red, blue, green, brown, cream and black books.
RED, BLUE, GREEN = (168, 46, 38), (46, 76, 150), (54, 116, 62)
BROWN, CREAM, BLACK = (118, 72, 38), (222, 206, 164), (48, 46, 52)
TEAL, PLUM = (38, 116, 120), (108, 58, 112)

# The case's outline box, inclusive; its posts, crown and plinth are gold inside it.
CASE = (3, 1, 28, 30)
CROWN_ROWS, PLINTH_ROWS, POST = 4, 2, 2
# Each shelf's books from the left: (width, height, cover), a None cover for a gap. Each row fills
# the case's inside width; heights are at most a shelf's.
SHELVES = [
    [(2, 5, RED), (2, 6, BLUE), (2, 4, CREAM), (1, 6, BLACK), (2, 5, GREEN), (2, 6, BROWN), (1, 0, None),
     (2, 5, TEAL), (2, 6, RED), (2, 4, PLUM), (2, 5, BLUE)],
    [(2, 6, GREEN), (2, 5, BROWN), (2, 6, PLUM), (2, 4, RED), (2, 0, None), (2, 6, CREAM), (2, 5, BLUE),
     (1, 6, BLACK), (2, 5, TEAL), (2, 6, RED), (1, 4, GREEN)],
    [(2, 6, BLUE), (2, 4, RED), (2, 5, CREAM), (2, 6, BROWN), (2, 6, GREEN), (1, 5, BLACK), (2, 4, PLUM),
     (2, 6, TEAL), (2, 5, RED), (1, 0, None), (2, 6, BLUE)],
]
SHELF_ROWS, BOARD_ROWS = 6, 2
# The glint's centre and arm length, over the case's top right corner.
GLINT, GLINT_ARM = (26, 3), 3


def lighter(colour, by):
    return tuple(min(255, round(c + (255 - c) * by)) for c in colour)


def darker(colour, by):
    return tuple(round(c * (1 - by)) for c in colour)


def put(pixels, x, y, colour):
    pixels[x, y] = colour + (255,)


def case(pixels):
    """The outline, then the gold: lit from the top left, so the left post, the crown's top and each
    board's top catch the light and the right post and the undersides fall into shade."""
    left, top, right, bottom = CASE
    for y in range(top, bottom + 1):
        for x in range(left, right + 1):
            edge = x in (left, right) or y in (top, bottom)
            put(pixels, x, y, OUTLINE if edge else BACK)
    inner_left, inner_right = left + 1, right - 1
    for y in range(top + 1, bottom):
        put(pixels, inner_left, y, GOLD_LIGHT)
        put(pixels, inner_left + 1, y, GOLD)
        put(pixels, inner_right - 1, y, GOLD_MID)
        put(pixels, inner_right, y, GOLD_DARK)
    crown = [GOLD_LIGHT, GOLD, GOLD_MID, GOLD_DARK]
    for row, colour in enumerate(crown[:CROWN_ROWS]):
        for x in range(inner_left + 1, inner_right):
            put(pixels, x, top + 1 + row, colour)
    for row, colour in enumerate([GOLD_LIGHT, GOLD_MID][:PLINTH_ROWS]):
        for x in range(inner_left + 1, inner_right):
            put(pixels, x, bottom - PLINTH_ROWS + row, colour)


def shelves(pixels):
    """Each shelf's books standing on its board, the back darker just under the board above."""
    left, top, right, _ = CASE
    first_x = left + 1 + POST
    width = right - 1 - POST - first_x + 1
    y = top + 1 + CROWN_ROWS
    for i, books in enumerate(SHELVES):
        assert sum(w for w, _, _ in books) == width, f"shelf {i} is {sum(w for w, _, _ in books)} wide, not {width}"
        for x in range(first_x, first_x + width):
            put(pixels, x, y, BACK_SHADE)
        x = first_x
        floor = y + SHELF_ROWS - 1
        for w, h, cover in books:
            assert h <= SHELF_ROWS, f"a book on shelf {i} is taller than the shelf"
            for dy in range(h):
                for dx in range(w):
                    colour = cover
                    # The spine's left edge lit, its top a shade lighter, as the case is lit.
                    if dx == 0 and w > 1:
                        colour = lighter(cover, 0.3)
                    elif w > 1:
                        colour = darker(cover, 0.1)
                    if dy == 0:
                        colour = lighter(colour, 0.15)
                    put(pixels, x + dx, floor - dy, colour)
            x += w
        y += SHELF_ROWS
        if i < len(SHELVES) - 1:
            for x in range(first_x, first_x + width):
                put(pixels, x, y, GOLD_LIGHT)
                put(pixels, x, y + 1, GOLD_DARK)
            y += BOARD_ROWS


def shine(pixels):
    """A streak across the gold where the light runs down from the top left, and a four-armed
    glint on the top right corner, its arms fading to the gold's lightest."""
    left, top, right, bottom = CASE
    for x in range(left + 1, right):
        for y in range(top + 1, bottom):
            r, g, b, _ = pixels[x, y]
            gold = (r, g, b) in (GOLD_LIGHT, GOLD, GOLD_MID, GOLD_DARK)
            if gold and x + y in (12, 13):
                put(pixels, x, y, GOLD_WHITE)
    gx, gy = GLINT
    put(pixels, gx, gy, (255, 255, 255))
    for step in range(1, GLINT_ARM + 1):
        colour = GOLD_WHITE if step < GLINT_ARM else GOLD_LIGHT
        for dx, dy in [(step, 0), (-step, 0), (0, step), (0, -step)]:
            x, y = gx + dx, gy + dy
            if 0 <= x < SIZE and 0 <= y < SIZE:
                put(pixels, x, y, colour)
    for dx, dy in [(1, 1), (-1, 1), (1, -1), (-1, -1)]:
        put(pixels, gx + dx, gy + dy, GOLD_LIGHT)


image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
pixels = image.load()
case(pixels)
shelves(pixels)
shine(pixels)
promo.save_mod_icon(image, ICON)
