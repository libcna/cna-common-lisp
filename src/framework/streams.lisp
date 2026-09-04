;;;; streams.lisp --- the narrowed `System.IO.Stream' this projection needs.
;;;;
;;;; **`System.IO.Stream' is not a projected type, and cannot be.** It is not in
;;;; the pinned contract -- that snapshot is the XNA profile, and `Stream' belongs
;;;; to the BCL -- so there is no selected type here to be complete or partial
;;;; about. What there is, is a handful of XNA members that *take* or *answer* one,
;;;; and a language that has its own equivalent abstraction.
;;;;
;;;; So `System.IO.Stream' maps onto a **Common Lisp binary stream**, and that is
;;;; the whole bridge. A consumer passes an ordinary stream from `OPEN' or from
;;;; anywhere else, and `WITH-OPEN-FILE', `READ-SEQUENCE', `FILE-POSITION' and
;;;; `CLOSE' all mean what they already mean. Nothing here wraps a stream in an
;;;; object, and no `SeekOrigin' is projected: .NET spells relative positioning as
;;;; an enumeration argument, Common Lisp spells it as arithmetic on
;;;; `FILE-POSITION', and inventing an enumeration to pass to a function that does
;;;; not take one would be a type nobody could use.
;;;;
;;;; **What is checked, and in XNA's order.** `Texture2D.SaveAsPng' reads as:
;;;;
;;;;     if (stream == null) throw new ArgumentNullException("stream", ...);
;;;;     if (!stream.CanWrite) throw new ArgumentException("stream");
;;;;
;;;; -- a null check, then a capability check, both argument failures naming the
;;;; parameter. Those are reproduced here, against `INPUT-STREAM-P' and
;;;; `OUTPUT-STREAM-P', which are what `CanRead' and `CanWrite' are called in this
;;;; language.
;;;;
;;;; **Where a Common Lisp stream is less uniform than a .NET one**, and it is
;;;; worth being explicit rather than assuming:
;;;;
;;;;   * There is no `Length'. `FILE-LENGTH' works on a file stream and is not
;;;;     required to work on anything else, and a non-seekable stream answers NIL
;;;;     from `FILE-POSITION' rather than signalling. So nothing here asks how big
;;;;     a stream is: reading goes on until `READ-SEQUENCE' returns short, which
;;;;     is end-of-file for every stream kind and is also the only correct way to
;;;;     handle a partial read.
;;;;   * There is no `CanSeek' to ask for either, and nothing here needs to seek.
;;;;   * A stream has an element type, and a character stream cannot carry image
;;;;     bytes. .NET has one `Stream' for both; Common Lisp does not, so a stream
;;;;     whose elements are not octets is refused by name rather than producing
;;;;     nonsense.
;;;;   * A closed stream is refused, and **as an argument failure rather than as a
;;;;     disposal**, which is a deliberate match rather than an oversight. A
;;;;     disposed .NET `Stream' answers *false* from `CanRead' and `CanWrite', so
;;;;     the check XNA reaches first is the capability one and the exception it
;;;;     throws is `ArgumentException'. Measured on this runtime: SBCL's
;;;;     `INPUT-STREAM-P' answers NIL for a closed stream too, so the same check
;;;;     fires here and the two sides agree. The `OPEN-STREAM-P' check below is a
;;;;     second line for a stream kind that reports a capability while closed.
;;;;
;;;; **Ownership is the caller's, in both directions.** Nothing here closes a
;;;; stream it was given -- XNA does not either, and a member that closed its
;;;; argument would break `WITH-OPEN-FILE' around it. There is therefore no
;;;; leave-open flag, because there is nothing for one to control.

(in-package #:microsoft.xna.framework)

(defconstant +stream-chunk-octets+ 65536
  "How much is read at a time. Any value is correct; this one is a page multiple.")

(defun %check-stream-argument (stream operation direction)
  "XNA's two argument checks, in XNA's order, plus the two Common Lisp adds.

DIRECTION is :INPUT or :OUTPUT. The order matters and is the assembly's: the null
check first, then the capability check, so a null stream is never reported as a
stream that cannot be written."
  (when (null stream)
    (error 'cna-argument-error
           :operation operation :parameter-name "stream"
           :format-control "a stream is required here; XNA throws ArgumentNullException."))
  (unless (streamp stream)
    (error 'cna-argument-error
           :operation operation :parameter-name "stream"
           :format-control
           "~s is not a stream. System.IO.Stream projects onto an ordinary Common Lisp ~
            binary stream in this binding."
           :format-arguments (list stream)))
  (ecase direction
    (:input
     (unless (input-stream-p stream)
       (error 'cna-argument-error
              :operation operation :parameter-name "stream"
              :format-control
              "this stream cannot be read. XNA refuses a Stream whose CanRead is false, ~
               and INPUT-STREAM-P is what CanRead is called here. A **closed** stream ~
               answers NIL to it, on both sides -- so this is also what a stream that ~
               was already closed reports.")))
    (:output
     (unless (output-stream-p stream)
       (error 'cna-argument-error
              :operation operation :parameter-name "stream"
              :format-control
              "this stream cannot be written. XNA refuses a Stream whose CanWrite is ~
               false, and OUTPUT-STREAM-P is what CanWrite is called here. A **closed** ~
               stream answers NIL to it, on both sides -- so this is also what a stream ~
               that was already closed reports."))))
  (unless (open-stream-p stream)
    (error 'cna-disposed-error
           :operation operation :object-type 'stream
           :format-control
           "this stream is closed. XNA's ObjectDisposedException says the same thing ~
            about a Stream that has been disposed."))
  (let ((element-type (stream-element-type stream)))
    (unless (and (subtypep element-type '(unsigned-byte 8))
                 (subtypep '(unsigned-byte 8) element-type))
      (error 'cna-argument-error
             :operation operation :parameter-name "stream"
             :format-control
             "this stream's elements are ~s, and image bytes are (UNSIGNED-BYTE 8). .NET ~
              has one Stream for bytes and for text; Common Lisp does not, so a stream ~
              opened without :ELEMENT-TYPE '(UNSIGNED-BYTE 8) is refused here rather ~
              than read as something it is not."
             :format-arguments (list element-type))))
  stream)

(defun %read-stream-octets (stream operation)
  "Every remaining octet of STREAM, as a (SIMPLE-ARRAY (UNSIGNED-BYTE 8) (*)).

Read in chunks until READ-SEQUENCE returns short. That is end-of-file for every
kind of stream, it is the only correct response to a partial read, and it needs
no Length -- which is the member a Common Lisp stream is not required to have."
  (%check-stream-argument stream operation :input)
  (let ((chunks '())
        (total 0))
    (loop
      (let* ((buffer (make-array +stream-chunk-octets+ :element-type '(unsigned-byte 8)))
             (filled (read-sequence buffer stream)))
        (when (plusp filled)
          (push (cons buffer filled) chunks)
          (incf total filled))
        (when (< filled +stream-chunk-octets+) (return))))
    (let ((octets (make-array total :element-type '(unsigned-byte 8)))
          (at total))
      (dolist (chunk chunks)
        (destructuring-bind (buffer . filled) chunk
          (decf at filled)
          (replace octets buffer :start1 at :end2 filled)))
      octets)))

(defun %write-stream-octets (stream octets operation)
  "Write OCTETS to STREAM. The stream stays open: it is the caller's."
  (%check-stream-argument stream operation :output)
  (write-sequence octets stream)
  (values))
