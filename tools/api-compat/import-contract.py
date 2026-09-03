#!/usr/bin/env python3
"""Import the selected XNA 4.0 Windows contract subset.

The authority is a hash-pinned public-metadata snapshot of the Microsoft XNA
Framework 4.0 Windows runtime profile: 257 types with their public members. It is
metadata, not a Microsoft binary, and no Microsoft binary is stored here.

This tool refuses to run unless the snapshot's SHA-256 is exactly the pinned one,
extracts the types CNA-Lisp has selected, and writes them with their provenance.
Re-running it with a different snapshot changes nothing unless the hash matches.

  python3 tools/api-compat/import-contract.py <path-to-snapshot>
"""
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "reference", "xna40-selected-contract.json")

PINNED_SHA256 = "7207908eb7926cc90a156d0370c907add4dda465421cea1cbec51afba2f97fdc"
EXPECTED_TYPES = 257

SELECTED = [
    "Microsoft.Xna.Framework.Game",
    "Microsoft.Xna.Framework.GameTime",
    "Microsoft.Xna.Framework.GraphicsDeviceManager",
    "Microsoft.Xna.Framework.Color",
    "Microsoft.Xna.Framework.Point",
    "Microsoft.Xna.Framework.Rectangle",
    "Microsoft.Xna.Framework.Vector2",
    "Microsoft.Xna.Framework.Vector3",
    "Microsoft.Xna.Framework.Vector4",
    "Microsoft.Xna.Framework.MathHelper",
    "Microsoft.Xna.Framework.Quaternion",
    "Microsoft.Xna.Framework.Matrix",
    "Microsoft.Xna.Framework.Plane",
    "Microsoft.Xna.Framework.ContainmentType",
    "Microsoft.Xna.Framework.PlaneIntersectionType",
    "Microsoft.Xna.Framework.Ray",
    "Microsoft.Xna.Framework.BoundingBox",
    "Microsoft.Xna.Framework.BoundingSphere",
    "Microsoft.Xna.Framework.PlayerIndex",
    "Microsoft.Xna.Framework.Graphics.GraphicsResource",
    "Microsoft.Xna.Framework.Graphics.GraphicsDevice",
    "Microsoft.Xna.Framework.Graphics.Viewport",
    "Microsoft.Xna.Framework.Graphics.Texture",
    "Microsoft.Xna.Framework.Graphics.Texture2D",
    "Microsoft.Xna.Framework.Graphics.SpriteBatch",
    "Microsoft.Xna.Framework.Graphics.SpriteSortMode",
    "Microsoft.Xna.Framework.Graphics.SpriteEffects",
    "Microsoft.Xna.Framework.Graphics.SurfaceFormat",
    "Microsoft.Xna.Framework.Input.Keyboard",
    "Microsoft.Xna.Framework.Input.KeyboardState",
    "Microsoft.Xna.Framework.Input.KeyState",
    "Microsoft.Xna.Framework.Input.Keys",
]


def main(argv):
    if len(argv) != 1:
        sys.stderr.write(__doc__)
        return 2
    path = argv[0]
    with open(path, "rb") as fh:
        raw = fh.read()
    digest = hashlib.sha256(raw).hexdigest()
    if digest != PINNED_SHA256:
        sys.stderr.write(
            "refusing to import %s\n  its SHA-256 is %s\n  the pinned one is  %s\n"
            "A snapshot whose hash does not match is not the pinned authority.\n"
            % (path, digest, PINNED_SHA256))
        return 1
    snapshot = json.loads(raw.decode("utf-8"))
    if len(snapshot["types"]) != EXPECTED_TYPES:
        sys.stderr.write("the snapshot holds %d types, not the pinned %d\n"
                         % (len(snapshot["types"]), EXPECTED_TYPES))
        return 1

    by_name = {t["name"]: t for t in snapshot["types"]}
    missing = [n for n in SELECTED if n not in by_name]
    if missing:
        sys.stderr.write("selected types absent from the snapshot: %s\n" % missing)
        return 1

    types = [by_name[n] for n in SELECTED]
    members = sum(len(t["members"]) for t in types)
    out = {
        "schema_version": 1,
        "profile": snapshot["profile"],
        "provenance": {
            "authority": "hash-pinned public metadata of the Microsoft XNA Framework 4.0 "
                         "Windows runtime profile",
            "snapshot_sha256": PINNED_SHA256,
            "snapshot_types": EXPECTED_TYPES,
            "note": "Public contract metadata only. No Microsoft binary is stored in this "
                    "repository or distributed with it. Reproduce with "
                    "tools/api-compat/import-contract.py and a snapshot of the pinned hash.",
        },
        "selection": {
            "name": "Foundation 1",
            "rationale": "The dependency closure of a real textured sprite game: create a "
                         "native game, receive its lifecycle, expose its graphics device, "
                         "clear, decode a PNG into a Texture2D, submit a SpriteBatch draw, "
                         "read the keyboard, exit and destroy deterministically.",
            "type_count": len(types),
            "member_count": members,
        },
        "types": types,
    }
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump(out, fh, indent=1, sort_keys=False)
        fh.write("\n")
    print("imported %d types and %d members into %s"
          % (len(types), members, os.path.relpath(OUT, ROOT)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
