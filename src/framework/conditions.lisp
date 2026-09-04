;;;; conditions.lisp --- the CNA-Lisp condition hierarchy.
;;;;
;;;; A consumer of CNA-Lisp sees Lisp conditions, never a result code and never
;;;; a pair of a result and a message. Every native failure is translated at the
;;;; boundary into the condition class that names what went wrong, carrying the
;;;; operation that failed, CNA's own diagnostic text and, where it is safe to
;;;; read, the object and state involved.
;;;;
;;;; The CNA result code itself is deliberately *not* a public reader: it is an
;;;; ABI detail. It is recorded in a private slot so that diagnostics and tests
;;;; can still see exactly what the ABI said.

(in-package #:microsoft.xna.framework)

(define-condition cna-error (error)
  ((operation :initarg :operation :initform nil :reader cna-error-operation
              :documentation "A short name for the CNA-Lisp operation that failed.")
   (native-message :initarg :native-message :initform nil :reader cna-error-native-message
                   :documentation "CNA's own diagnostic text, or NIL when CNA had none.")
   (object-type :initarg :object-type :initform nil :reader cna-error-object-type
                :documentation "The class name of the object involved, when there was one.")
   (%result :initarg :%result :initform nil :reader %cna-error-result)
   (%category :initarg :%category :initform nil :reader %cna-error-category)
   (format-control :initarg :format-control :initform nil :reader %cna-error-format-control)
   (format-arguments :initarg :format-arguments :initform nil
                     :reader %cna-error-format-arguments))
  (:documentation
   "Superclass of every condition CNA-Lisp signals. Its readers describe the
failure in Lisp terms; the CNA result code behind it is not part of the public
API.")
  (:report
   (lambda (condition stream)
     (let ((control (%cna-error-format-control condition)))
       (if control
           (apply #'format stream control (%cna-error-format-arguments condition))
           (format stream "~@[~a: ~]~a"
                   (cna-error-operation condition)
                   (or (cna-error-native-message condition)
                       "the CNA native runtime reported a failure"))))
     (let ((type (cna-error-object-type condition)))
       (when type (format stream " [~a]" type))))))

(define-condition cna-usage-error (cna-error) ()
  (:documentation "A CNA-Lisp contract was broken by the calling program."))

(define-condition cna-native-error (cna-error) ()
  (:documentation "The CNA native runtime refused or failed an operation."))

;;; One condition class per CNA result code. The names describe the failure, not
;;; the number: a consumer handles CNA-INVALID-STATE-ERROR, never `result 3'.

(macrolet ((define-native-conditions (&rest specs)
             `(progn
                ,@(loop for (name doc) in specs
                        collect `(define-condition ,name (cna-native-error) ()
                                   (:documentation ,doc))))))
  (define-native-conditions
    (cna-invalid-argument-error
     "An argument violated the CNA native contract.")
    (cna-invalid-object-error
     "A native object was stale, already destroyed, or of the wrong kind.")
    (cna-invalid-state-error
     "The operation is not valid for the current object or runtime state.")
    (cna-out-of-memory-error
     "A native allocation failed.")
    (cna-io-error
     "A native input or output operation failed.")
    (cna-not-supported-error
     "The selected renderer or platform does not support this operation.")
    (cna-platform-error
     "A native platform service failed.")
    (cna-thread-error
     "The operation was attempted from a thread that may not perform it.")
    (cna-overflow-error
     "A size or numeric conversion cannot be represented safely.")
    (cna-encoding-error
     "Text was not valid for the UTF-8 contract the CNA C ABI requires.")
    (cna-internal-error
     "CNA caught a native failure with no more specific public meaning.")
    (cna-shutting-down-error
     "Native runtime shutdown prevents the operation.")
    (cna-buffer-too-small-error
     "A caller-owned output buffer cannot hold the required result.")))

(define-condition cna-callback-error (cna-native-error)
  ((underlying-condition :initarg :underlying-condition :initform nil
                         :reader cna-callback-underlying-condition
                         :documentation
                         "The Lisp condition the callback signalled, preserved intact."))
  (:documentation
   "A CNA-Lisp lifecycle method signalled, or otherwise failed, inside a native
callback. The original condition is preserved rather than flattened to a string;
it is re-signalled on the Lisp side only after control has returned from the C
call that entered the callback.")
  (:report
   (lambda (condition stream)
     (let ((inner (cna-callback-underlying-condition condition)))
       (format stream "~@[~a: ~]a CNA-Lisp lifecycle method failed inside a native callback"
               (cna-error-operation condition))
       (if inner
           (format stream ": ~a: ~a" (type-of inner) inner)
           (format stream "~@[: ~a~]" (cna-error-native-message condition)))))))

;;; Conditions CNA-Lisp raises on its own behalf, before or instead of a native
;;; call. These are usage errors: the program did something the binding refuses.

(define-condition cna-argument-error (cna-usage-error)
  ((parameter-name :initarg :parameter-name :initform nil
                   :reader cna-error-parameter-name
                   :documentation "The name of the argument the original names."))
  (:documentation
   "An argument is one the original refuses.

CNA-Lisp's projection of System.ArgumentException. Two base-class-library
exceptions reach a caller of the selected XNA surface, and .NET makes one a
subclass of the other, so this hierarchy is that hierarchy:
ArgumentOutOfRangeException is CNA-ARGUMENT-OUT-OF-RANGE-ERROR and is a subtype
of this. Handling this one catches both, which is what a `catch
(ArgumentException)' does there.

`SpriteFont' is where the plain ArgumentException appears: setting a
DefaultCharacter the font has no glyph for, and measuring or drawing a code unit
it cannot resolve even through the fallback, both throw it."))

(define-condition cna-argument-out-of-range-error (cna-argument-error)
  ()
  (:documentation
   "An argument is outside the range the original accepts.

CNA-Lisp's projection of System.ArgumentOutOfRangeException. Projecting it --
rather than letting the check disappear -- is what keeps
`(matrix-create-perspective-field-of-view 0 ...)' refusing here as it refuses
there."))

(define-condition cna-disposed-error (cna-usage-error) ()
  (:documentation "The object was already disposed."))

(define-condition cna-ownership-error (cna-usage-error) ()
  (:documentation
   "A native ownership rule was broken: a parent was disposed while it still
owned live children, or a child outlived the generation that created it."))

(define-condition cna-scope-error (cna-usage-error) ()
  (:documentation
   "An operation that is only legal inside a game lifecycle callback was
attempted outside one, or the reverse."))

(define-condition cna-native-library-error (cna-usage-error)
  ((native-library-path :initarg :native-library-path :initform nil
                        :reader cna-native-library-path
                        :documentation "The exact path CNA-Lisp attempted, or NIL."))
  (:documentation
   "The CNA native shared library could not be resolved or loaded. The reader
CNA-NATIVE-LIBRARY-PATH names the exact path that was attempted."))

(define-condition cna-abi-rejected-error (cna-usage-error)
  ((found-version :initarg :found-version :initform nil :reader cna-abi-found-version
                  :documentation "The encoded ABI version the loaded library reports.")
   (admitted-versions :initarg :admitted-versions :initform nil
                      :reader cna-abi-admitted-versions
                      :documentation "Every encoded ABI version this build admits.")
   (native-library-path :initarg :native-library-path :initform nil
                        :reader cna-native-library-path))
  (:documentation
   "The loaded CNA library reports an ABI version this build has not qualified.
The CNA 0.x C ABI is experimental, so CNA-Lisp admits an explicit set of versions
whose whole bound surface a compiler has verified, and refuses every other."))
