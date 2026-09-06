;;;; storage-stream.lisp --- the Common Lisp stream a storage file opens as.
;;;;
;;;; **This is the answer to the second of Storage's two design questions, and
;;;; the argument is in `docs/limitations.md'.** The short form:
;;;;
;;;; `StorageContainer.CreateFile' and its three `OpenFile' overloads answer
;;;; `System.IO.Stream'. This binding already declares what that projects onto --
;;;; "`System.IO.Stream' is a Common Lisp stream, and is not a projected type" --
;;;; and `Texture2D.FromStream' and `SaveAsPng' already move bytes across ordinary
;;;; CL binary streams. What Storage adds is that the stream on the *other* side
;;;; is CNA's: a seekable, readable-and-writable object with eleven routes of its
;;;; own, and the first such object to cross this boundary.
;;;;
;;;; Answering a second, parallel stream-like API -- a class with `read-bytes'
;;;; and `write-bytes' of its own -- would have been easy and would have made the
;;;; statement above false. So this is a **real Common Lisp stream**, built on
;;;; Gray streams, and the ordinary vocabulary works on it:
;;;;
;;;;   (read-sequence buffer stream)      (write-sequence buffer stream)
;;;;   (read-byte stream nil :eof)        (write-byte 65 stream)
;;;;   (file-position stream)             (file-position stream 128)
;;;;   (file-position stream :end)        (force-output stream)
;;;;   (close stream)                     (with-open-stream (s ...) ...)
;;;;
;;;; **`FILE-LENGTH' is not among them, and that is the Gray protocol's limit
;;;; rather than a choice.** `CL:FILE-LENGTH' takes a *file stream* and there is
;;;; no Gray generic behind it, so no portable stream class can answer it. The
;;;; length is reached the way it is reached on any other non-file stream:
;;;; `(file-position stream :end)', which is `cna_storage_stream_seek' with the
;;;; END origin and answers the same number `cna_storage_stream_get_length'
;;;; would. That route is bound and unused for exactly this reason.
;;;;
;;;; **The dependency is `trivial-gray-streams', and it is not the thing the
;;;; `cffi-libffi' refusal was about.** That refusal is recorded as being about
;;;; *load-time requirements*: "a released binding needs neither" libffi headers
;;;; nor a C compiler. `trivial-gray-streams' is a few hundred lines of portable
;;;; Common Lisp with no foreign code, no toolchain and no build step, so it
;;;; costs a released binding nothing that the policy is protecting.
;;;;
;;;; --- what a CNA stream is, and is not --------------------------------------
;;;;
;;;; It is an **owned child of its container**: `cna_storage_container_create_file'
;;;; and the three open routes answer an owned handle, and the header says "the
;;;; stream is a child of its container and must be closed before the container is
;;;; destroyed". `cna_storage_stream_close' is the release, so `CL:CLOSE' is what
;;;; calls it and the ownership graph is Container -> Stream.
;;;;
;;;; It reports its own capabilities -- `can_read', `can_write', `can_seek' -- and
;;;; those are what `INPUT-STREAM-P' and friends answer, rather than a guess made
;;;; from the `FileAccess' the caller asked for.

(in-package #:microsoft.xna.framework.storage)

(defclass storage-stream (cna-lisp.internal:native-object
                          trivial-gray-streams:trivial-gray-stream-mixin
                          trivial-gray-streams:fundamental-binary-input-stream
                          trivial-gray-streams:fundamental-binary-output-stream)
  ((can-read :reader %stream-can-read
             :documentation "CNA's `can_read', read once when the stream opened.")
   (can-write :reader %stream-can-write
              :documentation "CNA's `can_write', read once when the stream opened.")
   (can-seek :reader %stream-can-seek
             :documentation "CNA's `can_seek', read once when the stream opened."))
  (:documentation
   "The Common Lisp stream a file inside a `STORAGE-CONTAINER' opens as.

    (let ((stream (open-file container \"save.dat\" :mode :create)))
      (unwind-protect (write-sequence bytes stream)
        (close stream)))

**An ordinary binary stream**, which is the whole point: `READ-SEQUENCE',
`WRITE-SEQUENCE', `READ-BYTE', `WRITE-BYTE', `FILE-POSITION', `FORCE-OUTPUT',
`CLOSE' and `WITH-OPEN-STREAM' all work. `FILE-LENGTH' does not, because
`CL:FILE-LENGTH' takes a file stream and the Gray protocol has no generic behind
it; `(file-position stream :end)' is the length. `System.IO.Stream' is
not a projected type here and never was; a Common Lisp stream is what it becomes.

It is an **owned child of its container** and must be closed before the container
is disposed, which CNA requires and this binding enforces through the ordinary
ownership graph. `CLOSE' releases it. **Disposing the container does not**:
ownership here never cascades, so a container that still owns an open stream
refuses disposal with a `CNA-OWNERSHIP-ERROR' naming what is still live. Close
the streams, then the container, then the device.

Whether it can be read, written or sought is **CNA's answer**, read when the
stream opened, rather than a guess from the `FileAccess' that was asked for."))

(defun %adopt-storage-stream (container handle operation)
  "Build the stream over a handle CNA has already given us, as a child of CONTAINER."
  (let ((stream (make-instance 'storage-stream
                               :handle handle
                               :ownership :owned
                               :owner container
                               :owner-thread
                               (cna-lisp.internal:owner-thread-of container))))
    (cna-lisp.internal:register-child container stream)
    (flet ((flag (route)
             (cffi:with-foreign-object (out :uint8)
               (cna-lisp.internal:check-result (funcall route handle out)
                                               operation :object-type 'storage-stream)
               (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref out :uint8)))))
      (setf (slot-value stream 'can-read)
            (flag #'cna-lisp.internal.ffi::%storage-stream-get-can-read)
            (slot-value stream 'can-write)
            (flag #'cna-lisp.internal.ffi::%storage-stream-get-can-write)
            (slot-value stream 'can-seek)
            (flag #'cna-lisp.internal.ffi::%storage-stream-get-can-seek)))
    stream))

(defmethod cna-lisp.internal:destroy-native ((stream storage-stream))
  "`cna_storage_stream_close' is the release, so closing *is* destroying.

CNA has one route where a CL stream has two ideas -- flushing and releasing --
and its `close' does both. There is no separate destroy route, which is CNA
saying that a closed stream is a released stream."
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%storage-stream-close
    (cna-lisp.internal:handle-of stream))
   "close" :object-type 'storage-stream))

;;; --- the Gray stream protocol ----------------------------------------------

(defmethod cl:input-stream-p ((stream storage-stream))
  (%stream-can-read stream))

(defmethod cl:output-stream-p ((stream storage-stream))
  (%stream-can-write stream))

(defmethod cl:stream-element-type ((stream storage-stream))
  "Bytes, always. CNA's stream routes move `uint8_t' and nothing else."
  '(unsigned-byte 8))

(defmethod cl:close ((stream storage-stream) &key abort)
  "Close the stream, releasing CNA's handle.

ABORT is accepted and ignored, which is what it means here: CNA's `close' is the
only release there is, so there is no way to discard buffered output without
releasing -- and nothing is buffered on this side to discard."
  (declare (ignore abort))
  (unless (cna-lisp.internal:disposed-state-of stream)
    (xna:dispose stream))
  t)

(defmethod cl:open-stream-p ((stream storage-stream))
  (not (cna-lisp.internal:disposed-state-of stream)))

(defmethod trivial-gray-streams:stream-read-sequence
    ((stream storage-stream) sequence start end &key)
  "Fill SEQUENCE between START and END, and answer the index just past the last
byte read.

**A short read is ordinary**, and the answer says how short: CNA's
`cna_storage_stream_read' \"receives the number of bytes actually read\", and a
read at the end of the file answers zero. That is exactly what
`READ-SEQUENCE' is specified to report, so nothing has to be invented."
  (let ((operation "read-sequence"))
    (cna-lisp.internal:check-usable stream operation)
    (let* ((end (or end (length sequence)))
           (count (- end start)))
      (when (<= count 0) (return-from trivial-gray-streams:stream-read-sequence start))
      (unless (%stream-can-read stream)
        (error 'xna:cna-invalid-state-error
               :operation operation :object-type 'storage-stream
               :format-control
               "this stream was not opened for reading; CNA reports can_read false."))
      (cffi:with-foreign-object (buffer :uint8 count)
        (cffi:with-foreign-object (read :uint64)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%storage-stream-read
            (cna-lisp.internal:handle-of stream) buffer count read)
           operation :object-type 'storage-stream)
          (let ((n (cffi:mem-ref read :uint64)))
            (dotimes (i n)
              (setf (elt sequence (+ start i)) (cffi:mem-aref buffer :uint8 i)))
            (+ start n)))))))

(defmethod trivial-gray-streams:stream-write-sequence
    ((stream storage-stream) sequence start end &key)
  "Write SEQUENCE between START and END, and answer SEQUENCE.

CNA's `cna_storage_stream_write' takes a count and writes all of it or fails, so
there is no short write to report -- which is what `WRITE-SEQUENCE' expects."
  (let ((operation "write-sequence"))
    (cna-lisp.internal:check-usable stream operation)
    (let* ((end (or end (length sequence)))
           (count (- end start)))
      (when (<= count 0) (return-from trivial-gray-streams:stream-write-sequence sequence))
      (unless (%stream-can-write stream)
        (error 'xna:cna-invalid-state-error
               :operation operation :object-type 'storage-stream
               :format-control
               "this stream was not opened for writing; CNA reports can_write false."))
      (cffi:with-foreign-object (buffer :uint8 count)
        (dotimes (i count)
          (setf (cffi:mem-aref buffer :uint8 i) (elt sequence (+ start i))))
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%storage-stream-write
          (cna-lisp.internal:handle-of stream) buffer count)
         operation :object-type 'storage-stream))
      sequence)))

(defmethod trivial-gray-streams:stream-read-byte ((stream storage-stream))
  "One byte, or `:EOF' at the end of the file -- which is what Gray streams want."
  (let ((one (make-array 1 :element-type '(unsigned-byte 8))))
    (if (zerop (trivial-gray-streams:stream-read-sequence stream one 0 1))
        :eof
        (aref one 0))))

(defmethod trivial-gray-streams:stream-write-byte ((stream storage-stream) byte)
  (check-type byte (unsigned-byte 8))
  (trivial-gray-streams:stream-write-sequence
   stream (make-array 1 :element-type '(unsigned-byte 8) :initial-element byte) 0 1)
  byte)

(defmethod trivial-gray-streams:stream-force-output ((stream storage-stream))
  "`cna_storage_stream_flush'. Nothing is buffered on this side, so this is the
native flush and only that."
  (let ((operation "force-output"))
    (cna-lisp.internal:check-usable stream operation)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%storage-stream-flush
      (cna-lisp.internal:handle-of stream))
     operation :object-type 'storage-stream)
    nil))

(defmethod trivial-gray-streams:stream-finish-output ((stream storage-stream))
  (trivial-gray-streams:stream-force-output stream))

(defmethod trivial-gray-streams:stream-file-position ((stream storage-stream))
  "Where the stream is, in bytes from the beginning."
  (let ((operation "file-position"))
    (cna-lisp.internal:check-usable stream operation)
    (cffi:with-foreign-object (out :int64)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%storage-stream-get-position
        (cna-lisp.internal:handle-of stream) out)
       operation :object-type 'storage-stream)
      (cffi:mem-ref out :int64))))

(defmethod (setf trivial-gray-streams:stream-file-position)
    (position (stream storage-stream))
  "Seek. `:START' and `:END' are the two designators `FILE-POSITION' defines
besides an integer, and they become CNA's `BEGIN' and `END' origins."
  (let ((operation "file-position"))
    (cna-lisp.internal:check-usable stream operation)
    (unless (%stream-can-seek stream)
      (error 'xna:cna-invalid-state-error
             :operation operation :object-type 'storage-stream
             :format-control
             "this stream cannot seek; CNA reports can_seek false."))
    (multiple-value-bind (offset origin)
        (case position
          (:start (values 0 cna-lisp.internal.ffi::+seek-origin-begin+))
          (:end (values 0 cna-lisp.internal.ffi::+seek-origin-end+))
          (t (unless (and (integerp position) (<= 0 position))
               (error 'xna:cna-argument-out-of-range-error
                      :operation operation :parameter-name "position"
                      :object-type 'storage-stream
                      :format-control
                      "a file position is :START, :END, or a non-negative ~
                       integer; ~s is none of them."
                      :format-arguments (list position)))
             (values position cna-lisp.internal.ffi::+seek-origin-begin+)))
      (cffi:with-foreign-object (out :int64)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%storage-stream-seek
          (cna-lisp.internal:handle-of stream) offset origin out)
         operation :object-type 'storage-stream)
        (cffi:mem-ref out :int64)))))

(defmethod print-object ((stream storage-stream) stream-out)
  (print-unreadable-object (stream stream-out :type t)
    (if (cna-lisp.internal:disposed-state-of stream)
        (format stream-out "closed")
        (format stream-out "~:[~;r~]~:[~;w~]~:[~;s~]"
                (%stream-can-read stream) (%stream-can-write stream)
                (%stream-can-seek stream)))))
