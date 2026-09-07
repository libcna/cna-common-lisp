;;;; shim-policy.lisp --- the four shim-dependent setters, as one class.
;;;;
;;;; **The point of this file is that there are four of them and they behave
;;;; identically.** Each already has a test of its own where its type is tested;
;;;; what none of those could show is the thing the 2026-09-07 classification
;;;; correction turned on -- that `GraphicsDevice.Viewport' and `BasicEffect''s
;;;; three matrices are one class with no distinguishing feature, so no rule may
;;;; report them differently.
;;;;
;;;; Both branches are asserted, and which one runs is the environment's choice:
;;;; with `CNA_LISP_SHIM' all four succeed, without it all four refuse in exactly
;;;; the same shape and all four readers still work. A run cannot produce a
;;;; mixture -- that is the assertion, not an assumption -- and
;;;; `tools/qualification/shim-policy.sh' requires *both* branches to have been
;;;; observed, in two processes, because one image cannot answer for two
;;;; configurations.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defvar *shim-policy-evidence* '()
  "Which branch the four setters took, and what they did there.")

(defun note-shim-policy (level description &rest arguments)
  (unless (assoc level *shim-policy-evidence*)
    (push (cons level (apply #'format nil description arguments))
          *shim-policy-evidence*)))

(defclass shim-policy-game (graphics-game)
  ((outcomes :initform '() :accessor shim-outcomes)
   (readers  :initform '() :accessor shim-readers)
   (probe-error :initform nil :accessor probe-error))
  (:documentation
   "Exercises all four shim-dependent setters, and all four readers, in one
callback -- because the claim is about the four together."))

(defun %shim-attempt (label thunk)
  "Answer :OK, or the printed condition, for one setter."
  (handler-case (progn (funcall thunk) (cons label :ok))
    (xna:cna-not-supported-error (condition) (cons label (princ-to-string condition)))))

(defmethod xna:load-content ((game shim-policy-game))
  (call-next-method)
  (handler-case
      (let* ((device (xna:graphics-device game))
             (effect (make-instance 'gfx:basic-effect :graphics-device device))
             (matrix (xna:matrix-identity))
             (viewport (gfx:make-viewport 4 8 64 32 0.25 0.75)))
        (unwind-protect
             (progn
               (setf (shim-outcomes game)
                     (list (%shim-attempt "GraphicsDevice.Viewport"
                                          (lambda () (setf (gfx:viewport device) viewport)))
                           (%shim-attempt "BasicEffect.World"
                                          (lambda () (setf (gfx:effect-world effect) matrix)))
                           (%shim-attempt "BasicEffect.View"
                                          (lambda () (setf (gfx:effect-view effect) matrix)))
                           (%shim-attempt "BasicEffect.Projection"
                                          (lambda () (setf (gfx:effect-projection effect) matrix)))))
               ;; The readers, which the policy says work either way.
               (setf (shim-readers game)
                     (list (%shim-attempt "Viewport reader"
                                          (lambda () (gfx:viewport device)))
                           (%shim-attempt "World reader"
                                          (lambda () (gfx:effect-world effect)))
                           (%shim-attempt "View reader"
                                          (lambda () (gfx:effect-view effect)))
                           (%shim-attempt "Projection reader"
                                          (lambda () (gfx:effect-projection effect))))))
          (ignore-errors (xna:dispose effect))))
    (error (condition) (setf (probe-error game) condition))))

(define-native-test the-four-shim-dependent-setters-are-one-class
  "Four members, one blocker, one behaviour -- and the scoreboard says so.

`GraphicsDevice.Viewport`, `BasicEffect.World`, `.View` and `.Projection` all take
a by-value aggregate the System V AMD64 ABI classifies MEMORY, all four go
through the optional private shim, and **all four are reported `partial`**. They
were not always: until 2026-09-07 the three matrices were `complete` while
`Viewport` was `partial`, on the identical blocker. This test is what makes that
correction defensible -- it asserts the four are indistinguishable rather than
asserting it in prose.

A run takes one branch for all four. A mixture would mean the shim answered for
some routes and not others, which is a defect in the shim or the loader, and it
is asserted against rather than assumed away."
  (let ((game (make-instance 'shim-policy-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (is (null (probe-error game)) "the shim lane failed: ~a" (probe-error game))
           (let* ((outcomes (shim-outcomes game))
                  (readers (shim-readers game))
                  (satisfied (remove-if-not (lambda (o) (eq (cdr o) :ok)) outcomes))
                  (refused (remove-if (lambda (o) (eq (cdr o) :ok)) outcomes)))
             (is (= 4 (length outcomes)) "all four setters were attempted")
             (is (= 4 (length readers)) "all four readers were attempted")
             ;; The readers, in both branches.
             (is (every (lambda (r) (eq (cdr r) :ok)) readers)
                 "a reader failed; the readers take a pointer and need no shim: ~s"
                 readers)
             (cond
               ((= 4 (length satisfied))
                (is (int:shim-loaded-p)
                    "all four setters succeeded but the shim is not loaded")
                (note-shim-policy
                 :shim-present
                 "with CNA_LISP_SHIM loaded, all four setters succeeded and all ~
                  four readers worked"))
               ((= 4 (length refused))
                (is (not (int:shim-loaded-p))
                    "all four setters refused but the shim reports itself loaded")
                ;; The refusal is the same shape for each, and it is actionable.
                (dolist (entry refused)
                  (is (search "CNA_LISP_SHIM" (cdr entry))
                      "~a's refusal does not name the variable that supplies the shim"
                      (car entry))
                  (is (search "verify.sh" (cdr entry))
                      "~a's refusal does not say how to build the shim" (car entry))
                  (is (search "System V" (cdr entry))
                      "~a's refusal does not say why a shim is needed" (car entry)))
                (note-shim-policy
                 :shim-absent
                 "with no CNA_LISP_SHIM, all four setters refused with a ~
                  CNA-NOT-SUPPORTED-ERROR naming the variable, the command and ~
                  the reason, and all four readers still worked"))
               (t
                (fail "the four setters did not agree, which means the shim ~
                       answered for some routes and not others: ~s" outcomes)))))
      (progn
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (ignore-errors (xna:dispose game))))))
