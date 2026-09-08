#!/usr/bin/env python3
"""Write a compiled-asset `.xnb` whose root object is an XNA `Video`.

    tools/qualification/make-video-xnb.py <output.xnb> <media-reference> \
        <duration-ms> <width> <height> <fps> <soundtrack>

**This is a measurement instrument and not an authority.** It exists to answer
one question -- whether CNA's C ABI can be made to produce a `Video` from a
compiled asset the way `ContentManager.Load<Video>` does -- and the honest
statement of what it produces is on the `--strict` flag below.

The field order is the pinned XNA `VideoReader.Read` and nothing else:

    ReadObject<string>()   the media reference, relative to the .xnb
    ReadObject<int32>()    duration in milliseconds
    ReadObject<int32>()    width
    ReadObject<int32>()    height
    ReadObject<float32>()  frames per second
    ReadObject<int32>()    VideoSoundtrackType

**Two forms, and the difference is the whole point.** `ReadObject<T>()`
dispatches through the asset's type-reader table, so every field is preceded by
a 7-bit-encoded reference into that table. A writer that emits the fields inline
instead produces a file the real content pipeline never writes.

    --strict   (default) every field dispatched through the table, which is the
               form a real content pipeline emits
    --inline   the fields laid out with no per-field reference

CNA reads both, and picks between them by counting the type-reader table: more
than one entry takes the dispatching path, exactly one takes the inline one. So
the inline form exercises **a compensation path that exists for hand-built test
fixtures**, and evidence gathered against it is evidence about CNA's parser
rather than about what an XNA program does. That is the same distinction this
project already drew for XACT's fixtures, and it is drawn here before rather
than after any claim rests on it.
"""
import struct
import sys


def seven_bit(value):
    out = bytearray()
    while value >= 0x80:
        out.append((value & 0x7F) | 0x80)
        value >>= 7
    out.append(value)
    return bytes(out)


def string(text):
    raw = text.encode("utf-8")
    return seven_bit(len(raw)) + raw


def build(reference, duration_ms, width, height, fps, soundtrack, strict):
    body = bytearray()
    if strict:
        readers = ["Microsoft.Xna.Framework.Content.VideoReader",
                   "Microsoft.Xna.Framework.Content.StringReader",
                   "Microsoft.Xna.Framework.Content.Int32Reader",
                   "Microsoft.Xna.Framework.Content.SingleReader"]
        body += seven_bit(len(readers))
        for name in readers:
            body += string(name) + struct.pack("<i", 0)
        body += seven_bit(0)          # no shared resources
        body += seven_bit(1)          # root -> VideoReader
        body += seven_bit(2) + string(reference)
        body += seven_bit(3) + struct.pack("<i", duration_ms)
        body += seven_bit(3) + struct.pack("<i", width)
        body += seven_bit(3) + struct.pack("<i", height)
        body += seven_bit(4) + struct.pack("<f", fps)
        body += seven_bit(3) + struct.pack("<i", soundtrack)
    else:
        body += seven_bit(1)
        body += string("Microsoft.Xna.Framework.Content.VideoReader") + struct.pack("<i", 0)
        body += seven_bit(0)
        body += seven_bit(1)
        body += string(reference)
        body += struct.pack("<iii", duration_ms, width, height)
        body += struct.pack("<f", fps)
        body += struct.pack("<i", soundtrack)

    header = b"XNBw" + bytes([5, 0])            # Windows, format 5, uncompressed
    return header + struct.pack("<i", 10 + len(body)) + bytes(body)


def main(argv):
    strict = True
    if "--inline" in argv:
        strict = False
        argv.remove("--inline")
    if "--strict" in argv:
        argv.remove("--strict")
    if len(argv) != 7:
        sys.stderr.write(__doc__)
        return 2
    path, reference, duration, width, height, fps, soundtrack = argv
    data = build(reference, int(duration), int(width), int(height), float(fps),
                 int(soundtrack), strict)
    with open(path, "wb") as handle:
        handle.write(data)
    print("%s  %d bytes  %s form" % (path, len(data), "dispatching" if strict else "inline"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
