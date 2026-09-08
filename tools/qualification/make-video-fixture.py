#!/usr/bin/env python3
"""Generate the deterministic Video qualification fixtures.

    tools/qualification/make-video-fixture.py <output-directory>

**A frame from this fixture proves four things by itself**: its width, its
height, where it sits in playback time, and that it is not flipped or shifted.
That is the whole reason it is generated here rather than downloaded -- an
arbitrary file proves that a decoder ran, and nothing about *which frame* came
back, so it cannot tell one poster frame apart from advancing playback.

Geometry, 64x48, and every number below is what the qualification asserts:

    field           the whole frame is one saturated section colour
    corner marker   a white 16x12 block in a section-specific corner
    centre anchor   a black 8x8 block at the exact centre, in every frame

The four sections are half a second each at 10 fps, so the file is 2.000 s of
20 frames:

    section 0   t in [0.0, 0.5)   red      marker top-left
    section 1   t in [0.5, 1.0)   green    marker top-right
    section 2   t in [1.0, 1.5)   blue     marker bottom-left
    section 3   t in [1.5, 2.0)   yellow   marker bottom-right

**Two independent signals name the section**, which is deliberate: the field
colour and the marker corner have to agree, so a frame that decoded into the
wrong colour space cannot quietly pass as the wrong section. They are the four
most separated points available in RGB, so a YUV round trip moves them but never
far enough to confuse two of them -- the qualification uses a generous tolerance
for exactly that reason and still discriminates.

The centre anchor is the spatial control. It is in every frame, so it says
nothing about time; what it says is that the frame arrived the right way up and
the right way round, which a uniform field cannot.
"""
import os
import shutil
import subprocess
import sys

WIDTH, HEIGHT, FPS, SECONDS = 64, 48, 10, 2.0
FRAMES = int(FPS * SECONDS)

# (name, field colour, marker corner)
SECTIONS = [
    ("red",    (255,   0,   0), "top-left"),
    ("green",  (  0, 255,   0), "top-right"),
    ("blue",   (  0,   0, 255), "bottom-left"),
    ("yellow", (255, 255,   0), "bottom-right"),
]

MARKER_W, MARKER_H = 16, 12
ANCHOR = 8
CORNERS = {
    "top-left":     (0,                 0),
    "top-right":    (WIDTH - MARKER_W,  0),
    "bottom-left":  (0,                 HEIGHT - MARKER_H),
    "bottom-right": (WIDTH - MARKER_W,  HEIGHT - MARKER_H),
}


def frame_bytes(index):
    """RGB24 bytes for one frame, straight from the definitions above."""
    section = SECTIONS[(index * len(SECTIONS)) // FRAMES]
    _, field, corner = section
    row = bytes(field) * WIDTH
    pixels = bytearray(row * HEIGHT)

    def fill(x0, y0, w, h, colour):
        for y in range(y0, y0 + h):
            base = (y * WIDTH + x0) * 3
            pixels[base:base + w * 3] = bytes(colour) * w

    mx, my = CORNERS[corner]
    fill(mx, my, MARKER_W, MARKER_H, (255, 255, 255))
    fill((WIDTH - ANCHOR) // 2, (HEIGHT - ANCHOR) // 2, ANCHOR, ANCHOR, (0, 0, 0))
    return bytes(pixels)


def encode(raw, path, codec, container, extra):
    """One ffmpeg run from the same raw frames, so the formats differ and the
    content cannot."""
    command = [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-f", "rawvideo", "-pixel_format", "rgb24",
        "-video_size", "%dx%d" % (WIDTH, HEIGHT), "-framerate", str(FPS),
        "-i", "pipe:0", "-an", "-c:v", codec, "-r", str(FPS),
    ] + extra + ["-f", container, path]
    process = subprocess.run(command, input=raw, capture_output=True)
    if process.returncode != 0:
        sys.stderr.write(process.stderr.decode("utf-8", "replace"))
        return False
    return True


def main(argv):
    if len(argv) != 1:
        sys.stderr.write(__doc__)
        return 2
    out = argv[0]
    os.makedirs(out, exist_ok=True)
    if not shutil.which("ffmpeg"):
        sys.stderr.write("make-video-fixture.py needs ffmpeg on PATH\n")
        return 2

    raw = b"".join(frame_bytes(i) for i in range(FRAMES))

    # The three formats answer three different questions and are named for them.
    #
    #   .wmv   the XNA-plausible container. WMV8, because this ffmpeg build
    #          *decodes* WMV3/VC-1 and cannot *encode* either, so this is as
    #          close to what XNA 4 consumes as can be produced here -- and the
    #          qualification says WMV8 rather than claiming codec parity.
    #   .ogv   Theora, which is what CNA's own VideoReader probes for: its
    #          supported-extension list is FNA's `.ogv'/`.ogg'. `-g 1' is not
    #          decoration: without it libtheora returns 15 frames for the 20 it
    #          was given, and a fixture whose frame count is not the one it was
    #          built from cannot anchor a claim about *which* frame came back.
    #   .mp4   H.264, the format the 2026-09-08 capability probe already used.
    #          Kept so that this fixture is comparable with that measurement.
    targets = [
        ("fixture.wmv", "wmv2",   "asf",  ["-b:v", "2M"]),
        ("fixture.ogv", "libtheora", "ogv", ["-q:v", "10", "-g", "1"]),
        ("fixture.mp4", "libx264", "mp4",
         ["-pix_fmt", "yuv420p", "-crf", "0", "-preset", "veryslow"]),
    ]
    written = []
    for name, codec, container, extra in targets:
        path = os.path.join(out, name)
        if encode(raw, path, codec, container, extra):
            written.append((name, os.path.getsize(path)))
        else:
            sys.stderr.write("could not encode %s with %s\n" % (name, codec))

    # A file nothing can decode, for the failure branch. Not a video: bytes that
    # are the right size to be one and are not one.
    broken = os.path.join(out, "undecodable.wmv")
    with open(broken, "wb") as handle:
        handle.write(b"\x30\x26\xb2\x75" + b"\x00" * 4096)
    written.append(("undecodable.wmv", os.path.getsize(broken)))

    for name, size in written:
        print("%-20s %8d bytes" % (name, size))
    print("%d frames, %dx%d, %d fps, %.3f s" % (FRAMES, WIDTH, HEIGHT, FPS, SECONDS))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
