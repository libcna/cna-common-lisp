;;;; content-atomicity.lisp --- one asset load is one transaction, proved.
;;;;
;;;; `tests/native/content.lisp' proves that a load that fails *before any handle
;;;; exists* -- a missing asset -- leaves the game owning nothing. That is the easy
;;;; half. This file is the hard half: a load whose native handles were acquired
;;;; and whose *later* steps fail.
;;;;
;;;; The shape being defended against is nested ledgers. Before this, a loader
;;;; recorded a handle's destruction in its own rollback and then called an
;;;; adoption helper that opened a second rollback and recorded the same handle
;;;; again. Two consequences, and the second is the dangerous one:
;;;;
;;;;   * the handle was destroyed twice, the inner ledger first and the outer one
;;;;     afterwards, on a handle CNA had already taken back;
;;;;   * for a SpriteFont, the atlas was adopted by an inner ledger that then
;;;;     *committed*. A failure in the font's own metadata therefore destroyed the
;;;;     atlas handle from the outer ledger while the atlas object stayed
;;;;     registered as a live child of the game -- a CLOS object that looked alive
;;;;     over a handle that was gone. The symptom was not here: it was the game
;;;;     refusing to shut down, a whole callback later.
;;;;
;;;; **How a destroy is counted.** The rollback thunks call the generated FFI
;;;; routes by name, and those are ordinary functions with no compiler macro and
;;;; no inline declaration, so binding their FDEFINITION around a load intercepts
;;;; every call the library makes. That is what turns "destroyed exactly once"
;;;; from an inference into a measurement.
;;;;
;;;; **How a step is made to fail.** `%read-texture-storage', `%sprite-font-info'
;;;; and `%read-font-glyph-table' are generic functions, and each says in its own
;;;; documentation that being one is what lets a test make that step fail. The
;;;; `:around' methods here are unspecialised and do nothing at all unless
;;;; *EXPLODING-STEP* names them, so they are inert for every other test in the
;;;; suite.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

;;; --- the two instruments ----------------------------------------------------

(define-condition content-step-blew-up (error)
  ((step :initarg :step :reader blown-step))
  (:report (lambda (condition stream)
             (format stream "deliberate failure in ~a" (blown-step condition)))))

(defvar *exploding-step* nil
  "The load step that must signal, or NIL. Bound around one LOAD-ASSET call.")

(defparameter *destroy-routes*
  '(ffi::%texture-2d-destroy ffi::%sprite-font-destroy ffi::%texturecube-destroy)
  "The destroy routes a content rollback can call.")

(defun call-with-destroy-log (function)
  "Call FUNCTION with a thunk answering every destroy made while it ran.

Each entry is (ROUTE . HANDLE), oldest first. The routes are rebound rather than
counted from the outside because the question is not how many textures went away:
it is whether *one* handle was handed back to CNA more than once, which only the
call itself can answer."
  (let ((log '())
        (originals (mapcar #'fdefinition *destroy-routes*)))
    (unwind-protect
         (progn
           (loop for route in *destroy-routes*
                 for original in originals
                 do (let ((route route) (original original))
                      (setf (fdefinition route)
                            (lambda (handle)
                              (push (cons route handle) log)
                              (funcall original handle)))))
           (funcall function (lambda () (reverse log))))
      (loop for route in *destroy-routes*
            for original in originals
            do (setf (fdefinition route) original)))))

(defun destroys-of (log route)
  (remove route log :key #'car :test-not #'eq))

(defun destroyed-exactly-once-p (log route)
  "True when ROUTE was called once, on one non-zero handle."
  (let ((entries (destroys-of log route)))
    (and (= 1 (length entries))
         (plusp (cdr (first entries))))))

;;; --- the fixture ------------------------------------------------------------

(defclass atomic-load-game (graphics-game)
  ((step-to-blow :initarg :step-to-blow :initform nil :reader step-to-blow)
   (asset-type :initarg :asset-type :initform 'gfx:sprite-font :reader asset-type)
   (asset-name :initarg :asset-name :initform *font-asset* :reader asset-name)
   (result :initform nil :accessor load-result)
   (condition-seen :initform nil :accessor condition-seen)
   (destroy-log :initform nil :accessor destroy-log)
   (children-before :initform nil :accessor children-before)
   (children-during :initform nil :accessor children-during)
   (children-after :initform nil :accessor children-after)
   (textures-before :initform nil :accessor textures-before)
   (textures-during :initform nil :accessor textures-during)
   (textures-after :initform nil :accessor textures-after)
   (registry-before :initform nil :accessor registry-before)
   (registry-after :initform nil :accessor registry-after)
   (info-succeeded :initform nil :accessor info-succeeded))
  (:documentation
   "Loads one asset with one step of the load rigged to fail, and records what
the game owned before, during and after. Nothing is asserted in here: this all
runs inside a native callback."))

(defun %live-texture-children (game)
  (count-if (lambda (child)
              (and (typep child 'gfx:texture-2d)
                   (not (xna:disposed-p child))))
            (int:children-of game)))

(defmethod xna:load-content ((game atomic-load-game))
  (call-next-method)
  (let ((content (xna:content game)))
    (setf (xna.content:root-directory content) (%content-root))
    (setf (children-before game) (length (int:children-of game))
          (textures-before game) (%live-texture-children game)
          (registry-before game) (int:callback-registry-count))
    (call-with-destroy-log
     (lambda (log)
       (handler-case
           (let ((*exploding-step* (step-to-blow game)))
             (setf (load-result game)
                   (multiple-value-list
                    (xna.content:load-asset content (asset-type game) (asset-name game)))))
         (content-step-blew-up (condition) (setf (condition-seen game) condition))
         (error (condition) (setf (condition-seen game) condition)))
       (setf (destroy-log game) (funcall log))))
    (setf (children-after game) (length (int:children-of game))
          (textures-after game) (%live-texture-children game)
          (registry-after game) (int:callback-registry-count))))

;;; --- the three steps a load can be made to fail at ---------------------------
;;;
;;; Defined after the fixture, because each one both observes it and fails it.

(defmethod gfx::%read-texture-storage :around ((texture gfx:texture-2d))
  (if (eq *exploding-step* :texture-storage)
      (error 'content-step-blew-up :step :texture-storage)
      (call-next-method)))

(defmethod gfx::%sprite-font-info :around (handle operation)
  "Observe that the atlas was already adopted, then fail if this is the step.

Both halves are here because CLOS allows one `:around' method per signature, and
the observation is the premise the assertions rest on: without it, a test that
failed *before* the atlas was adopted would pass for the wrong reason."
  (declare (ignore handle operation))
  (let ((game (int:active-game)))
    (when (typep game 'atomic-load-game)
      (setf (textures-during game) (%live-texture-children game)
            (children-during game) (length (int:children-of game)))))
  (if (eq *exploding-step* :font-info)
      (error 'content-step-blew-up :step :font-info)
      (call-next-method)))

(defmethod xna.content::%commit-loaded-asset :around
    ((manager xna.content:content-manager) asset-name record &rest values)
  "The last step of a load: cache the asset, and fail here if asked to.

This is the commit itself, so a failure in it is the one case where *everything*
had already worked -- the handles are CNA's, the objects are built, the game owns
them -- and the load still has to come apart. Nothing else in the suite reaches
that state."
  (declare (ignore asset-name record values))
  (if (eq *exploding-step* :cache-insertion)
      (error 'content-step-blew-up :step :cache-insertion)
      (call-next-method)))

(defmethod gfx::%read-font-glyph-table :around (handle count operation)
  "Record that the font's info step had already succeeded, then fail if asked."
  (declare (ignore handle count operation))
  (let ((game (int:active-game)))
    (when (typep game 'atomic-load-game)
      (setf (info-succeeded game) t)))
  (if (eq *exploding-step* :glyph-table)
      (error 'content-step-blew-up :step :glyph-table)
      (call-next-method)))

(defmacro with-atomic-load-game ((variable &rest initargs) &body body)
  "Run an ATOMIC-LOAD-GAME and then assert, with the game disposed at the end.

The teardown is half the evidence. CNA refuses to destroy a game while any child
handle is alive, so a load that leaked one fails the DISPOSE below -- which is
how this class of bug announced itself before it was understood."
  `(let ((,variable (make-instance 'atomic-load-game :exit-after 2 ,@initargs))
         (teardown-error nil))
     (unwind-protect
          (progn (xna:run ,variable) ,@body)
       (progn
         (when (batch ,variable) (ignore-errors (xna:dispose (batch ,variable))))
         (when (texture ,variable) (ignore-errors (xna:dispose (texture ,variable))))
         (when (manager ,variable) (ignore-errors (xna:dispose (manager ,variable))))
         (handler-case (xna:dispose ,variable)
           (error (condition) (setf teardown-error condition)))
         (is (null teardown-error)
             "the game would not shut down after the failed load: ~a" teardown-error)))))

;;; --- A. Texture2D: the metadata query fails after the handle exists ---------

(define-native-test a-failed-texture-load-hands-its-handle-back-exactly-once
  "Load<Texture2D> whose storage-info query fails after the decode succeeded.

The window is the one nested ledgers got wrong: the loader owns the handle and
the adoption helper reads the metadata, so a failure in the read is a failure
with a live handle in hand and a caller who never received an object."
  (with-atomic-load-game (game :asset-type 'gfx:texture-2d
                               :asset-name "cna-lisp-mark.png"
                               :step-to-blow :texture-storage)
    (let ((log (destroy-log game)))
      (is (typep (condition-seen game) 'content-step-blew-up)
          "the caller saw ~a rather than the condition that caused the rollback"
          (type-of (condition-seen game)))
      (is (eq :texture-storage (blown-step (condition-seen game))))
      (is (null (load-result game)) "a failed load answered ~a" (load-result game))
      (is (destroyed-exactly-once-p log 'ffi::%texture-2d-destroy)
          "the texture handle was destroyed ~d time(s), not once"
          (length (destroys-of log 'ffi::%texture-2d-destroy)))
      (is (= (children-before game) (children-after game))
          "a failed load changed the game's children from ~d to ~d"
          (children-before game) (children-after game))
      (is (= (textures-before game) (textures-after game))
          "a failed load left ~d live texture object(s) behind"
          (- (textures-after game) (textures-before game)))
      (is (= (registry-before game) (registry-after game))
          "a failed load changed the callback registry by ~d"
          (- (registry-after game) (registry-before game))))))

;;; --- B. SpriteFont: the font's info fails after the atlas was adopted -------

(define-native-test a-font-that-fails-after-its-atlas-was-adopted-strands-nothing
  "Load<SpriteFont> whose `cna_sprite_font_get_info' fails.

By then CNA has handed back **both** handles and the atlas is a fully adopted,
registered child of the game -- the exact point at which the old nested ledger
had already committed. What must happen is that the one transaction undoes the
atlas as well: the atlas object is abandoned, and both handles go back, font
first, each exactly once."
  (with-atomic-load-game (game :asset-type 'gfx:sprite-font
                               :step-to-blow :font-info)
    (let ((log (destroy-log game)))
      (is (typep (condition-seen game) 'content-step-blew-up)
          "the caller saw ~a" (type-of (condition-seen game)))
      (is (eq :font-info (blown-step (condition-seen game))))
      ;; The premise: the atlas really was adopted before the failure.
      (is (= (1+ (textures-before game)) (textures-during game))
          "the atlas was not adopted before the failing step; this test proves ~
           nothing unless it was (~d -> ~d live textures)"
          (textures-before game) (textures-during game))
      (is (destroyed-exactly-once-p log 'ffi::%sprite-font-destroy)
          "the font handle was destroyed ~d time(s), not once"
          (length (destroys-of log 'ffi::%sprite-font-destroy)))
      (is (destroyed-exactly-once-p log 'ffi::%texture-2d-destroy)
          "the atlas handle was destroyed ~d time(s), not once"
          (length (destroys-of log 'ffi::%texture-2d-destroy)))
      ;; CNA refuses to destroy the atlas while the font lives, so the order is
      ;; part of the contract and not an implementation detail.
      (is (eq 'ffi::%sprite-font-destroy (car (first log)))
          "the rollback destroyed ~a before the font" (car (first log)))
      (is (eq 'ffi::%texture-2d-destroy (car (second log)))
          "the rollback destroyed ~a second" (car (second log)))
      ;; And the zombie the old shape left behind.
      (is (= (textures-before game) (textures-after game))
          "the adopted atlas was left registered as a live child of the game")
      (is (= (children-before game) (children-after game))
          "a failed font load changed the game's children from ~d to ~d"
          (children-before game) (children-after game))
      (is (= (registry-before game) (registry-after game))
          "a failed font load changed the callback registry by ~d"
          (- (registry-after game) (registry-before game))))))

;;; --- C. SpriteFont: the glyph table fails, later still ----------------------

(define-native-test a-font-that-fails-in-its-glyph-table-strands-nothing
  "The same atomicity one step later, with a native call in between.

`cna_sprite_font_get_info' has now succeeded, so this is not the first thing to
run after the atlas: an intermediate native step committed and the transaction
still has to undo everything."
  (with-atomic-load-game (game :asset-type 'gfx:sprite-font
                               :step-to-blow :glyph-table)
    (let ((log (destroy-log game)))
      (is (typep (condition-seen game) 'content-step-blew-up)
          "the caller saw ~a" (type-of (condition-seen game)))
      (is (eq :glyph-table (blown-step (condition-seen game))))
      (is-true (info-succeeded game)
               "the font's info step did not run, so nothing intermediate succeeded")
      (is (= (1+ (textures-before game)) (textures-during game))
          "the atlas was not adopted before the failing step")
      (is (destroyed-exactly-once-p log 'ffi::%sprite-font-destroy)
          "the font handle was destroyed ~d time(s), not once"
          (length (destroys-of log 'ffi::%sprite-font-destroy)))
      (is (destroyed-exactly-once-p log 'ffi::%texture-2d-destroy)
          "the atlas handle was destroyed ~d time(s), not once"
          (length (destroys-of log 'ffi::%texture-2d-destroy)))
      (is (eq 'ffi::%sprite-font-destroy (car (first log))))
      (is (= (textures-before game) (textures-after game))
          "the adopted atlas was left registered as a live child of the game")
      (is (= (children-before game) (children-after game)))
      (is (= (registry-before game) (registry-after game))))))

;;; --- and the happy path is unaffected ---------------------------------------

(define-native-test a-load-whose-caching-fails-keeps-none-of-it
  "The last step, and the one where everything else had already worked.

By the time the asset reaches the cache CNA has handed back both handles, the
metadata is read, the objects are built and the game owns them. A failure here is
therefore the strongest test of the transaction there is: nothing is left to go
right, and all of it has to come apart. Reaching this state at all is what the
commit step being inside the load's ledger buys."
  (with-atomic-load-game (game :asset-type 'gfx:sprite-font
                               :step-to-blow :cache-insertion)
    (let ((log (destroy-log game))
          (content (xna:content game)))
      (is (typep (condition-seen game) 'content-step-blew-up)
          "the caller saw ~a" (type-of (condition-seen game)))
      (is (eq :cache-insertion (blown-step (condition-seen game))))
      (is (destroyed-exactly-once-p log 'ffi::%sprite-font-destroy)
          "the font handle was destroyed ~d time(s), not once"
          (length (destroys-of log 'ffi::%sprite-font-destroy)))
      (is (destroyed-exactly-once-p log 'ffi::%texture-2d-destroy)
          "the atlas handle was destroyed ~d time(s), not once"
          (length (destroys-of log 'ffi::%texture-2d-destroy)))
      (is (eq 'ffi::%sprite-font-destroy (car (first log)))
          "the rollback destroyed ~a before the font" (car (first log)))
      (is (= (textures-before game) (textures-after game))
          "the adopted atlas was left registered as a live child of the game")
      (is (= (children-before game) (children-after game)))
      ;; and the manager kept nothing: no cache entry, and nothing on the
      ;; disposal list that Unload would later try to dispose twice.
      (is (zerop (hash-table-count (xna.content::%content-loaded-assets content)))
          "a failed load left ~d cache entry/entries behind"
          (hash-table-count (xna.content::%content-loaded-assets content)))
      (is (null (xna.content::%content-disposable-assets content))
          "a failed load left ~d asset(s) on the manager's disposal list"
          (length (xna.content::%content-disposable-assets content))))))

(define-native-test a-successful-load-destroys-nothing-and-registers-both
  "The control. With no step rigged, the same fixture loads and keeps everything.

Without this, every assertion above would still pass if LOAD-ASSET had simply
stopped working."
  (with-atomic-load-game (game :asset-type 'gfx:sprite-font :step-to-blow nil)
    (is (null (condition-seen game)) "the control load failed: ~a" (condition-seen game))
    (is (= 2 (length (load-result game)))
        "Load<SpriteFont> answered ~d value(s)" (length (load-result game)))
    (is (typep (first (load-result game)) 'gfx:sprite-font))
    (is (typep (second (load-result game)) 'gfx:texture-2d))
    (is (null (destroy-log game))
        "a successful load destroyed ~a" (destroy-log game))
    (is (= (1+ (textures-before game)) (textures-after game))
        "the atlas was not registered as a child of the game")
    ;; ...and the manager kept both, in the order Unload has to dispose them.
    (let ((content (xna:content game)))
      (is (= 1 (hash-table-count (xna.content::%content-loaded-assets content)))
          "a successful load left ~d cache entry/entries"
          (hash-table-count (xna.content::%content-loaded-assets content)))
      (is (equal (list (first (load-result game)) (second (load-result game)))
                 (xna.content::%content-disposable-assets content))
          "the disposal list must read font-first, and reads ~a"
          (xna.content::%content-disposable-assets content)))
    ;; and the caller's objects are disposed here rather than in the teardown,
    ;; font first, because CNA refuses the other order.
    (xna:dispose (first (load-result game)))
    (xna:dispose (second (load-result game)))))
