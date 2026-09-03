;;;; mouse.lisp --- Microsoft.Xna.Framework.Input.Mouse and MouseState.
;;;;
;;;; The second static input class, and the first place the naming rule that
;;;; KEYBOARD-GET-STATE follows actually earns its keep: MOUSE-GET-STATE and
;;;; KEYBOARD-GET-STATE live in one package and would both have been GET-STATE.
;;;;
;;;; MouseState is a value type in XNA -- five button states, a position and a
;;;; cumulative wheel value -- and it is a value here too: a snapshot has no
;;;; handle and no lifetime, and may be copied, stored and compared long after
;;;; the frame it came from. It is held as the same button bit set CNA's C ABI
;;;; uses, with the five readers derived, so that equality is exact and no
;;;; ordering of five separate slots can drift from the bits.

(in-package #:microsoft.xna.framework.input)

(microsoft.xna.framework::define-xna-enum button-state
  '((:released . 0) (:pressed . 1))
  :documentation "Microsoft.Xna.Framework.Input.ButtonState.")

(defstruct (mouse-state (:constructor %make-mouse-state (x y scroll-wheel buttons))
                        (:copier copy-mouse-state))
  "Microsoft.Xna.Framework.Input.MouseState: where the mouse was at one instant."
  (x 0 :type (signed-byte 32))
  (y 0 :type (signed-byte 32))
  (scroll-wheel 0 :type (signed-byte 32))
  (buttons 0 :type (unsigned-byte 32)))

(defun make-mouse-state (&key (x 0) (y 0) (scroll-wheel 0)
                              (left-button :released) (middle-button :released)
                              (right-button :released)
                              (x-button-1 :released) (x-button-2 :released))
  "MouseState(int, int, int, ButtonState x 5).

The original takes eight positional arguments, five of which are the same type
and tell each other apart only by position. Keywords here, because
`(make-mouse-state 0 0 0 :released :pressed :released :released :released)' is a
line nobody can read and one nobody can review."
  (flet ((bit-of (state mask)
           (check-type state button-state)
           (if (eq state :pressed) mask 0)))
    (%make-mouse-state
     x y scroll-wheel
     (logior (bit-of left-button cna-lisp.internal.ffi:+mouse-button-left+)
             (bit-of middle-button cna-lisp.internal.ffi:+mouse-button-middle+)
             (bit-of right-button cna-lisp.internal.ffi:+mouse-button-right+)
             (bit-of x-button-1 cna-lisp.internal.ffi:+mouse-button-x1+)
             (bit-of x-button-2 cna-lisp.internal.ffi:+mouse-button-x2+)))))

(macrolet ((button-reader (name mask documentation)
             `(defun ,name (state)
                ,documentation
                (if (logtest (mouse-state-buttons state) ,mask) :pressed :released))))
  (button-reader mouse-state-left-button cna-lisp.internal.ffi:+mouse-button-left+
                 "MouseState.LeftButton.")
  (button-reader mouse-state-middle-button cna-lisp.internal.ffi:+mouse-button-middle+
                 "MouseState.MiddleButton.")
  (button-reader mouse-state-right-button cna-lisp.internal.ffi:+mouse-button-right+
                 "MouseState.RightButton.")
  (button-reader mouse-state-x-button-1 cna-lisp.internal.ffi:+mouse-button-x1+
                 "MouseState.XButton1.")
  (button-reader mouse-state-x-button-2 cna-lisp.internal.ffi:+mouse-button-x2+
                 "MouseState.XButton2."))

(defun mouse-state-scroll-wheel-value (state)
  "MouseState.ScrollWheelValue: cumulative, in XNA's 120-unit notches, and not
reset between frames -- a caller compares two snapshots rather than reading one."
  (mouse-state-scroll-wheel state))

(defun mouse-state-equal (left right)
  "MouseState.Equals and op_Equality."
  (and (= (mouse-state-x left) (mouse-state-x right))
       (= (mouse-state-y left) (mouse-state-y right))
       (= (mouse-state-scroll-wheel left) (mouse-state-scroll-wheel right))
       (= (mouse-state-buttons left) (mouse-state-buttons right))))

(defun mouse-get-state ()
  "Mouse.GetState.

Answers a fresh MOUSE-STATE snapshot. Like KEYBOARD-GET-STATE it takes no game
argument: CNA allows one active game per process, and CNA-Lisp resolves it."
  (let ((handle (%active-game-handle "mouse-get-state")))
    (cffi:with-foreign-object (state '(:struct cna-lisp.internal.ffi::cna-mouse-state))
      (cffi:foreign-funcall "memset" :pointer state :int 0
                            :size cna-lisp.internal.ffi::+sizeof-cna-mouse-state+ :void)
      (macrolet ((slot (name)
                   `(cffi:foreign-slot-value
                     state '(:struct cna-lisp.internal.ffi::cna-mouse-state) ',name)))
        (setf (slot cna-lisp.internal.ffi::struct-size)
              cna-lisp.internal.ffi::+sizeof-cna-mouse-state+
              (slot cna-lisp.internal.ffi::struct-version) 1)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%mouse-get-state handle state)
         "mouse-get-state")
        (%make-mouse-state (slot cna-lisp.internal.ffi::x)
                           (slot cna-lisp.internal.ffi::y)
                           (slot cna-lisp.internal.ffi::scroll-wheel)
                           (slot cna-lisp.internal.ffi::pressed-buttons))))))

(defun mouse-set-position (x y)
  "Mouse.SetPosition: move the cursor, in the window's logical coordinates."
  (check-type x integer)
  (check-type y integer)
  (let ((handle (%active-game-handle "mouse-set-position")))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%mouse-set-position handle x y)
     "mouse-set-position"))
  (values))
