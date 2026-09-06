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
    "Microsoft.Xna.Framework.IGameComponent",
    "Microsoft.Xna.Framework.IUpdateable",
    "Microsoft.Xna.Framework.IDrawable",
    "Microsoft.Xna.Framework.GameComponent",
    "Microsoft.Xna.Framework.DrawableGameComponent",
    "Microsoft.Xna.Framework.GameComponentCollection",
    "Microsoft.Xna.Framework.GameComponentCollectionEventArgs",
    "Microsoft.Xna.Framework.LaunchParameters",
    "Microsoft.Xna.Framework.GameWindow",
    "Microsoft.Xna.Framework.TitleContainer",
    "Microsoft.Xna.Framework.Graphics.GraphicsProfile",
    "Microsoft.Xna.Framework.Graphics.ClearOptions",
    "Microsoft.Xna.Framework.Graphics.PresentInterval",
    "Microsoft.Xna.Framework.Graphics.GraphicsDeviceStatus",
    "Microsoft.Xna.Framework.Graphics.DisplayMode",
    "Microsoft.Xna.Framework.Graphics.PresentationParameters",
    "Microsoft.Xna.Framework.Graphics.GraphicsAdapter",
    "Microsoft.Xna.Framework.Graphics.DisplayModeCollection",
    "Microsoft.Xna.Framework.GraphicsDeviceManager",
    "Microsoft.Xna.Framework.Content.ContentManager",
    "Microsoft.Xna.Framework.Graphics.RenderTargetCube",
    "Microsoft.Xna.Framework.Graphics.RenderTargetBinding",
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
    "Microsoft.Xna.Framework.BoundingFrustum",
    "Microsoft.Xna.Framework.Curve",
    "Microsoft.Xna.Framework.CurveKey",
    "Microsoft.Xna.Framework.CurveKeyCollection",
    "Microsoft.Xna.Framework.CurveContinuity",
    "Microsoft.Xna.Framework.CurveLoopType",
    "Microsoft.Xna.Framework.CurveTangent",
    "Microsoft.Xna.Framework.PlayerIndex",
    "Microsoft.Xna.Framework.DisplayOrientation",
    "Microsoft.Xna.Framework.Graphics.GraphicsResource",
    "Microsoft.Xna.Framework.Graphics.GraphicsDevice",
    "Microsoft.Xna.Framework.Graphics.Viewport",
    "Microsoft.Xna.Framework.Graphics.Texture",
    "Microsoft.Xna.Framework.Graphics.Texture2D",
    "Microsoft.Xna.Framework.Graphics.RenderTarget2D",
    "Microsoft.Xna.Framework.Graphics.RenderTargetUsage",
    "Microsoft.Xna.Framework.Graphics.DepthFormat",
    "Microsoft.Xna.Framework.Graphics.SpriteBatch",
    "Microsoft.Xna.Framework.Graphics.SpriteFont",
    "Microsoft.Xna.Framework.Graphics.SpriteSortMode",
    "Microsoft.Xna.Framework.Graphics.SpriteEffects",
    "Microsoft.Xna.Framework.Graphics.SurfaceFormat",
    "Microsoft.Xna.Framework.Graphics.Blend",
    "Microsoft.Xna.Framework.Graphics.BlendFunction",
    "Microsoft.Xna.Framework.Graphics.ColorWriteChannels",
    "Microsoft.Xna.Framework.Graphics.CompareFunction",
    "Microsoft.Xna.Framework.Graphics.StencilOperation",
    "Microsoft.Xna.Framework.Graphics.CullMode",
    "Microsoft.Xna.Framework.Graphics.FillMode",
    "Microsoft.Xna.Framework.Graphics.TextureAddressMode",
    "Microsoft.Xna.Framework.Graphics.TextureFilter",
    "Microsoft.Xna.Framework.Graphics.BlendState",
    "Microsoft.Xna.Framework.Graphics.DepthStencilState",
    "Microsoft.Xna.Framework.Graphics.RasterizerState",
    "Microsoft.Xna.Framework.Graphics.SamplerState",
    "Microsoft.Xna.Framework.Graphics.SamplerStateCollection",
    "Microsoft.Xna.Framework.Graphics.TextureCollection",
    "Microsoft.Xna.Framework.Graphics.VertexElementFormat",
    "Microsoft.Xna.Framework.Graphics.VertexElementUsage",
    "Microsoft.Xna.Framework.Graphics.VertexElement",
    "Microsoft.Xna.Framework.Graphics.VertexDeclaration",
    "Microsoft.Xna.Framework.Graphics.IVertexType",
    "Microsoft.Xna.Framework.Graphics.VertexPositionColor",
    "Microsoft.Xna.Framework.Graphics.VertexPositionTexture",
    "Microsoft.Xna.Framework.Graphics.VertexPositionColorTexture",
    "Microsoft.Xna.Framework.Graphics.VertexPositionNormalTexture",
    "Microsoft.Xna.Framework.Graphics.BufferUsage",
    "Microsoft.Xna.Framework.Graphics.IndexElementSize",
    "Microsoft.Xna.Framework.Graphics.SetDataOptions",
    "Microsoft.Xna.Framework.Graphics.PrimitiveType",
    "Microsoft.Xna.Framework.Graphics.VertexBuffer",
    "Microsoft.Xna.Framework.Graphics.DynamicVertexBuffer",
    "Microsoft.Xna.Framework.Graphics.IndexBuffer",
    "Microsoft.Xna.Framework.Graphics.DynamicIndexBuffer",
    "Microsoft.Xna.Framework.Graphics.VertexBufferBinding",
    "Microsoft.Xna.Framework.Graphics.Effect",
    "Microsoft.Xna.Framework.Graphics.EffectTechnique",
    "Microsoft.Xna.Framework.Graphics.EffectTechniqueCollection",
    "Microsoft.Xna.Framework.Graphics.EffectPass",
    "Microsoft.Xna.Framework.Graphics.EffectPassCollection",
    "Microsoft.Xna.Framework.Graphics.EffectParameter",
    "Microsoft.Xna.Framework.Graphics.EffectParameterCollection",
    "Microsoft.Xna.Framework.Graphics.EffectAnnotation",
    "Microsoft.Xna.Framework.Graphics.EffectAnnotationCollection",
    "Microsoft.Xna.Framework.Graphics.EffectParameterClass",
    "Microsoft.Xna.Framework.Graphics.EffectParameterType",
    "Microsoft.Xna.Framework.Graphics.IEffectMatrices",
    "Microsoft.Xna.Framework.Graphics.IEffectLights",
    "Microsoft.Xna.Framework.Graphics.IEffectFog",
    "Microsoft.Xna.Framework.Graphics.DirectionalLight",
    "Microsoft.Xna.Framework.Graphics.BasicEffect",
    "Microsoft.Xna.Framework.Graphics.AlphaTestEffect",
    "Microsoft.Xna.Framework.Graphics.DualTextureEffect",
    "Microsoft.Xna.Framework.Graphics.SkinnedEffect",
    "Microsoft.Xna.Framework.Graphics.EnvironmentMapEffect",
    "Microsoft.Xna.Framework.Graphics.TextureCube",
    "Microsoft.Xna.Framework.Graphics.CubeMapFace",
    "Microsoft.Xna.Framework.Graphics.PackedVector.Alpha8",
    "Microsoft.Xna.Framework.Graphics.PackedVector.Bgr565",
    "Microsoft.Xna.Framework.Graphics.PackedVector.Bgra4444",
    "Microsoft.Xna.Framework.Graphics.PackedVector.Bgra5551",
    "Microsoft.Xna.Framework.Graphics.PackedVector.Byte4",
    "Microsoft.Xna.Framework.Graphics.PackedVector.HalfSingle",
    "Microsoft.Xna.Framework.Graphics.PackedVector.HalfVector2",
    "Microsoft.Xna.Framework.Graphics.PackedVector.HalfVector4",
    "Microsoft.Xna.Framework.Graphics.PackedVector.NormalizedByte2",
    "Microsoft.Xna.Framework.Graphics.PackedVector.NormalizedByte4",
    "Microsoft.Xna.Framework.Graphics.PackedVector.NormalizedShort2",
    "Microsoft.Xna.Framework.Graphics.PackedVector.NormalizedShort4",
    "Microsoft.Xna.Framework.Graphics.PackedVector.Rg32",
    "Microsoft.Xna.Framework.Graphics.PackedVector.Rgba1010102",
    "Microsoft.Xna.Framework.Graphics.PackedVector.Rgba64",
    "Microsoft.Xna.Framework.Graphics.PackedVector.Short2",
    "Microsoft.Xna.Framework.Graphics.PackedVector.Short4",
    "Microsoft.Xna.Framework.Input.Keyboard",
    "Microsoft.Xna.Framework.Input.KeyboardState",
    "Microsoft.Xna.Framework.Input.KeyState",
    "Microsoft.Xna.Framework.Input.Keys",
    "Microsoft.Xna.Framework.Input.Touch.TouchPanel",
    "Microsoft.Xna.Framework.Input.Touch.TouchCollection",
    "Microsoft.Xna.Framework.Input.Touch.TouchLocation",
    "Microsoft.Xna.Framework.Input.Touch.TouchLocationState",
    "Microsoft.Xna.Framework.Input.Touch.TouchPanelCapabilities",
    "Microsoft.Xna.Framework.Input.Touch.GestureSample",
    "Microsoft.Xna.Framework.Input.Touch.GestureType",
    "Microsoft.Xna.Framework.Input.GamePad",
    "Microsoft.Xna.Framework.Input.GamePadState",
    "Microsoft.Xna.Framework.Input.GamePadButtons",
    "Microsoft.Xna.Framework.Input.GamePadDPad",
    "Microsoft.Xna.Framework.Input.GamePadThumbSticks",
    "Microsoft.Xna.Framework.Input.GamePadTriggers",
    "Microsoft.Xna.Framework.Input.GamePadCapabilities",
    "Microsoft.Xna.Framework.Input.Buttons",
    "Microsoft.Xna.Framework.Input.GamePadType",
    "Microsoft.Xna.Framework.Input.GamePadDeadZone",
    "Microsoft.Xna.Framework.Input.Mouse",
    "Microsoft.Xna.Framework.Input.MouseState",
    "Microsoft.Xna.Framework.Input.ButtonState",
    # --- Microsoft.Xna.Framework.Audio -----------------------------------
    # The dependency-complete SoundEffect closure -- eight types, every type they
    # need already above -- and DynamicSoundEffectInstance, which was the ninth
    # and needed nothing new: it derives from SoundEffectInstance, its two
    # arguments are an Int32 and the AudioChannels already here, and its one
    # event is EventHandler<EventArgs> like every other event in this selection.
    # XACT (AudioEngine, SoundBank, WaveBank, Cue, AudioCategory, RendererDetail)
    # stays out because CNA has no route for any of it; the three Microphone
    # types have a full CNA route family and are a closure of their own, whose
    # interesting half needs a capture device no verification tree has.
    "Microsoft.Xna.Framework.Audio.SoundEffect",
    "Microsoft.Xna.Framework.Audio.SoundEffectInstance",
    "Microsoft.Xna.Framework.Audio.DynamicSoundEffectInstance",
    "Microsoft.Xna.Framework.Audio.AudioListener",
    "Microsoft.Xna.Framework.Audio.AudioEmitter",
    "Microsoft.Xna.Framework.Audio.SoundState",
    "Microsoft.Xna.Framework.Audio.AudioChannels",
    "Microsoft.Xna.Framework.Audio.NoAudioHardwareException",
    "Microsoft.Xna.Framework.Audio.InstancePlayLimitException",
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
            "name": "Foundation 1 and the managed closures",
            "rationale": "Foundation 1 is the dependency closure of a real textured sprite "
                         "game: create a native game, receive its lifecycle, expose its "
                         "graphics device, clear, decode a PNG into a Texture2D, submit a "
                         "SpriteBatch draw, read the keyboard, exit and destroy "
                         "deterministically. The selection then grows one dependency-complete "
                         "closure at a time, in the order NEXT.md records. Some of those "
                         "closures are pure managed and touch no native route -- the 3D "
                         "transform types, the bounding volumes, the Curve family and the "
                         "packed vectors; others reach CNA, as the input surface and the "
                         "graphics state objects do.",
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
