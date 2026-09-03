;;;; ownership.lisp --- deterministic lifetimes for CNA native objects.
;;;;
;;;; Native destruction in CNA-Lisp is deterministic and explicit. No finalizer
;;;; ever destroys a CNA object: a finalizer runs on whichever thread the garbage
;;;; collector chooses, and every CNA handle is thread-affine, so a finalizer
;;;; that called CNA would be calling it from the wrong thread by construction.
;;;; See docs/ownership-and-lifetimes.md.
;;;;
;;;; Four kinds of native reference exist here:
;;;;
;;;;   :owned              this object holds the handle and must destroy it
;;;;   :borrowed           someone else owns the handle; never destroyed here
;;;;   :callback-scoped    borrowed *and* valid only inside a lifecycle callback
;;;;   :parent-owned       a facade with no handle of its own; resolves per call
;;;;
;;;; A generation counter on the owner invalidates children that outlive it, so a
;;;; stale object reports what it is rather than handing CNA a reused handle.

(in-package #:cna-lisp.internal)

(defvar *active-game* nil
  "The process's one active CNA game, or NIL.

CNA allows exactly one active game per process, which is what makes XNA's static
input classes projectable: `Keyboard.GetState()' takes no arguments there and
takes none here, because there is only ever one game it could mean.")

(defun active-game () *active-game*)
(defun (setf active-game) (game) (setf *active-game* game))

(defvar *generation-counter* 0)

(defun next-generation ()
  (incf *generation-counter*))

(defclass native-object ()
  ((handle :initarg :handle :initform 0 :accessor handle-of
           :documentation "The CNA handle, or 0 once this object no longer holds one.")
   (ownership :initarg :ownership :initform :owned :reader ownership-of
              :documentation "One of :OWNED :BORROWED :CALLBACK-SCOPED :PARENT-OWNED.")
   (owner :initarg :owner :initform nil :reader owner-of
          :documentation "The object that owns this one, or NIL for a root.")
   (owner-generation :initarg :owner-generation :initform nil :accessor owner-generation-of
                     :documentation "The owner's generation when this object was created.")
   (owner-thread :initarg :owner-thread :initform nil :reader owner-thread-of
                 :documentation "The thread that may operate on this object.")
   (generation :initform nil :accessor generation-of
               :documentation "This object's own generation, for children to record.")
   (children :initform '() :accessor children-of
             :documentation "Live owned children, newest first.")
   (disposed :initform nil :accessor disposed-state-of))
  (:documentation
   "Private base of every CNA-Lisp object with a native handle. None of its slots
is publicly readable: a consumer never sees a handle, an ownership token or a
generation."))

(defmethod initialize-instance :after ((object native-object) &key)
  (setf (generation-of object) (next-generation))
  (unless (owner-thread-of object)
    (setf (slot-value object 'owner-thread) (current-thread-token))))

;;; --- parent/child bookkeeping ------------------------------------------

(defun register-child (parent child)
  "Record CHILD as a live owned child of PARENT."
  (when parent
    (push child (children-of parent))
    (setf (owner-generation-of child) (generation-of parent)))
  child)

(defun unregister-child (parent child)
  (when parent
    (setf (children-of parent) (remove child (children-of parent) :test #'eq)))
  child)

;;; --- validity ----------------------------------------------------------

(defun stale-p (object)
  "True when OBJECT's owner has been disposed or reused since OBJECT was made."
  (let ((owner (owner-of object)))
    (and owner
         (or (disposed-state-of owner)
             (and (owner-generation-of object)
                  (/= (owner-generation-of object) (generation-of owner)))))))

(defun check-live (object operation)
  "Refuse OPERATION when OBJECT has been disposed or has gone stale."
  (when (disposed-state-of object)
    (error 'microsoft.xna.framework:cna-disposed-error
           :operation operation
           :object-type (type-of object)
           :format-control "~a was already disposed; ~a is not legal on it."
           :format-arguments (list (type-of object) operation)))
  (when (stale-p object)
    (error 'microsoft.xna.framework:cna-ownership-error
           :operation operation
           :object-type (type-of object)
           :format-control
           "~a outlived the ~a that owned it. Its native handle is not used: a handle from ~
            a destroyed owner may since have been reissued, and calling through it would ~
            reach an unrelated object."
           :format-arguments (list (type-of object) (type-of (owner-of object)))))
  t)

(defun check-usable (object operation)
  "Refuse OPERATION unless OBJECT is live, on its own thread, and holds a handle."
  (check-live object operation)
  (check-owner-thread (owner-thread-of object) operation :object-type (type-of object))
  (when (and (member (ownership-of object) '(:owned :borrowed))
             (zerop (handle-of object)))
    (error 'microsoft.xna.framework:cna-invalid-handle-error
           :operation operation
           :object-type (type-of object)
           :format-control "~a holds no native handle."
           :format-arguments (list (type-of object))))
  t)

(defun invalidate (object)
  "Mark OBJECT disposed and drop its handle, without calling CNA."
  (setf (disposed-state-of object) t
        (handle-of object) 0
        (generation-of object) (next-generation))
  (let ((owner (owner-of object)))
    (when owner (unregister-child owner object)))
  object)

(defgeneric destroy-native (object)
  (:documentation
   "Release OBJECT's native resource. Called by DISPOSE once the object has been
checked; specialised by each native-backed class. Must not be called directly."))
