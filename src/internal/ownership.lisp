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
   (construction-undo
    :initform '() :accessor construction-undo-of
    :documentation "Undo thunks for a construction still in progress, newest
first. Emptied when the construction commits; see INITIALIZE-INSTANCE :around.")
   (constructing
    :initform nil :accessor constructing-p
    :documentation "True while this object's MAKE-INSTANCE has not yet returned.

**A step that is undoable during construction and permanent afterwards needs to
know which it is.** Subscribing to an event is the case: during a construction it
belongs in the ledger, so a later initializer's failure gives the registration
back; after one it is an ordinary thing a program did and must not be undone by
anybody. A non-empty ledger is *nearly* the same test and is not the same test,
so the flag is explicit rather than inferred.")
   (disposed :initform nil :accessor disposed-state-of))
  (:documentation
   "Private base of every CNA-Lisp object with a native handle. None of its slots
is publicly readable: a consumer never sees a handle, an ownership token or a
generation."))

(defmethod initialize-instance :after ((object native-object) &key)
  (setf (generation-of object) (next-generation))
  (unless (owner-thread-of object)
    (setf (slot-value object 'owner-thread) (current-thread-token))))

;;; --- construction is all-or-nothing, a subclass's share included -------------
;;;
;;; A native-backed class acquires its handle in an `initialize-instance :after'
;;; method. CLOS runs `:after' methods least-specific-first, so **a subclass's
;;; own `:after' runs last -- after the handle exists and after the object has
;;; been registered as a child of its owner.** A subclass initializer that
;;; signals therefore used to leave CNA holding a resource the caller never
;;; received, with nothing left that could dispose it. The symptom is never at
;;; the constructor: it is the game refusing to shut down, later, because a child
;;; handle is still alive.
;;;
;;; Every exported class here can be subclassed -- CLOS has no `sealed' -- so
;;; this is one `:around' on the private base rather than one per class. It is
;;; the innermost `:around', because NATIVE-OBJECT is the least specific class,
;;; which is exactly what is wanted: `call-next-method' from here runs every
;;; `:before', primary and `:after' method there is, a subclass's included.

(defun record-construction-undo (object thunk)
  "Record THUNK as the undo for the construction step OBJECT has just completed.

Answers THUNK. Steps are undone newest-first, which is leaf-first: a handle taken
later is the child of one taken earlier, and a registration made later has to be
withdrawn before the handle it registered goes back."
  (push thunk (construction-undo-of object))
  thunk)

(defmethod initialize-instance :around ((object native-object) &key)
  "Undo what a construction recorded when the construction does not finish.

The undo is quiet: this runs on the way out of a failure, and a condition raised
here would replace the one that caused it. A committed construction drops its
ledger rather than keeping it, so nothing recorded can be run twice or reached
after MAKE-INSTANCE has answered."
  (let ((committed nil))
    (setf (constructing-p object) t)
    (unwind-protect
         (multiple-value-prog1 (call-next-method)
           (setf committed t))
      (setf (constructing-p object) nil)
      (if committed
          (setf (construction-undo-of object) '())
          (dolist (thunk (construction-undo-of object))
            (ignore-errors (funcall thunk)))))))

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
    (error 'microsoft.xna.framework:cna-invalid-object-error
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

;;; --- transactional construction, and transient handles ----------------------
;;;
;;; Two shapes, and they want opposite things from a failing cleanup.
;;;
;;; **Construction is all-or-nothing.** A native handle acquired part-way through
;;; building an object must go back if the rest of the building fails, or the
;;; game is left owning something the caller never received -- which shows up much
;;; later as a game that will not shut down, nowhere near the constructor that
;;; leaked it. The undo runs *quietly*: the condition that caused the rollback is
;;; the one worth reporting, and a second failure on the way out would mask it.
;;;
;;; **A transient handle is the other way round.** If the work succeeded and CNA
;;; then refuses to take the handle back, that refusal is news and nothing else
;;; will report it. Swallowing it because the handle was only meant to be
;;; short-lived is how a leak becomes invisible.

(defun call-with-native-rollback (function)
  "Call FUNCTION with a recorder, and undo what it recorded if it does not finish.

FUNCTION receives one argument: a function of a thunk, which records that thunk
as the undo for the step just completed and answers it. Steps are undone
newest-first, which is leaf-first, because a handle acquired later is always the
child of one acquired earlier.

The undo is quiet on purpose. This runs on the way out of a failure, and a
condition raised here would replace the one that caused it."
  (let ((undo '())
        (committed nil))
    (flet ((record (thunk) (push thunk undo) thunk))
      (unwind-protect
           (multiple-value-prog1 (funcall function #'record)
             (setf committed t))
        (unless committed
          (dolist (thunk undo)
            (ignore-errors (funcall thunk))))))))

(defmacro with-native-rollback ((record) &body body)
  "Run BODY transactionally, undoing recorded steps if it does not finish.

    (with-native-rollback (record)
      (let ((handle (create ...)))
        (funcall record (lambda () (destroy handle)))
        ...))

See CALL-WITH-NATIVE-ROLLBACK."
  `(call-with-native-rollback (lambda (,record) (declare (ignorable ,record)) ,@body)))

(defun call-with-transient-native (body release operation &key object-type)
  "Run BODY and then give a transient native handle back, exactly once.

If BODY completed, a failing RELEASE is **reported**: the work is done and
nothing else will say that CNA still holds a handle. If BODY signalled, RELEASE
runs quietly and the original condition is what reaches the caller.

RELEASE answers a CNA result code, and the point of this function is that the
code is checked rather than dropped."
  (let ((completed nil)
        (values nil))
    (unwind-protect
         (progn (setf values (multiple-value-list (funcall body)))
                (setf completed t))
      (unless completed
        (ignore-errors (funcall release))))
    (check-result (funcall release) operation :object-type object-type)
    (values-list values)))

(defmacro with-transient-native ((release operation &key object-type) &body body)
  "Run BODY, then evaluate RELEASE and check its result. See
CALL-WITH-TRANSIENT-NATIVE."
  `(call-with-transient-native (lambda () ,@body) (lambda () ,release)
                               ,operation :object-type ,object-type))
