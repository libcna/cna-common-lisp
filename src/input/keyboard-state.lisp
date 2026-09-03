;;;; keyboard-state.lisp --- Microsoft.Xna.Framework.Input.KeyboardState.
;;;;
;;;; KeyboardState is a value type: a 256-slot bit set of which keys are down.
;;;; CNA-Lisp holds the same four 64-bit words CNA does, so a snapshot is a plain
;;;; Lisp value with no handle and no lifetime -- it may be copied, stored, and
;;;; compared long after the frame it came from.

(in-package #:microsoft.xna.framework.input)

(defstruct (keyboard-state (:constructor %make-keyboard-state (words))
                           (:copier %copy-keyboard-state))
  "Microsoft.Xna.Framework.Input.KeyboardState: which keys were down at one
instant."
  (words (make-array 4 :element-type '(unsigned-byte 64) :initial-element 0)
   :type (simple-array (unsigned-byte 64) (4))))

(defun make-keyboard-state (&optional pressed-keys)
  "KeyboardState(Keys[]): a snapshot in which exactly PRESSED-KEYS are down.

A duplicate key contributes once, exactly as the original's set-taking
constructors behave. A key outside the 256-slot range is refused rather than
silently dropped -- the deviation CNA's C ABI already documents, kept here so a
caller can never lose a key without being told."
  (let ((words (make-array 4 :element-type '(unsigned-byte 64) :initial-element 0)))
    (dolist (key pressed-keys)
      (let ((value (keys-value key)))
        (unless (< -1 value 256)
          (error 'microsoft.xna.framework:cna-usage-error
                 :operation "make-keyboard-state"
                 :format-control "~s has value ~d, outside the 256-slot key range."
                 :format-arguments (list key value)))
        (setf (ldb (byte 1 (mod value 64)) (aref words (floor value 64))) 1)))
    (%make-keyboard-state words)))

(defun copy-keyboard-state (state)
  "A copy of STATE. Value semantics: the copy shares nothing with the original."
  (%make-keyboard-state (copy-seq (keyboard-state-words state))))

(defun get-key-state (state key)
  "KeyboardState's indexer: :DOWN or :UP for KEY."
  (let ((value (keys-value key)))
    (if (and (< -1 value 256)
             (logbitp (mod value 64) (aref (keyboard-state-words state) (floor value 64))))
        :down
        :up)))

(defun is-key-down (state key)
  "KeyboardState.IsKeyDown(Keys)."
  (eq (get-key-state state key) :down))

(defun is-key-up (state key)
  "KeyboardState.IsKeyUp(Keys)."
  (eq (get-key-state state key) :up))

(defun get-pressed-keys (state)
  "KeyboardState.GetPressedKeys(), in ascending key value order."
  (let ((result '()))
    (dolist (row *keys-table* (nreverse result))
      (let ((value (cdr row)))
        (when (and (< -1 value 256)
                   (logbitp (mod value 64) (aref (keyboard-state-words state) (floor value 64))))
          (push (car row) result))))))

(defun keyboard-state-equal (left right)
  "KeyboardState.Equals."
  (equalp (keyboard-state-words left) (keyboard-state-words right)))
