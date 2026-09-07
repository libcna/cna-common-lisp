;;;; cna-common-lisp.asd --- CNA-Lisp: a Common Lisp binding for CNA.
;;;;
;;;; The public API of this system is idiomatic Common Lisp and CLOS. The CNA
;;;; C ABI is a private implementation detail that never reaches a consumer.

(defsystem "cna-common-lisp"
  :description "CNA-Lisp: an object-oriented Common Lisp/CLOS projection of the selected
Microsoft XNA Framework 4.0 Windows runtime contract, over the CNA C ABI."
  :author "Robert Vokac <robertvokac@robertvokac.com>"
  :license "MS-PL"
  :version "0.1.0"
  ;; `trivial-gray-streams' is what `System.IO.Stream' needs to stay an ordinary
  ;; Common Lisp stream once a CNA-owned one has to cross the boundary -- see
  ;; src/storage/storage-stream.lisp. It is a few hundred lines of portable
  ;; Common Lisp with no foreign code and no build step, so it costs a released
  ;; binding nothing that the `cffi-libffi' refusal is protecting.
  :depends-on ("cffi" "babel" "bordeaux-threads" "trivial-gray-streams" "uiop")
  :serial t
  :pathname "src"
  :components
  ((:file "packages")
   ;; --- private foreign layer --------------------------------------------
   (:file "internal/ffi/package")
   (:file "internal/ffi/types")
   (:file "internal/ffi/constants.generated")
   (:file "internal/ffi/structs.generated")
   (:file "internal/ffi/callbacks")
   (:file "internal/ffi/functions.generated")
   ;; --- conditions come before anything that can fail ---------------------
   (:file "framework/conditions")
   ;; Keyword sets that name a CLR overload and nothing else. Before everything
   ;; that collapses an overload family, which is most of the graphics surface.
   (:file "framework/overloads")
   ;; --- private runtime ---------------------------------------------------
   (:file "internal/float-semantics")
   (:file "internal/callback-conditions")
   (:file "internal/results")
   (:file "internal/utf8")
   (:file "internal/utf16")
   (:file "internal/native-library")
   (:file "internal/abi-gate")
   (:file "internal/threads")
   (:file "internal/ownership")
   (:file "internal/callback-registry")
   ;; --- Microsoft.Xna.Framework -------------------------------------------
   (:file "framework/disposable")
   ;; The narrowed System.IO.Stream bridge: no type of its own, just the checks
   ;; and the two transfers the XNA members that take a Stream need.
   (:file "framework/streams")
   (:file "framework/binary32")
   (:file "framework/math-helper")
   (:file "framework/enums")
   (:file "framework/value-types")
   (:file "framework/vector3")
   (:file "framework/vector4")
   (:file "framework/quaternion")
   (:file "framework/matrix")
   (:file "framework/transforms")
   (:file "framework/plane")
   (:file "framework/bounding-volumes")
   (:file "framework/gjk")
   (:file "framework/bounding-frustum")
   (:file "framework/curve")
   (:file "framework/color")
   (:file "framework/predefined-colors.generated")
   (:file "framework/named-colors")
   (:file "framework/game-time")
   ;; --- Microsoft.Xna.Framework.Graphics ----------------------------------
   ;; The event mechanism knows about no class, so it loads before the two
   ;; namespaces whose types raise events.
   (:file "runtime/event-machinery")
   (:file "graphics/enums")
   (:file "graphics/native-values")
   ;; GraphicsResource is the base of the state objects and the vertex
   ;; declaration as well as of the handle-bearing resources, so it loads before
   ;; all of them rather than in the middle of them.
   (:file "graphics/graphics-resource")
   (:file "graphics/state-objects")
   (:file "graphics/vertex-types")
   (:file "graphics/buffer-data")
   (:file "graphics/packed-vector")
   (:file "graphics/viewport")
   (:file "graphics/graphics-device")
   (:file "graphics/texture-2d")
   (:file "graphics/texture-cube")
   (:file "graphics/buffers")
   ;; RenderTarget2D is a Texture2D and raises a buffer-shaped ContentLost, so
   ;; it loads after both.
   (:file "graphics/render-target")
   ;; The cube target derives from TextureCube and RenderTargetBinding names
   ;; both kinds, so this loads after both target families exist.
   (:file "graphics/render-target-cube")
   ;; DisplayMode and PresentationParameters are value snapshots the device
   ;; answers; they load after the enumerations they carry -- DepthFormat and
   ;; RenderTargetUsage are declared with the render targets -- and they carry
   ;; the three GraphicsDevice readers with them for the same reason.
   (:file "graphics/display")
   ;; The adapter reads through the device facade and builds DisplayModes, so it
   ;; loads after both.
   (:file "graphics/graphics-adapter")
   (:file "graphics/drawing")
   ;; Effect is a GraphicsResource, and the four view kinds hanging off it are
   ;; not; both halves are here, and BasicEffect after them.
   (:file "graphics/effect")
   (:file "graphics/effect-parameter")
   (:file "graphics/basic-effect")
   (:file "graphics/stock-effects")
   ;; The Model family, which needs the effect graph and both buffer kinds.
   (:file "graphics/model")
   (:file "graphics/state-collections")
   ;; SpriteFont is not a GraphicsResource -- XNA derives it from Object --
   ;; and SpriteBatch.DrawString specialises on it, so it loads first.
   (:file "graphics/sprite-font")
   (:file "graphics/sprite-batch")
   ;; --- Microsoft.Xna.Framework.Input -------------------------------------
   (:file "input/keys")
   (:file "input/keyboard-state")
   (:file "input/keyboard")
   (:file "input/mouse")
   (:file "input/game-pad")
   (:file "input/touch")
   ;; --- the service container and the two device-service interfaces --------
   ;; Before GAME, because `Game.Services' is a slot of that class and XNA's own
   ;; constructor fills the field before its body runs. The container reaches
   ;; nothing but the condition types, so this is the earliest it can go.
   (:file "runtime/game-services")
   (:file "runtime/device-service-protocols")
   ;; GraphicsDeviceInformation needs PresentationParameters and GraphicsAdapter,
   ;; both of which are above, and is needed by the manager below.
   ;; --- Game and the graphics device manager ------------------------------
   (:file "runtime/game")
   (:file "runtime/game-events")
   ;; The native cross-check for CNA's two canonical service slots. After GAME,
   ;; because it reads `Game.Services' and the game's handle.
   (:file "runtime/graphics-device-manager")
   ;; GameWindow is a facade over the game and uses the event machinery, so it
   ;; loads after GAME and before anything that reaches a window.
   (:file "runtime/game-window")
   (:file "runtime/manager-events")
   ;; PreparingDeviceSettings: the event args, the fifth virtual raiser and the
   ;; mutable callback. After manager-events, whose raiser table and release it
   ;; shares, and after graphics-device-information, whose object it carries.
   ;; The graphics device's own four events. After manager-events, because three
   ;; of the four pairs are shared with types declared there and in
   ;; graphics-resource, and a method needs its generic function to exist.
   (:file "graphics/graphics-device-events")
   ;; The component engine: classes CNA calls back into, and the collection the
   ;; game drives them from. After Game, whose class it extends.
   (:file "runtime/game-components")
   ;; TitleContainer resolves the title location through a game, so it loads
   ;; after GAME exists.
   (:file "runtime/title-container")
   ;; --- Microsoft.Xna.Framework.Audio --------------------------------------
   ;; The two exceptions first: they are conditions, and a condition has to exist
   ;; before the code that signals it. Then the enumerations, then the two
   ;; spatial value holders, which name Vector3 and nothing else.
   (:file "audio/conditions")
   (:file "audio/enums")
   (:file "audio/spatial")
   ;; The RIFF/WAVE shape FromStream accepts. Before sound-effect, which calls it
   ;; before CNA's decoder -- which accepts more than XNA does.
   (:file "audio/wave")
   ;; SoundEffect names SOUND-EFFECT-INSTANCE in CREATE-INSTANCE and the instance
   ;; names SOUND-EFFECT in its owner slot, so the two are mutually recursive at
   ;; run time and orderable at load time: the effect first, because the instance
   ;; specialises on its class.
   (:file "audio/sound-effect")
   (:file "audio/sound-effect-instance")
   ;; The streaming subclass last of the three, because it specialises the base
   ;; class's construction and destruction hooks and reuses SoundEffect's own
   ;; validators and sample arithmetic. It names no SOUND-EFFECT: a
   ;; DynamicSoundEffectInstance has none, and is a child of the game directly.
   (:file "audio/dynamic-sound-effect-instance")
   ;; The capture half, last of the namespace. It is not a NATIVE-OBJECT and owns
   ;; no handle -- the runtime owns the devices -- but it reuses SoundEffect's
   ;; active-game resolution, its buffer/offset/count validators and its TimeSpan
   ;; arithmetic, so it loads after the three that define them.
   (:file "audio/microphone")
   ;; --- Microsoft.Xna.Framework.Media --------------------------------------
   ;; The playback closure. After Audio because it resolves the active game the
   ;; same way and because nothing here is a SoundEffect; before Content, which
   ;; names neither. The enumeration and the buffer pair first -- both are pure
   ;; values -- then Song and SongCollection, which are native objects, then the
   ;; queue facade over them, then the static player that drives all three.
   (:file "media/enums")
   (:file "media/visualization-data")
   (:file "media/song")
   (:file "media/media-queue")
   (:file "media/media-player")
   ;; --- Microsoft.Xna.Framework.Content ------------------------------------
   ;; The manager first, then the loaders that produce graphics objects, then
   ;; Game.Content, which needs both GAME and CONTENT-MANAGER to exist.
   (:file "content/content-manager")
   (:file "content/content-loaders")
   (:file "content/game-content")
   ;; --- Microsoft.Xna.Framework.Storage -------------------------------------
   ;; The one namespace that needs no game at all: no storage route takes one.
   ;; The enumerations and the condition first, then the stream -- which the
   ;; container's four file members answer -- then the container, then the device
   ;; that owns it. The ownership graph here is three deep, which is new:
   ;; StorageDevice -> StorageContainer -> StorageStream.
   (:file "storage/enums")
   (:file "storage/conditions")
   ;; Where the saves go: two CNA extensions with no XNA member behind them,
   ;; because off the Xbox nothing derives a title's directory for it.
   (:file "storage/storage-root")
   (:file "storage/storage-stream")
   (:file "storage/storage-container")
   (:file "storage/storage-device")
   ;; --- declared capabilities and deliberate absences ----------------------
   (:file "capabilities"))
  :in-order-to ((test-op (test-op "cna-common-lisp/tests"))))

(defsystem "cna-common-lisp/tests"
  :description "Maintained test suite for CNA-Lisp."
  :depends-on ("cna-common-lisp" "fiveam" "uiop")
  :serial t
  :pathname "tests"
  :components
  ((:file "suite")
   (:file "unit/utf8")
   (:file "unit/value-types")
   (:file "unit/math-helper")
   (:file "unit/vectors")
   (:file "unit/rotation")
   (:file "unit/bounding-volumes")
   (:file "unit/bounding-frustum")
   (:file "unit/color")
   (:file "unit/curve")
   (:file "unit/packed-vector")
   (:file "unit/mouse-state")
   (:file "unit/game-pad")
   (:file "unit/touch")
   (:file "unit/graphics-resource-hierarchy")
   (:file "unit/graphics-state")
   (:file "unit/vertex-types")
   (:file "unit/buffer-data")
   (:file "unit/viewport-projection")
   (:file "unit/game-time")
   (:file "unit/keys")
   (:file "unit/conditions")
   ;; The rollback machinery is correctness infrastructure and touches no CNA,
   ;; so it is tested here rather than only through a resource.
   (:file "unit/rollback")
   (:file "unit/exports")
   (:file "unit/sprite-font")
   (:file "structure/public-surface")
   (:file "structure/generated-files")
   (:file "behavior/corpus")
   (:file "native/support")
   (:file "native/abi-gate")
   (:file "native/struct-passing")
   (:file "native/game-lifecycle")
   (:file "native/events")
   (:file "native/graphics")
   (:file "native/graphics-state")
   (:file "native/vertex-types")
   (:file "native/buffers")
   (:file "native/effects")
   (:file "native/stock-effects")
   (:file "native/render-target")
   (:file "native/render-target-cube")
   (:file "native/graphics-adapter")
   (:file "native/game-components")
   (:file "native/game-window")
   ;; The text pixel proofs build on the SpriteFont fixture game.
   (:file "native/sprite-font")
   (:file "native/models")
   (:file "native/content")
   ;; The atomicity proofs need the content fixture's root and asset name.
   (:file "native/content-atomicity")
   ;; The SoundEffect closure: fixtures generated here, no sample audio stored.
   (:file "native/audio")
   ;; The Microphone closure. After native/audio because it reuses that file's
   ;; game fixture and its teardown; its own lanes need a capture device, and
   ;; both branches -- one enumerated and none enumerated -- assert.
   (:file "native/microphone")
   ;; The MediaPlayer playback closure, which reuses the same game fixture and
   ;; the same PCM16 file the SoundEffect tests generate. Both branches assert:
   ;; a song is created with no playback device and the refusal arrives at Play.
   (:file "native/media")
   ;; The first closure that needs no game: storage opens the ABI gate itself,
   ;; writes real files under a root the tests name, and deletes every container
   ;; it opens. Its two branches are forced rather than environmental.
   (:file "native/storage")
   ;; Texture2D's four Stream members, over ordinary Common Lisp streams.
   (:file "native/texture-streams")
   ;; TitleContainer resolves its base path through a live game.
   (:file "native/title-container")
   ;; A subclass initializer runs after every base one, including the one that
   ;; took the handle; this proves that costs nothing.
   (:file "native/construction-atomicity")
   ;; Game.Services and the two canonical registrations. After
   ;; construction-atomicity, whose EXPLODING-GRAPHICS-DEVICE-MANAGER the
   ;; ownership lane below reuses rather than defining a second one.
   ;; GraphicsDeviceInformation, the mutable PreparingDeviceSettings event and
   ;; the manager's protected virtual surface. After native/services, whose
   ;; MANAGED-GAME fixture and stand-in service provider it reuses.
   (:file "native/rasterization")
   (:file "native/graphics-resource")
   (:file "native/keyboard")
   (:file "native/mouse")
   (:file "native/game-pad")
   (:file "native/touch")
   (:file "native/ownership")
   (:file "native/stress")
   (:file "runner"))
  :perform (test-op (op c)
             (uiop:symbol-call :cna-common-lisp.tests '#:run-all-tests)))
