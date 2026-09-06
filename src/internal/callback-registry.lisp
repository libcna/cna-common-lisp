;;;; callback-registry.lisp --- resolving a C context back to a CLOS object,
;;;; and keeping a Lisp condition from unwinding across a C frame.
;;;;
;;;; CNA carries one `void*' context per callback table. CNA-Lisp never puts a
;;;; Lisp object there: a Lisp object moves, and its address means nothing after
;;;; the next garbage collection. What goes into the context is a small integer
;;;; token; this registry maps the token to the object and roots it for exactly
;;;; as long as CNA may still call back.
;;;;
;;;;   C context pointer -> integer token -> strongly rooted entry -> CLOS game
;;;;
;;;; No Lisp condition may unwind across a C callback boundary. A callback that
;;;; answers a result code runs inside WITH-CONTAINED-CALLBACK, which catches
;;;; every serious condition, preserves the condition object, writes CNA's
;;;; diagnostic structure and returns CNA_RESULT_CALLBACK; one that answers
;;;; `void' runs inside WITH-EVENT-DISPATCH instead, which has no code to answer
;;;; with. src/internal/callback-conditions.lisp is where both preserved
;;;; conditions live and where the rule for delivering each of them is written.

(in-package #:cna-lisp.internal)

(defvar *callback-registry* (make-hash-table :test #'eql :synchronized t)
  "Token -> callback target. Strong references: an entry here is what keeps a
game reachable while CNA still holds its context pointer.")

(defvar *callback-token-counter* 0)
(defvar *callback-token-lock* (bordeaux-threads:make-lock "cna-lisp callback tokens"))

(defun register-callback-target (object)
  "Register OBJECT and answer the integer token CNA will carry as its context."
  (bordeaux-threads:with-lock-held (*callback-token-lock*)
    (let ((token (incf *callback-token-counter*)))
      (setf (gethash token *callback-registry*) object)
      token)))

(defun unregister-callback-target (token)
  "Forget TOKEN. Called only after CNA can no longer invoke the callbacks."
  (remhash token *callback-registry*))

(defun callback-target (token)
  "The object TOKEN names, or NIL when the token is stale."
  (gethash token *callback-registry*))

(defun callback-registry-count ()
  "How many callback targets are currently rooted."
  (hash-table-count *callback-registry*))

(defun map-callback-registry (function)
  (maphash function *callback-registry*))

;;; --- condition containment ---------------------------------------------
;;;
;;; The callback scope, both pending-condition variables and the delivery rule
;;; are in src/internal/callback-conditions.lisp, which is loaded before the
;;; result translation that has to read them. What is left here is the part that
;;; needs the foreign layer: CNA's diagnostic structure, and the two boundaries.

(defvar *callback-error-buffer* nil
  "The foreign buffer holding the diagnostic bytes of the most recent contained
callback failure on this thread.

CNA borrows those bytes and reads them *after* the callback returns, so they must
outlive the callback frame. The buffer is therefore held here and released by
RELEASE-CALLBACK-ERROR-BUFFER once the enclosing native call has come back --
never inside the callback itself, which would hand CNA a dangling pointer.")

(defun release-callback-error-buffer ()
  "Free the diagnostic bytes of the last contained callback failure, if any."
  (let ((buffer *callback-error-buffer*))
    (when buffer
      (setf *callback-error-buffer* nil)
      (ignore-errors (cffi:foreign-free buffer))))
  nil)

(defun %write-callback-error (out-error text)
  "Fill CNA's callback diagnostic structure with TEXT.

Nothing in this function may signal: it runs on the failure path of a callback,
where a condition would be the very thing containment exists to prevent."
  (when (and out-error (not (cffi:null-pointer-p out-error)))
    (ignore-errors
     (release-callback-error-buffer)
     (let* ((octets (string-to-utf8-octets text))
            (n (length octets))
            (buffer (cffi:foreign-alloc :uint8 :count (max 1 n))))
       (dotimes (i n) (setf (cffi:mem-aref buffer :uint8 i) (aref octets i)))
       (setf *callback-error-buffer* buffer)
       (let ((view (cffi:foreign-slot-pointer out-error '(:struct ffi::cna-callback-error)
                                              'ffi::message)))
         (setf (cffi:foreign-slot-value view '(:struct ffi::cna-string-view) 'ffi::data) buffer
               (cffi:foreign-slot-value view '(:struct ffi::cna-string-view) 'ffi::byte-length) n))
       buffer))))

(defun %describe-safely (condition)
  (or (ignore-errors (format nil "~a: ~a" (type-of condition) condition))
      (ignore-errors (format nil "~a" (type-of condition)))
      "a Lisp condition that could not be printed"))

(defmacro with-contained-callback ((out-error &key (operation "a CNA lifecycle callback"))
                                   &body body)
  "Run BODY as the body of a CNA callback, containing every serious condition.

Answers the CNA result code to return: success when BODY completes, and
CNA_RESULT_CALLBACK when it does not. The condition object itself is preserved in
*PENDING-CALLBACK-CONDITION* -- not flattened into a string -- so the Lisp side
can re-signal the real thing once control has come back out of C."
  (let ((condition (gensym "CONDITION")))
    `(handler-case
         (call-with-callback-scope (lambda () ,@body ffi::+result-success+))
       (serious-condition (,condition)
         (setf *pending-callback-condition* ,condition)
         (%write-callback-error
          ,out-error
          (format nil "~a: ~a" ,operation (%describe-safely ,condition)))
         ffi::+result-callback+))))

;;; --- calling a native route that may re-enter Lisp ----------------------

(defun call-native-frame (thunk operation &key object-type)
  "Call a native route that may invoke CNA-Lisp callbacks, and translate its
answer.

A callback that failed has already been contained: CNA saw CNA_RESULT_CALLBACK
and stopped the loop, and the Lisp condition it contained is waiting here. That
condition is attached to the CNA-CALLBACK-ERROR signalled now -- after control has
come back out of C, where signalling is safe again."
  (let ((code (funcall thunk)))
    (unwind-protect
         (if (= code ffi::+result-callback+)
             (check-result code operation :object-type object-type
                                          :callback-condition
                                          (take-pending-callback-condition))
             ;; A lifecycle condition with no CNA_RESULT_CALLBACK beside it is
             ;; one CNA never acted on, so it is dropped rather than left to
             ;; surface at an unrelated later call. **An event condition is not
             ;; dropped here**: it has no result code to be paired with, and
             ;; CHECK-RESULT below is what delivers it.
             (progn (setf *pending-callback-condition* nil)
                    (check-result code operation :object-type object-type)))
      (release-callback-error-buffer))))
