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
   (:file "internal/native-library")
   (:file "internal/abi-gate")
   (:file "internal/threads")
   (:file "internal/ownership")
   (:file "internal/callback-registry")
   ;; --- Microsoft.Xna.Framework -------------------------------------------
   (:file "framework/disposable")
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
   (:file "graphics/enums")
   (:file "graphics/viewport")
   (:file "graphics/graphics-device")
   (:file "graphics/texture-2d")
   (:file "graphics/sprite-batch")
   ;; --- Microsoft.Xna.Framework.Input -------------------------------------
   (:file "input/keys")
   (:file "input/keyboard-state")
   (:file "input/keyboard")
   ;; --- Game and the graphics device manager ------------------------------
   (:file "runtime/game")
   (:file "runtime/graphics-device-manager")
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
   (:file "unit/game-time")
   (:file "unit/keys")
   (:file "unit/conditions")
   (:file "structure/public-surface")
   (:file "structure/generated-files")
   (:file "behavior/corpus")
   (:file "native/support")
   (:file "native/abi-gate")
   (:file "native/struct-passing")
   (:file "native/game-lifecycle")
   (:file "native/graphics")
   (:file "native/keyboard")
   (:file "native/ownership")
   (:file "native/stress")
   (:file "runner"))
  :perform (test-op (op c)
             (uiop:symbol-call :cna-common-lisp.tests '#:run-all-tests)))
