#!/usr/bin/env python3
"""Generate the audio content fixtures, byte for byte.

`ContentManager.Load<SoundEffect>` reads a file from disk, so its test needs a
real audio file -- and the one thing this repository will not do is store a
recording. These are generated instead, so every byte is stated here in source
and a reviewer can check the claim without opening an audio editor.

  test-tone.wav    a canonical RIFF/WAVE file: 16-bit PCM, mono, 8000 Hz,
                   8000 sample frames -- exactly one second.

**The samples are a computed sawtooth, not a recording.** Sample n is
`(n * 1031) mod 65536` read as a signed 16-bit little-endian value. 1031 is
coprime with 65536, so the sequence visits every value before repeating and no
two consecutive samples are equal: a decoder that dropped, duplicated or
reordered a block cannot produce this buffer by accident, the way it could
produce silence by accident.

The same arithmetic is in `tests/native/audio.lisp` as `PCM16-RAMP`, which is
what makes this file checkable: the test that loads it can rebuild the payload
and compare, rather than trusting the loader to have read something.

**WAV, because it is the format with no decoder to disagree about.** The header
below is the 44-byte canonical form -- `RIFF`, `WAVE`, a 16-byte `fmt ` chunk
declaring PCM (format tag 1), and a `data` chunk -- which every audio backend
reads the same way. Nothing here depends on a codec being built into CNA.

    tools/qualification/make-audio-fixtures.py [OUTPUT-DIRECTORY]

Defaults to tests/fixtures, and rewrites the file only when its bytes change, so
running it is not a commit.
"""

import os
import struct
import sys

SAMPLE_RATE = 8000
CHANNELS = 1
BITS = 16
FRAMES = 8000  # exactly one second at 8000 Hz
STEP = 1031


def ramp_pcm16(frames, channels):
    """The deterministic non-zero waveform, signed little-endian PCM16.

    Identical to PCM16-RAMP in tests/native/audio.lisp. Kept as arithmetic in
    both places rather than as a blob in one, so neither can drift without the
    test that compares them failing.
    """
    out = bytearray()
    for n in range(frames * channels):
        out += struct.pack("<H", (n * STEP) % 65536)
    return bytes(out)


def wav(pcm, sample_rate=SAMPLE_RATE, channels=CHANNELS, bits=BITS):
    """The canonical 44-byte RIFF/WAVE header, and PCM after it."""
    block_align = channels * bits // 8
    byte_rate = sample_rate * block_align
    return b"".join([
        b"RIFF",
        struct.pack("<I", 36 + len(pcm)),   # everything after this field
        b"WAVE",
        b"fmt ",
        struct.pack("<I", 16),              # PCM fmt chunk is 16 bytes
        struct.pack("<H", 1),               # format tag 1 = PCM
        struct.pack("<H", channels),
        struct.pack("<I", sample_rate),
        struct.pack("<I", byte_rate),
        struct.pack("<H", block_align),
        struct.pack("<H", bits),
        b"data",
        struct.pack("<I", len(pcm)),
        pcm,
    ])


def write(path, data):
    if os.path.exists(path):
        with open(path, "rb") as fh:
            if fh.read() == data:
                print("unchanged %s" % path)
                return
    with open(path, "wb") as fh:
        fh.write(data)
    print("wrote %s (%d bytes)" % (path, len(data)))


def main(argv):
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(os.path.dirname(here))
    out = argv[0] if argv else os.path.join(root, "tests", "fixtures")
    pcm = ramp_pcm16(FRAMES, CHANNELS)
    assert len(pcm) == FRAMES * CHANNELS * BITS // 8
    write(os.path.join(out, "test-tone.wav"), wav(pcm))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
