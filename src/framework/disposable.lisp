;;;; disposable.lisp --- deterministic disposal for every native-backed object.
;;;;
;;;; DISPOSE is the one way a CNA resource is released. There is no finalizer
;;;; anywhere in CNA-Lisp that destroys a CNA object, and there will not be one:
;;;; a finalizer runs on whatever thread the collector happens to be using, and
;;;; every CNA handle is affine to the thread that created its game. A finalizer
;;;; that called CNA would be calling it from the wrong thread by construction.
;;;;
;;;; DISPOSE is idempotent, exactly as IDisposable.Dispose is.

(in-package #:microsoft.xna.framework)

(defgeneric disposed-p (object)
  (:documentation
   "True once OBJECT has been disposed.

A CNA-Lisp addition rather than an XNA member: XNA spells this differently on
each type that has it at all, and CNA-Lisp needs one question that can be asked
of anything holding a native resource.")
  (:method ((object cna-lisp.internal:native-object))
    (cna-lisp.internal:disposed-state-of object)))

(defgeneric dispose (object)
  (:documentation
   "Release OBJECT's native resource, deterministically and now.

Refuses when OBJECT still owns live children -- CNA requires children to be
destroyed before their parent, and a diagnosable refusal is better than the
native failure that would follow. Calling DISPOSE on an already-disposed object
does nothing, exactly as IDisposable.Dispose does."))

(defgeneric %check-disposable (object)
  (:documentation
   "Signal when OBJECT must not be disposed at all -- *before* DISPOSE touches it.

Refusing inside DESTROY-NATIVE is not soon enough, and that was the bug this
exists to close. DISPOSE invalidates through an UNWIND-PROTECT, so a refusal
raised from the destruction still ran the invalidation on the way out: the object
came back marked disposed and holding no handle, over a native resource that was
never released and is still perfectly alive. A caller who wrapped the refusal in
HANDLER-CASE -- the reasonable thing to do with a refusal -- was left with a
poisoned facade:

    (let ((content (content game)))
      (ignore-errors (dispose content))   ; correctly refused
      (root-directory content))           ; ...and now this fails too

The default refuses every :PARENT-OWNED object, because a facade holds no handle
of its own: CNA lends it, answers the same handle every time, and releases it
with the parent. Specialise this to say *why* for a particular type. Do not
specialise it to accept -- a facade that quietly accepted disposal would be
claiming to have released something it does not own.")
  (:method ((object cna-lisp.internal:native-object))
    (when (eq (cna-lisp.internal:ownership-of object) :parent-owned)
      (error 'cna-ownership-error
             :operation "dispose"
             :object-type (type-of object)
             :format-control
             "a ~a reached this way is a facade over something its parent owns. CNA lends ~
              the handle, answers the same one every time and releases it with the parent, ~
              so there is nothing here to dispose. Dispose the parent instead."
             :format-arguments (list (string-downcase (type-of object)))))))

(defun %live-owned-children (object)
  (remove-if (lambda (child)
               (or (eq (cna-lisp.internal:ownership-of child) :parent-owned)
                   (disposed-p child)))
             (cna-lisp.internal:children-of object)))

(defmethod dispose ((object cna-lisp.internal:native-object))
  (unless (disposed-p object)
    (cna-lisp.internal:check-owner-thread
     (cna-lisp.internal:owner-thread-of object) "dispose" :object-type (type-of object))
    ;; Before the UNWIND-PROTECT below, and deliberately: a refusal raised from
    ;; inside it would still invalidate the object on the way out. See
    ;; %CHECK-DISPOSABLE.
    (%check-disposable object)
    (let ((children (%live-owned-children object)))
      (when children
        (error 'cna-ownership-error
               :operation "dispose"
               :object-type (type-of object)
               :format-control
               "~a still owns ~d live native ~:[child~;children~] (~{~a~^, ~}). CNA destroys ~
                children before their parent and refuses the other order; dispose them ~
                first. CNA-Lisp does not cascade on your behalf, because deciding when a ~
                resource dies is the program's decision, not the binding's."
               :format-arguments (list (type-of object) (length children) (rest children)
                                       (mapcar (lambda (c) (string-downcase (type-of c)))
                                               children)))))
    (unwind-protect
         (cna-lisp.internal:destroy-native object)
      ;; The handle is invalid once CNA has released it, including when a shutdown
      ;; callback reported a failure. Dropping it here means a failed disposal
      ;; still cannot leave a stale handle reachable.
      (cna-lisp.internal:invalidate object)))
  (values))

(defmacro with-disposal ((variable form) &body body)
  "Evaluate FORM, bind VARIABLE to it for BODY, and DISPOSE it on the way out.

A CNA-Lisp convenience over UNWIND-PROTECT, not a replacement for the object
model: the object is an ordinary value while the body runs, and disposing it
early inside the body is legal because DISPOSE is idempotent."
  `(let ((,variable ,form))
     (unwind-protect (progn ,@body)
       (dispose ,variable))))
