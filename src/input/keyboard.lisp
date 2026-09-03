;;;; keyboard.lisp --- Microsoft.Xna.Framework.Input.Keyboard.
;;;;
;;;; Keyboard is a static class in XNA. Static classes are projected as package
;;;; functions named `<class>-<member>' -- KEYBOARD-GET-STATE here -- because a
;;;; bare GET-STATE would collide the moment Mouse and GamePad arrive in the same
;;;; namespace, and a binding that names two different members the same thing has
;;;; already lost. See docs/common-lisp-mapping.md.
;;;;
;;;; The original takes no game argument and neither does this: CNA allows one
;;;; active game per process, so there is exactly one game the static class could
;;;; mean, and CNA-Lisp resolves it rather than making a consumer pass it.

(in-package #:microsoft.xna.framework.input)

(defun %active-game-handle (operation)
  (let ((game (cna-lisp.internal:active-game)))
    (unless game
      (error 'microsoft.xna.framework:cna-invalid-state-error
             :operation operation
             :format-control
             "~a needs a live game: CNA reads the keyboard through the active game, and ~
              there is none. Create a game before reading input."
             :format-arguments (list operation)))
    (cna-lisp.internal:check-usable game operation)
    (cna-lisp.internal:handle-of game)))

(defun keyboard-get-state (&optional player-index)
  "Keyboard.GetState() and Keyboard.GetState(PlayerIndex).

Answers a fresh KEYBOARD-STATE snapshot. PLAYER-INDEX is a
MICROSOFT.XNA.FRAMEWORK:PLAYER-INDEX member; CNA has one keyboard, so every slot
reports the same snapshot, exactly as the C ABI documents."
  (let ((handle (%active-game-handle "keyboard-get-state")))
    (cffi:with-foreign-object (state '(:struct cna-lisp.internal.ffi::cna-keyboard-state))
      (cffi:foreign-funcall "memset" :pointer state :int 0
                            :size cna-lisp.internal.ffi::+sizeof-cna-keyboard-state+ :void)
      (macrolet ((slot (name)
                   `(cffi:foreign-slot-value
                     state '(:struct cna-lisp.internal.ffi::cna-keyboard-state) ',name)))
        (setf (slot cna-lisp.internal.ffi::struct-size)
              cna-lisp.internal.ffi::+sizeof-cna-keyboard-state+
              (slot cna-lisp.internal.ffi::struct-version) 1))
      (cna-lisp.internal:check-result
       (if player-index
           (cna-lisp.internal.ffi::%keyboard-get-state-for-player
            handle (microsoft.xna.framework:player-index-value player-index) state)
           (cna-lisp.internal.ffi::%keyboard-get-state handle state))
       "keyboard-get-state")
      (let ((words (make-array 4 :element-type '(unsigned-byte 64))))
        (let ((base (cffi:foreign-slot-pointer
                     state '(:struct cna-lisp.internal.ffi::cna-keyboard-state)
                     'cna-lisp.internal.ffi::pressed-key-words)))
          (dotimes (i 4) (setf (aref words i) (cffi:mem-aref base :uint64 i))))
        (%make-keyboard-state words)))))
