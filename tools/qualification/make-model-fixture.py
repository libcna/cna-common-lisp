#!/usr/bin/env python3
"""Build the deterministic Model fixture: a `.cnj` document and two binary sidecars.

**The smallest model that can prove the things the Model closure claims**, and
not one field larger. It has

  * **three bones in a two-deep hierarchy** -- `Root`, `Arm` under it and `Hand`
    under that -- so `Parent`, `Children`, `Index` and the parent/child object
    identity have something to be true about, and so that the composition below
    happens between two bones whose transforms both survive the reader;
  * **transforms that differ from identity and from each other**, so
    `CopyAbsoluteBoneTransformsTo` composes something: `Arm` translates by
    (10, 0, 0) and `Hand` scales by two and translates by (0, 5, 0);
  * **two meshes**, each with one part, so `Meshes` is a collection rather than a
    single object and `ParentBone` differs between them;
  * a **vertex buffer, an index buffer and an effect** per part, so ownership,
    identity and `Draw` all have real resources;
  * **geometry already in clip space**, which is what lets the SOFTWARE pixel
    proof run with identity world/view/projection matrices and therefore without
    the optional shim.

**One vertex/index pair per mesh, and that is the reader's shape rather than a
preference.** CNA's Model `.cnj` reader takes a mesh's whole vertex file as one
mesh part: it honours `name`, `vertices`, `indices`, `vertexStride`, `effect`,
`vertexColorEnabled`, `parentBone` and the material fields, and derives the
vertex and primitive counts from the file sizes. It reads no `vertexCount`,
`primitiveCount`, `startIndex` or `vertexOffset` -- measured, after a first
version of this fixture wrote them and got two meshes of six vertices each.

`vertexColorEnabled` is set because both BasicEffect and SkinnedEffect default
`VertexColorEnabled` to false, so without it the colour bytes are uploaded and
the shader ignores them -- which would make the pixel proof read the clear colour
and look like a culled triangle.

**The multiplication order is observable and this fixture is built so that it
is.** XNA's `CopyAbsoluteBoneTransformsTo` computes `local * parentAbsolute`.
With pure translations the two orders happen to agree, so `Hand`'s transform also
carries a scale: `local = scale(2) * translate(0,5,0)` and
`parent = translate(10,0,0)`. `local * parent` translates by (10, 5, 0);
`parent * local` translates by (20, 5, 0). One number tells the two apart.

    python3 tools/qualification/make-model-fixture.py OUT-DIR [NAME]

Writes OUT-DIR/NAME.cnj, OUT-DIR/NAME-verts.bin and OUT-DIR/NAME-index.bin.
Pure standard library: unlike the font fixture this needs no Pillow, because a
model is numbers rather than pixels.
"""
import json
import os
import struct
import sys

# VertexPositionColor: float3 position + a packed BGRA colour, stride 16. The
# stock BasicEffect draws it with VertexColorEnabled, which is the one stock
# effect path the qualification renderers actually shade.
STRIDE = 16


def vertex(x, y, z, rgba):
    """One VertexPositionColor: position, then the colour as XNA packs it."""
    r, g, b, a = rgba
    return struct.pack("<fff", x, y, z) + struct.pack("<BBBB", r, g, b, a)


def matrix(m):
    """A 4x4 row-major matrix as the sixteen numbers the .cnj carries."""
    return [float(v) for v in m]


def translation(x, y, z):
    return matrix([1, 0, 0, 0,
                   0, 1, 0, 0,
                   0, 0, 1, 0,
                   x, y, z, 1])


def scale_then_translate(s, x, y, z):
    """`Matrix.CreateScale(s) * Matrix.CreateTranslation(x, y, z)`, row-major."""
    return matrix([s, 0, 0, 0,
                   0, s, 0, 0,
                   0, 0, s, 0,
                   x, y, z, 1])


# **Channel values that survive the pipeline exactly.** A vertex colour makes a
# round trip through a normalised float, and 200 came back as 199 when this
# fixture first used it -- a real one-unit loss, not a renderer fault, and not
# something a pixel proof should have to spell an epsilon for. 0, 128 and 255 were
# measured to survive unchanged, so the two colours are built from those.
ORANGE = (255, 128, 0, 255)
GREEN = (0, 255, 128, 255)


def main(argv):
    out_dir = argv[1] if len(argv) > 1 else "."
    name = argv[2] if len(argv) > 2 else "three-bone-triangles"
    os.makedirs(out_dir, exist_ok=True)

    # Two triangles, in clip space, on opposite halves of the screen so a test can
    # tell which mesh drew which pixel. Counter-clockwise in a left-handed clip
    # space is the front face XNA's default CullCounterClockwiseFace keeps.
    # Wound **clockwise in clip space**, which is front-facing once the viewport
    # transform has flipped Y -- so XNA's default CullCounterClockwiseFace keeps
    # them. Bottom-left, apex, bottom-right; the other order draws nothing and
    # reads back as the clear colour, which looks exactly like a broken draw.
    meshes = [
        ("left", ORANGE, [(-0.9, -0.6), (-0.5, 0.6), (-0.1, -0.6)]),
        ("right", GREEN, [(0.1, -0.6), (0.5, 0.6), (0.9, -0.6)]),
    ]
    written = []
    for slug, colour, corners in meshes:
        payload = b"".join(vertex(x, y, 0.0, colour) for x, y in corners)
        verts_name = "%s-%s-verts.bin" % (name, slug)
        index_name = "%s-%s-index.bin" % (name, slug)
        with open(os.path.join(out_dir, verts_name), "wb") as fh:
            fh.write(payload)
        with open(os.path.join(out_dir, index_name), "wb") as fh:
            fh.write(struct.pack("<3H", 0, 1, 2))
        written.append((verts_name, index_name))

    document = {
        "cnjVersion": 1,
        "type": "Model",
        # Entry 0 is the root and its parent defaults to -1; a later entry's
        # parent defaults to 0. Both are written out anyway: a fixture that
        # depends on a default is a fixture that tests the default.
        # **Three bones, and the interesting pair is not the first.** CNA's reader
        # gives entry 0 the identity transform whatever the file says -- measured,
        # after a two-bone version of this fixture read its root back as identity
        # -- so the composition the absolute-transform test needs happens one level
        # down, between `Arm' and `Hand'.
        "bones": [
            {"name": "Root", "parent": -1, "transform": translation(0.0, 0.0, 0.0)},
            {"name": "Arm", "parent": 0, "transform": translation(10.0, 0.0, 0.0)},
            {"name": "Hand", "parent": 1,
             "transform": scale_then_translate(2.0, 0.0, 5.0, 0.0)},
        ],
        "meshes": [
            {
                "name": mesh_name,
                "parentBone": bone,
                "vertices": verts_name,
                "indices": index_name,
                "vertexStride": STRIDE,
                "effect": "BasicEffect",
                "vertexColorEnabled": True,
            }
            for mesh_name, bone, (verts_name, index_name)
            in zip(("LeftTriangle", "RightTriangle"), (1, 2), written)
        ],
    }
    path = os.path.join(out_dir, "%s.cnj" % name)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(document, fh, indent=2)
        fh.write("\n")
    print("wrote %s and %d sidecar pairs" % (path, len(written)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
