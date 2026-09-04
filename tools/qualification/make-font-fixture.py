#!/usr/bin/env python3
"""Build a SpriteFont asset -- a PNG glyph atlas and its `.cnj` descriptor.

The template needs a font it can actually read on screen, and a font is the one
asset a program cannot construct from arguments. This renders a monospaced
typeface into a grid atlas and writes the descriptor CNA's
`cna_content_manager_load_sprite_font` parses, so the asset in the template is
reproducible rather than a binary that arrived from nowhere.

**Monospaced on purpose.** Every glyph gets a cell of the same size, its crop is
the whole cell and its kerning is (0, cell width, 0), so the advance is the cell
width for every character. That keeps the descriptor readable and makes a layout
bug obvious: in a proportional font a wrong advance looks like bad spacing, and
in this one it looks like a collision.

    python3 tools/qualification/make-font-fixture.py OUT-DIR [NAME]

Writes OUT-DIR/NAME.cnj and OUT-DIR/NAME-atlas.png. Requires Pillow, which is a
build-time dependency of this script alone -- nothing in CNA-Lisp needs it.
"""
import json
import os
import sys

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
SIZE = 16
FIRST, LAST = 32, 126          # printable ASCII
COLUMNS = 16


def main(argv):
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        sys.exit("this script needs Pillow: pip install pillow")
    out_dir = argv[1] if len(argv) > 1 else "."
    name = argv[2] if len(argv) > 2 else "font"
    if not os.path.exists(FONT):
        sys.exit("no font at %s; point FONT at a monospaced .ttf" % FONT)

    font = ImageFont.truetype(FONT, SIZE)
    # One cell big enough for every glyph in the range, measured rather than
    # guessed: a cell too small clips a descender and the clipping is invisible
    # until some particular string is drawn.
    probe = Image.new("L", (1, 1))
    draw = ImageDraw.Draw(probe)
    boxes = [draw.textbbox((0, 0), chr(c), font=font) for c in range(FIRST, LAST + 1)]
    left = min(b[0] for b in boxes)
    top = min(b[1] for b in boxes)
    cell_w = max(b[2] for b in boxes) - left
    cell_h = max(b[3] for b in boxes) - top
    advance = int(round(font.getlength("M")))

    count = LAST - FIRST + 1
    rows = (count + COLUMNS - 1) // COLUMNS
    atlas = Image.new("RGBA", (COLUMNS * cell_w, rows * cell_h), (0, 0, 0, 0))
    pen = ImageDraw.Draw(atlas)

    glyphs = []
    for index, code in enumerate(range(FIRST, LAST + 1)):
        col, row = index % COLUMNS, index // COLUMNS
        x, y = col * cell_w, row * cell_h
        # White glyphs on transparent: SpriteBatch tints with the draw colour, so
        # a white atlas is every colour and a coloured one is exactly one.
        pen.text((x - left, y - top), chr(code), font=font, fill=(255, 255, 255, 255))
        glyphs.append({
            "char": code,
            "source": [x, y, cell_w, cell_h],
            "crop": [0, 0, cell_w, cell_h],
            "kerning": [0, advance, 0],
        })

    png = os.path.join(out_dir, "%s-atlas.png" % name)
    atlas.save(png)
    descriptor = {
        "cnjVersion": 1,
        "type": "SpriteFont",
        "texture": "%s-atlas.png" % name,
        "lineSpacing": cell_h + 2,
        "spacing": 0.0,
        "defaultCharacter": "?",
        "glyphs": glyphs,
    }
    cnj = os.path.join(out_dir, "%s.cnj" % name)
    with open(cnj, "w", encoding="utf-8") as fh:
        json.dump(descriptor, fh, indent=1)
        fh.write("\n")
    print("wrote %s (%dx%d, %d glyphs of %dx%d, advance %d) and %s"
          % (png, atlas.width, atlas.height, count, cell_w, cell_h, advance, cnj))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
