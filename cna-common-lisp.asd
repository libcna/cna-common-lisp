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
  :depends-on ("cffi" "babel" "bordeaux-threads" "uiop")
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
   ;; --- private runtime ---------------------------------------------------
   (:file "internal/float-semantics")
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
   ;; --- Game and the graphics device manager ------------------------------
   (:file "runtime/game")
   (:file "runtime/game-events")
   (:file "runtime/graphics-device-manager")
   ;; GameWindow is a facade over the game and uses the event machinery, so it
   ;; loads after GAME and before anything that reaches a window.
   (:file "runtime/game-window")
   (:file "runtime/manager-events")
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
   ;; --- Microsoft.Xna.Framework.Content ------------------------------------
   ;; The manager first, then the loaders that produce graphics objects, then
   ;; Game.Content, which needs both GAME and CONTENT-MANAGER to exist.
   (:file "content/content-manager")
   (:file "content/content-loaders")
   (:file "content/game-content")
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
   (:file "native/content")
   ;; The atomicity proofs need the content fixture's root and asset name.
   (:file "native/content-atomicity")
   ;; Texture2D's four Stream members, over ordinary Common Lisp streams.
   (:file "native/texture-streams")
   ;; TitleContainer resolves its base path through a live game.
   (:file "native/title-container")
   ;; A subclass initializer runs after every base one, including the one that
   ;; took the handle; this proves that costs nothing.
   (:file "native/construction-atomicity")
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
