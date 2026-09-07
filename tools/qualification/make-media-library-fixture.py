#!/usr/bin/env python3
"""Generate a deterministic MediaLibrary fixture tree.

CNA's media library scans the platform's user folders, and SDL resolves those
through ``$XDG_CONFIG_HOME/user-dirs.dirs`` -- CNA's own C-API suite says so in
as many words and builds its fixture the same way.  Pointing that at a generated
tree is what turns "whatever music this machine happens to hold" into a library
with a known count.

    make-media-library-fixture.py <root>

writes::

    <root>/config/user-dirs.dirs      XDG_MUSIC_DIR and XDG_PICTURES_DIR
    <root>/Music/cna-lisp-probe.mp3   one tag-only MP3
    <root>/Pictures/                  empty

and prints the ``XDG_CONFIG_HOME`` a probe should run with.

**The MP3 carries tags and no audio.**  The index reads a song's title, artist,
album and genre from its ID3 tags, so a frame-only file produces a real song,
album, artist and genre without a recording in the tree.  That is CNA's own
technique, not an invention here.
"""
import os
import struct
import sys

ARTIST = "CNA-Lisp Probe Artist"
ALBUM = "CNA-Lisp Probe Album"
GENRE = "Probe Genre"
TITLE = "Probe Track One"


def text_frame(frame_id: str, text: str) -> bytes:
    """One ID3v2.3 text frame: id, big-endian size, two flag bytes, encoding, text."""
    payload = b"\x00" + text.encode("latin-1")          # 0x00 = ISO-8859-1
    return frame_id.encode("ascii") + struct.pack(">I", len(payload)) + b"\x00\x00" + payload


def syncsafe(value: int) -> bytes:
    """ID3v2 sizes are seven bits per byte, so no byte can look like a sync word."""
    return bytes(((value >> 21) & 0x7F, (value >> 14) & 0x7F,
                  (value >> 7) & 0x7F, value & 0x7F))


def tagged_mp3() -> bytes:
    frames = b"".join((text_frame("TIT2", TITLE), text_frame("TPE1", ARTIST),
                       text_frame("TALB", ALBUM), text_frame("TCON", GENRE)))
    header = b"ID3" + bytes((3, 0, 0)) + syncsafe(len(frames))
    return header + frames


def main(argv):
    if len(argv) != 2:
        sys.exit("usage: make-media-library-fixture.py <root>")
    root = os.path.abspath(argv[1])
    config, music, pictures = (os.path.join(root, name)
                               for name in ("config", "Music", "Pictures"))
    for directory in (config, music, pictures):
        os.makedirs(directory, exist_ok=True)
    with open(os.path.join(config, "user-dirs.dirs"), "w", encoding="utf-8") as handle:
        handle.write('XDG_MUSIC_DIR="%s"\n' % music)
        handle.write('XDG_PICTURES_DIR="%s"\n' % pictures)
    with open(os.path.join(music, "cna-lisp-probe.mp3"), "wb") as handle:
        handle.write(tagged_mp3())
    print("fixture root : %s" % root)
    print("one song     : %s / %s / %s / %s" % (TITLE, ARTIST, ALBUM, GENRE))
    print("run with     : XDG_CONFIG_HOME=%s" % config)


if __name__ == "__main__":
    main(sys.argv)
