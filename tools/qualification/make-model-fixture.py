#!/usr/bin/env python3
"""Build the deterministic Model fixture: a `.cnj` document and two binary sidecars.

**The smallest model that can prove the things the Model closure claims**, and
not one field larger. It has

  * **two bones in a hierarchy** -- `Root` and `Child`, with `Child.Parent` being
    `Root` -- so `Parent`, `Children`, `Index` and the parent/child object
    identity have something to be true about;
  * **transforms that differ from identity and from each other**, so
    `CopyAbsoluteBoneTransformsTo` composes something. Root translates by
    (10, 0, 0) and Child by (0, 5, 0), which makes the child's absolute transform
    a translation by (10, 5, 0) and a wrong multiplication order visible as
    (10, 5, 0) against (10, 5, 0)'s alternative -- see below;
  * **two meshes**, each with one part, so `Meshes` is a collection rather than a
    single object and `ParentBone` differs between them;
  * a **vertex buffer, an index buffer and an effect** per part, so ownership,
    identity and `Draw` all have real resources;
  * **geometry already in clip space**, which is what lets the SOFTWARE pixel
    proof run with identity world/view/projection matrices and therefore without
    the optional shim.

**The multiplication order is observable and this fixture is built so that it
is.** XNA's `CopyAbsoluteBoneTransformsTo` computes `local * parentAbsolute`.
With pure translations the two orders happen to agree, so the child's transform
also carries a scale: `local = scale(2) * translate(0,5,0)` and
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


ORANGE = (255, 128, 0, 255)
GREEN = (0, 200, 0, 255)


def main(argv):
    out_dir = argv[1] if len(argv) > 1 else "."
    name = argv[2] if len(argv) > 2 else "two-bone-quads"
    os.makedirs(out_dir, exist_ok=True)

    # Two triangles, in clip space, on opposite halves of the screen so a test can
    # tell which mesh drew which pixel. Counter-clockwise in a left-handed clip
    # space is the front face XNA's default CullCounterClockwiseFace keeps.
    vertices = b"".join([
        # mesh 0: the left triangle, orange
        vertex(-0.9, -0.6, 0.0, ORANGE),
        vertex(-0.1, -0.6, 0.0, ORANGE),
        vertex(-0.5, 0.6, 0.0, ORANGE),
        # mesh 1: the right triangle, green
        vertex(0.1, -0.6, 0.0, GREEN),
        vertex(0.9, -0.6, 0.0, GREEN),
        vertex(0.5, 0.6, 0.0, GREEN),
    ])
    indices = struct.pack("<6H", 0, 1, 2, 3, 4, 5)

    verts_name = "%s-verts.bin" % name
    index_name = "%s-index.bin" % name
    with open(os.path.join(out_dir, verts_name), "wb") as fh:
        fh.write(vertices)
    with open(os.path.join(out_dir, index_name), "wb") as fh:
        fh.write(indices)

    document = {
        "cnjVersion": 1,
        "type": "Model",
        # Entry 0 is the root and its parent defaults to -1; a later entry's
        # parent defaults to 0. Both are written out anyway: a fixture that
        # depends on a default is a fixture that tests the default.
        "bones": [
            {"name": "Root", "parent": -1, "transform": translation(10.0, 0.0, 0.0)},
            {"name": "Child", "parent": 0,
             "transform": scale_then_translate(2.0, 0.0, 5.0, 0.0)},
        ],
        "meshes": [
            {
                "name": "LeftTriangle",
                "parentBone": 0,
                "vertices": verts_name,
                "indices": index_name,
                "vertexStride": STRIDE,
                "vertexCount": 3,
                "startIndex": 0,
                "primitiveCount": 1,
                "effect": "BasicEffect",
            },
            {
                "name": "RightTriangle",
                "parentBone": 1,
                "vertices": verts_name,
                "indices": index_name,
                "vertexStride": STRIDE,
                "vertexCount": 3,
                "vertexOffset": 3,
                "startIndex": 3,
                "primitiveCount": 1,
                "effect": "BasicEffect",
            },
        ],
    }
    path = os.path.join(out_dir, "%s.cnj" % name)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(document, fh, indent=2)
        fh.write("\n")
    print("wrote %s, %s and %s" % (path, verts_name, index_name))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
