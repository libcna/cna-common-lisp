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
    # stays out, and **not** for the reason this comment used to give. It said
    # "CNA has no route for any of it", and that was measured false: `xact.h' has
    # 62 routes covering all five reachable types. The real reason is that it
    # could not be *qualified*. `cna_audio_engine_create' takes a path to an
    # `.xgs' settings file, `cna_wave_bank_create' an `.xwb' and
    # `cna_sound_bank_create' an `.xsb', and those are binaries built by
    # Microsoft's XACT authoring tool -- so no fixture for them can be generated
    # in this repository, which is the standard every other fixture here meets.
    "Microsoft.Xna.Framework.Audio.SoundEffect",
    "Microsoft.Xna.Framework.Audio.SoundEffectInstance",
    "Microsoft.Xna.Framework.Audio.DynamicSoundEffectInstance",
    "Microsoft.Xna.Framework.Audio.AudioListener",
    "Microsoft.Xna.Framework.Audio.AudioEmitter",
    "Microsoft.Xna.Framework.Audio.SoundState",
    "Microsoft.Xna.Framework.Audio.AudioChannels",
    "Microsoft.Xna.Framework.Audio.NoAudioHardwareException",
    "Microsoft.Xna.Framework.Audio.InstancePlayLimitException",
    # --- the Microphone family -------------------------------------------
    # Dependency-complete and measured, not listed: the closure of these three
    # over the snapshot's own `baseType', `interfaces', member return types and
    # parameter types adds **nothing**. Everything they reach is either already
    # selected or the base-class library's -- `System.Byte[]', `System.TimeSpan',
    # `System.Int32', `System.String', `System.Boolean', `System.Exception', and
    # the `ReadOnlyCollection<Microphone>' that `All' answers, which is the same
    # BCL collection wrapper `GraphicsAdapter.Adapters' already projects onto a
    # Common Lisp list.
    #
    # **The reason this family was held back is gone, and it was measured
    # rather than assumed.** It used to read "whose interesting half needs a
    # capture device no verification tree has". SDL's `dummy' audio driver
    # enumerates capture devices that start, stop, and advance a PCM16 stream at
    # their reported sample rate, so both halves qualify deterministically and
    # with no hardware -- the same way `SDL_AUDIODRIVER=dummy' already qualifies
    # the playback half.
    #
    # `MicrophoneCollection' is **not** here and is not a member of this closure:
    # it is `private' in the pinned assembly, so it is not in the 257-type public
    # snapshot at all, and `Microphone.All' answers the BCL wrapper rather than
    # it. The two CNA type-name routes are likewise not members; they answer the
    # microphone type's .NET name, which is machinery, exactly as
    # `cna_game_copy_type_name' is.
    "Microsoft.Xna.Framework.Audio.Microphone",
    "Microsoft.Xna.Framework.Audio.MicrophoneState",
    "Microsoft.Xna.Framework.Audio.NoMicrophoneConnectedException",
    # --- the Model family ------------------------------------------------
    # Dependency-complete and measured rather than listed: the closure of these
    # twelve over the pinned snapshot's own `baseType`, `interfaces`, member
    # return types and parameter types adds **nothing**. Every XNA type they
    # reach -- Effect, Matrix, BoundingSphere, VertexBuffer, IndexBuffer,
    # GraphicsDevice -- was already selected, and everything else they reach is
    # the base-class library's: System.Object, System.String, and the generic
    # collection interfaces `ReadOnlyCollection<T>` carries.
    #
    # **The four nested enumerators are in, and that is what dependency-complete
    # means here.** `ModelBoneCollection.GetEnumerator()` returns
    # `ModelBoneCollection+Enumerator`, an XNA type in this profile rather than
    # a BCL one -- unlike `DisplayModeCollection`'s and the effect collections',
    # whose enumerators are `List<T>.Enumerator` and are therefore outside the
    # selection by the same rule that keeps `System.IO.Stream` out. Selecting
    # the collection and not its enumerator would leave `GetEnumerator()`
    # answering a type the profile does not admit.
    #
    # CNA's own model extensions -- morph targets, the skinned-model EXT family,
    # animation clips, SkinningData, AnimationPlayer, the glTF import report,
    # cameras, skins and material variants -- are **not** here and are not XNA.
    # They share `models.h` with these routes and nothing else; a CNA route is
    # not an argument for a member, which is the rule `cna_sprite_font_create`
    # is already unbound under.
    "Microsoft.Xna.Framework.Graphics.Model",
    "Microsoft.Xna.Framework.Graphics.ModelBone",
    "Microsoft.Xna.Framework.Graphics.ModelBoneCollection",
    "Microsoft.Xna.Framework.Graphics.ModelBoneCollection+Enumerator",
    "Microsoft.Xna.Framework.Graphics.ModelMesh",
    "Microsoft.Xna.Framework.Graphics.ModelMeshCollection",
    "Microsoft.Xna.Framework.Graphics.ModelMeshCollection+Enumerator",
    "Microsoft.Xna.Framework.Graphics.ModelMeshPart",
    "Microsoft.Xna.Framework.Graphics.ModelMeshPartCollection",
    "Microsoft.Xna.Framework.Graphics.ModelMeshPartCollection+Enumerator",
    "Microsoft.Xna.Framework.Graphics.ModelEffectCollection",
    "Microsoft.Xna.Framework.Graphics.ModelEffectCollection+Enumerator",
    # --- Microsoft.Xna.Framework.Media: the playback closure ---------------
    # `MediaPlayer' and everything it needs to play a song: the one `MediaQueue'
    # it owns, `Song' and `SongCollection', the `MediaState' enumeration and the
    # `VisualizationData' buffer pair.
    #
    # **Three members of `Song' are declared missing so that this is a closure
    # rather than a namespace.** `Song.Artist', `Song.Album' and `Song.Genre'
    # answer `Artist', `Album' and `Genre', which are *media-library* entities:
    # their CNA routes are in `media_library.h' rather than `media.h', and
    # `cna_song_get_album' and its two siblings document that only a song
    # obtained from a media library has one -- a song a caller created from a
    # file path has no library context, so the route reports CNA_FALSE. Measured
    # true on all three admitted ABIs, for the only kind of song this closure can
    # make.
    #
    # Selecting `Album', `AlbumCollection', `Artist' and `Genre' to satisfy those
    # three would add **53 members that nothing in this repository could
    # exercise**, which is the reason `MediaLibrary' was not the closure chosen.
    # They are declared missing under DEPENDENCY_NOT_SELECTED instead -- exactly
    # what `EffectParameter.GetValueTexture3D' is declared under for `Texture3D',
    # which is the standing precedent for a member whose type is not selected.
    #
    # **The library half joined on 2026-09-08, and the reason it was absent is
    # the reason it is here now.** It used to say that `media_library.h' calls an
    # empty library an ordinary result, so CI could qualify *empty* and nothing
    # else. That was measuring the wrong thing: SDL resolves the user folders
    # through `$XDG_CONFIG_HOME/user-dirs.dirs', so pointing that at a generated
    # fixture makes the library deterministic and non-empty on every admitted
    # ABI -- songs 2, albums 2, artists 2, genres 1, pictures 2, measured three
    # times each. docs/media-library-audit.md has the whole audit.
    #
    # The music half is selected first and the picture half with it, because
    # `MediaLibrary' itself returns `PictureCollection' and `PictureAlbum' from
    # six of its own members: a closure that stopped at the music half would make
    # `MediaLibrary' partial by construction rather than by any limit.
    "Microsoft.Xna.Framework.Media.MediaPlayer",
    "Microsoft.Xna.Framework.Media.MediaState",
    "Microsoft.Xna.Framework.Media.MediaQueue",
    "Microsoft.Xna.Framework.Media.Song",
    "Microsoft.Xna.Framework.Media.SongCollection",
    "Microsoft.Xna.Framework.Media.VisualizationData",
    "Microsoft.Xna.Framework.Media.MediaLibrary",
    "Microsoft.Xna.Framework.Media.MediaSource",
    "Microsoft.Xna.Framework.Media.MediaSourceType",
    "Microsoft.Xna.Framework.Media.Album",
    "Microsoft.Xna.Framework.Media.AlbumCollection",
    "Microsoft.Xna.Framework.Media.Artist",
    "Microsoft.Xna.Framework.Media.ArtistCollection",
    "Microsoft.Xna.Framework.Media.Genre",
    "Microsoft.Xna.Framework.Media.GenreCollection",
    "Microsoft.Xna.Framework.Media.Playlist",
    "Microsoft.Xna.Framework.Media.PlaylistCollection",
    # --- Microsoft.Xna.Framework.Storage -----------------------------------
    # All three types of the namespace, and the closure is complete: everything
    # they reach beyond each other is the base-class library's -- `System.String',
    # `System.Int64', `System.Boolean', `System.String[]', `System.Exception', and
    # the four types the two design questions are about: `System.IAsyncResult',
    # `System.AsyncCallback', `System.IO.Stream' and the three `System.IO' file
    # enumerations. `Microsoft.Xna.Framework.PlayerIndex' is the one XNA type they
    # reach and it has been selected since Foundation 1.
    #
    # The two questions are answered in `docs/limitations.md' and the answers are
    # both "project it the way the pinned IL says, and invent nothing":
    # `IAsyncResult' becomes an opaque already-complete object because XNA's own
    # is already complete, and `System.IO.Stream' becomes a real Common Lisp
    # stream because that is what this binding has always said it becomes.
    # --- game services and device selection --------------------------------
    # **Five types, 21 members, and the count is the contract's rather than the
    # planning pass's.** The plan that recommended this closure counted 17
    # members over five types, with `FrameworkDispatcher' in the list and
    # `IGraphicsDeviceService' absent. The dependency closure over the pinned
    # snapshot says otherwise, and it was recomputed rather than trusted:
    #
    # * `Graphics.IGraphicsDeviceService' is **not optional**. The already
    #   selected `GraphicsDeviceManager' names it in its own `interfaces', beside
    #   `IGraphicsDeviceManager' and `System.IDisposable', so the closure of the
    #   selection *as it already stood* reached it. It was a hole in the profile
    #   before this closure and is filled by it.
    # * `FrameworkDispatcher' is **not reached by anything**. Nothing in the
    #   257-type snapshot names it in a base type, an interface, a return type or
    #   a parameter type -- it is a static pump a program calls itself. It is not
    #   selected here, because `cna_framework_dispatcher_update' existing is not
    #   an argument for a member: that is the rule `cna_sprite_font_create' is
    #   already unbound under, and the rule CNA's own model extensions are
    #   excluded by.
    #
    # Adding these five reaches **no** further unselected type: `Adapter',
    # `GraphicsProfile' and `PresentationParameters' are all already here, and
    # everything else the five touch is the base-class library's --
    # `System.Type', `System.Object', `System.IServiceProvider', `System.EventArgs',
    # `System.EventHandler`1' and the `List<GraphicsDeviceInformation>' that
    # `RankDevices' takes.
    #
    # **None of those BCL types is added to the profile**, and each collapses the
    # way this binding already collapses its kind. `System.Type' becomes a service
    # type designator -- a class or a declared protocol -- rather than CLR
    # reflection; `System.IServiceProvider' becomes the one generic function
    # `GET-SERVICE', the way `System.IAsyncResult' became an opaque object and
    # `System.IO.Stream' became a Common Lisp stream; `List<T>' becomes an
    # ordinary mutable Lisp sequence, as every other generic collection here does;
    # and `System.EventArgs' stays collapsed, as it has been since `Game''s four
    # events. `docs/common-lisp-mapping.md' carries all four rules.
    "Microsoft.Xna.Framework.GameServiceContainer",
    "Microsoft.Xna.Framework.IGraphicsDeviceManager",
    "Microsoft.Xna.Framework.Graphics.IGraphicsDeviceService",
    "Microsoft.Xna.Framework.GraphicsDeviceInformation",
    "Microsoft.Xna.Framework.PreparingDeviceSettingsEventArgs",
    "Microsoft.Xna.Framework.Storage.StorageDevice",
    "Microsoft.Xna.Framework.Storage.StorageContainer",
    "Microsoft.Xna.Framework.Storage.StorageDeviceNotConnectedException",
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
