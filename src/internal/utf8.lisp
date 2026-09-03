;;;; utf8.lisp --- exact UTF-8 conversion for the CNA C ABI.
;;;;
;;;; The CNA C ABI carries text as an explicit pointer-plus-length view of UTF-8
;;;; bytes; it never uses a NUL terminator, and the byte counts it reports never
;;;; include one. Babel does the encoding so the conversion is exact rather than
;;;; whatever the Lisp's default external format happens to be.

(in-package #:cna-lisp.internal)

(defun string-to-utf8-octets (string)
  "The exact UTF-8 bytes of STRING."
  (babel:string-to-octets string :encoding :utf-8))

(defun utf8-octets-to-string (octets)
  "The string OCTETS encodes, decoded as strict UTF-8."
  (babel:octets-to-string (coerce octets '(vector (unsigned-byte 8))) :encoding :utf-8))

(defmacro with-utf8-view ((data-var length-var string) &body body)
  "Bind DATA-VAR to a foreign buffer holding STRING's UTF-8 bytes and LENGTH-VAR
to their count, for the dynamic extent of BODY.

CNA borrows the bytes only for the duration of the call it is given them in, so
stack-allocating them here is exactly the lifetime the contract asks for. A zero
length is legal and passes a valid, non-null pointer."
  (let ((octets (gensym "OCTETS")) (i (gensym "I")))
    `(let* ((,octets (string-to-utf8-octets ,string))
            (,length-var (length ,octets)))
       (cffi:with-foreign-object (,data-var :uint8 (max 1 ,length-var))
         (dotimes (,i ,length-var)
           (setf (cffi:mem-aref ,data-var :uint8 ,i) (aref ,octets ,i)))
         ,@body))))

(defun count-then-copy-string (size-thunk copy-thunk operation)
  "Read one CNA string through the ABI's count-then-copy idiom.

SIZE-THUNK receives a foreign uint64 pointer and answers a result code.
COPY-THUNK receives (DESTINATION CAPACITY OUT-BYTES) and answers a result code.
The reported count never includes a terminator, and a capacity that is too small
is refused without a partial write, so the buffer allocated here is exactly the
size the ABI asked for."
  (cffi:with-foreign-object (needed :uint64)
    (check-result (funcall size-thunk needed) operation)
    (let ((n (cffi:mem-ref needed :uint64)))
      (if (zerop n)
          ""
          (cffi:with-foreign-object (buffer :uint8 n)
            (cffi:with-foreign-object (written :uint64)
              (check-result (funcall copy-thunk buffer n written) operation)
              (let ((count (cffi:mem-ref written :uint64)))
                (utf8-octets-to-string
                 (let ((v (make-array count :element-type '(unsigned-byte 8))))
                   (dotimes (i count v)
                     (setf (aref v i) (cffi:mem-aref buffer :uint8 i))))))))))))
