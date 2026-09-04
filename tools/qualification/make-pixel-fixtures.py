#!/usr/bin/env python3
"""Generate the two pixel-proof texture fixtures, byte for byte.

A rasterization proof is only as good as the texture it draws. These two are
generated rather than drawn, so every texel is stated here in source and a
reviewer can check the claim without opening an image editor.

  solid-magenta-8.png   8x8, every texel (255, 0, 255, 255)
  quadrant-4.png        4x4, four 2x2 opaque quadrants:
                          top-left  red    (255,   0,   0, 255)
                          top-right green  (  0, 255,   0, 255)
                          bot-left  blue   (  0,   0, 255, 255)
                          bot-right yellow (255, 255,   0, 255)

Both are opaque, so no blending mode can change what a texel contributes, and
both use colours no clear colour in these tests uses.

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
    for name in ("solid-magenta-8.png", "quadrant-4.png"):
        path = os.path.join(directory, name)
        print("%-22s %d bytes" % (name, os.path.getsize(path)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
