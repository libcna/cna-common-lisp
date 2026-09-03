;;;; results.lisp --- translating CNA result codes into Lisp conditions.
;;;;
;;;; This is the only place in CNA-Lisp that reads a CNA result code. Above it
;;;; nothing has one: an operation either returns its value or signals.

(in-package #:cna-lisp.internal)

(defconstant +result-success+ ffi::+result-success+)
(defconstant +result-callback+ ffi::+result-callback+)

(defparameter *result-conditions*
  `((,ffi::+result-invalid-argument+  . microsoft.xna.framework:cna-invalid-argument-error)
    (,ffi::+result-invalid-handle+    . microsoft.xna.framework:cna-invalid-object-error)
    (,ffi::+result-invalid-state+     . microsoft.xna.framework:cna-invalid-state-error)
    (,ffi::+result-out-of-memory+     . microsoft.xna.framework:cna-out-of-memory-error)
    (,ffi::+result-io+                . microsoft.xna.framework:cna-io-error)
    (,ffi::+result-not-supported+     . microsoft.xna.framework:cna-not-supported-error)
    (,ffi::+result-platform+          . microsoft.xna.framework:cna-platform-error)
    (,ffi::+result-thread+            . microsoft.xna.framework:cna-thread-error)
    (,ffi::+result-callback+          . microsoft.xna.framework:cna-callback-error)
    (,ffi::+result-overflow+          . microsoft.xna.framework:cna-overflow-error)
    (,ffi::+result-encoding+          . microsoft.xna.framework:cna-encoding-error)
    (,ffi::+result-internal+          . microsoft.xna.framework:cna-internal-error)
    (,ffi::+result-shutting-down+     . microsoft.xna.framework:cna-shutting-down-error)
    (,ffi::+result-buffer-too-small+  . microsoft.xna.framework:cna-buffer-too-small-error))
  "One condition class per CNA result code. A code with no entry becomes a plain
CNA-NATIVE-ERROR rather than being silently treated as success.")

(defparameter *result-names*
  `((,ffi::+result-success+           . :success)
    (,ffi::+result-invalid-argument+  . :invalid-argument)
    (,ffi::+result-invalid-handle+    . :invalid-handle)
    (,ffi::+result-invalid-state+     . :invalid-state)
    (,ffi::+result-out-of-memory+     . :out-of-memory)
    (,ffi::+result-io+                . :io)
    (,ffi::+result-not-supported+     . :not-supported)
    (,ffi::+result-platform+          . :platform)
    (,ffi::+result-thread+            . :thread)
    (,ffi::+result-callback+          . :callback)
    (,ffi::+result-overflow+          . :overflow)
    (,ffi::+result-encoding+          . :encoding)
    (,ffi::+result-internal+          . :internal)
    (,ffi::+result-shutting-down+     . :shutting-down)
    (,ffi::+result-buffer-too-small+  . :buffer-too-small)))

(defun result-name (code)
  "The keyword CNA-Lisp uses for a CNA result CODE, for diagnostics and tests."
  (or (cdr (assoc code *result-names*)) :unknown))

(defun last-native-message ()
  "CNA's own diagnostic text for the most recent failure on this thread, or NIL.

Error queries never overwrite the thread-local diagnostic, so calling this after
a failure is safe and repeatable."
  (cffi:with-foreign-object (needed :uint64)
    (unless (zerop (ffi::%error-get-last-message-size needed))
      (return-from last-native-message nil))
    (let ((n (cffi:mem-ref needed :uint64)))
      (when (zerop n) (return-from last-native-message nil))
      (cffi:with-foreign-object (buffer :uint8 n)
        (cffi:with-foreign-object (written :uint64)
          (unless (zerop (ffi::%error-copy-last-message buffer n written))
            (return-from last-native-message nil))
          (let ((count (cffi:mem-ref written :uint64)))
            (handler-case
                (utf8-octets-to-string
                 (let ((v (make-array count :element-type '(unsigned-byte 8))))
                   (dotimes (i count v)
                     (setf (aref v i) (cffi:mem-aref buffer :uint8 i)))))
              (error () nil))))))))

(defun last-error-category ()
  "CNA's stable error category for the most recent failure on this thread, or NIL."
  (cffi:with-foreign-object (info '(:struct ffi::cna-error-info))
    (setf (cffi:foreign-slot-value info '(:struct ffi::cna-error-info) 'ffi::struct-size)
          ffi::+sizeof-cna-error-info+
          (cffi:foreign-slot-value info '(:struct ffi::cna-error-info) 'ffi::struct-version) 1)
    (when (zerop (ffi::%error-get-last-info info))
      (cffi:foreign-slot-value info '(:struct ffi::cna-error-info) 'ffi::category))))

(defun check-result (code operation &key object-type (callback-condition nil))
  "Return T when CODE is success; otherwise signal the condition it names.

OPERATION is the CNA-Lisp operation being performed, in Lisp terms. The CNA
diagnostic text and error category are read before anything else can disturb the
thread-local diagnostic."
  (if (= code +result-success+)
      t
      (let* ((message (last-native-message))
             (category (last-error-category))
             (class (or (cdr (assoc code *result-conditions*))
                        'microsoft.xna.framework:cna-native-error)))
        (if (and (eql class 'microsoft.xna.framework:cna-callback-error) callback-condition)
            (error class :operation operation :native-message message
                         :object-type object-type :%result code :%category category
                         :underlying-condition callback-condition)
            (error class :operation operation :native-message message
                         :object-type object-type :%result code :%category category)))))
