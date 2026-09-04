#!/usr/bin/env python3
"""Generate the pixel-proof texture fixtures, byte for byte.

A rasterization proof is only as good as the texture it draws. These are
generated rather than drawn, so every texel is stated here in source and a
reviewer can check the claim without opening an image editor.

  solid-magenta-8.png   8x8, every texel (255, 0, 255, 255)
  quadrant-4.png        4x4, four 2x2 opaque quadrants:
                          top-left  red    (255,   0,   0, 255)
                          top-right green  (  0, 255,   0, 255)
                          bot-left  blue   (  0,   0, 255, 255)
                          bot-right yellow (255, 255,   0, 255)
  glyph-atlas-16x8.png  16x8, two 8x8 opaque glyph cells:
                          left  'A'  red    (255,   0,   0, 255)
                          right 'B'  green  (  0, 255,   0, 255)

All are opaque, so no blending mode can change what a texel contributes, and all
use colours no clear colour in these tests uses.

The glyph atlas is deliberately **two different colours** rather than two copies
of one shape. A text proof whose glyphs looked alike could pass while drawing the
first glyph twice, or while drawing the second one in the first one's place; with
this atlas the colour of a pixel says *which glyph* reached it, so the advance
between glyphs and the per-glyph source rectangle are both under test rather
than merely the fact that some font texel arrived.

There is no antialiasing anywhere in it: every texel is fully opaque and fully
saturated, so the expected back-buffer value is the texel itself and no
tolerance, blend or filter has to be reasoned about.

  python3 tools/qualification/make-pixel-fixtures.py tests/fixtures
"""
import os
import struct
import sys
import zlib


def png(path, width, height, texel):
    """Write a minimal 8-bit RGBA PNG whose pixel (x, y) is texel(x, y)."""
    raw = b"".join(
        b"\x00" + b"".join(bytes(texel(x, y)) for x in range(width))
        for y in range(height))

    def chunk(kind, payload):
        return (struct.pack(">I", len(payload)) + kind + payload
                + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF))

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n")
        fh.write(chunk(b"IHDR", header))
        fh.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        fh.write(chunk(b"IEND", b""))
    return path


def main(argv):
    directory = argv[0] if argv else "tests/fixtures"
    os.makedirs(directory, exist_ok=True)
    png(os.path.join(directory, "solid-magenta-8.png"), 8, 8,
        lambda x, y: (255, 0, 255, 255))
    png(os.path.join(directory, "quadrant-4.png"), 4, 4,
        lambda x, y: ((255, 0, 0, 255) if (x < 2 and y < 2) else
                      (0, 255, 0, 255) if (x >= 2 and y < 2) else
                      (0, 0, 255, 255) if (x < 2 and y >= 2) else
                      (255, 255, 0, 255)))
    # 'A' occupies texels x 0..7 and 'B' texels x 8..15, both 8 rows tall.
    png(os.path.join(directory, "glyph-atlas-16x8.png"), 16, 8,
        lambda x, y: (255, 0, 0, 255) if x < 8 else (0, 255, 0, 255))
    for name in ("solid-magenta-8.png", "quadrant-4.png", "glyph-atlas-16x8.png"):
        path = os.path.join(directory, name)
        print("%-22s %d bytes" % (name, os.path.getsize(path)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
