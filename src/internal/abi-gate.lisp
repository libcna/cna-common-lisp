;;;; abi-gate.lisp --- the admitted CNA C ABI versions, and why.
;;;;
;;;; The CNA 0.x C ABI is experimental. CNA-Lisp therefore admits an explicit
;;;; *set* of encoded versions rather than a range: not "any 0.x", not "this
;;;; minor or newer". A version enters the set only after the whole bound native
;;;; surface -- every prototype, every struct size, alignment, field offset and
;;;; field size, and every constant -- has been verified by a C compiler against
;;;; that version's canonical headers. See docs/native-abi.md.

(in-package #:cna-lisp.internal)

(defparameter *admitted-abi-versions*
  ;; Regenerate with tools/native-abi/generate.py; the evidence for each entry is
  ;; recorded in docs/generated/native-abi-manifest.json.
  '((5376 . "0.21.0")
    (5632 . "0.22.0")
    (5888 . "0.23.0"))
  "Encoded CNA C ABI versions this build has qualified, with their spelling.")

(defvar *loaded-abi-version* nil)

(defun encode-abi-version (major minor patch)
  "The CNA encoding of an ABI version triple."
  (logior (ash (logand major #xFFFF) 16)
          (ash (logand minor #xFF) 8)
          (logand patch #xFF)))

(defun decode-abi-version (encoded)
  "The major, minor and patch components of an encoded CNA ABI version."
  (values (ash encoded -16) (ldb (byte 8 8) encoded) (ldb (byte 8 0) encoded)))

(defun format-abi-version (encoded)
  "ENCODED as the usual dotted spelling."
  (multiple-value-bind (major minor patch) (decode-abi-version encoded)
    (format nil "~d.~d.~d" major minor patch)))

(defun admitted-abi-versions ()
  "The encoded ABI versions this build admits."
  (mapcar #'car *admitted-abi-versions*))

(defun loaded-abi-version ()
  "The encoded ABI version the loaded CNA library reports."
  *loaded-abi-version*)

(defun ensure-abi-admitted ()
  "Read the loaded library's ABI version and refuse it unless it is admitted.

This is the first CNA route CNA-Lisp ever calls. A rejection names the library
that was loaded, the version it reports, the exact set this build admits, and
how to supply a qualified library."
  (ensure-native-library)
  (let ((found (ffi::%get-abi-version)))
    (setf *loaded-abi-version* found)
    (unless (member found (admitted-abi-versions))
      (error 'microsoft.xna.framework:cna-abi-rejected-error
             :operation "admit-abi-version"
             :found-version found
             :admitted-versions (admitted-abi-versions)
             :native-library-path (native-library-path)
             :format-control
             "~s reports CNA C ABI ~a (encoded ~d), which this build of CNA-Lisp has not ~
              qualified. It admits exactly ~{~a~^, ~}, because the whole bound native ~
              surface has been verified by a C compiler against those versions' canonical ~
              headers and against no other. The CNA 0.x C ABI is experimental, so a ~
              matching major number is not evidence of compatibility. Point ~a at a ~
              qualified CNA C ABI shared library, or qualify this one with ~
              tools/native-abi/verify.sh and add it to the admitted set."
             :format-arguments
             (list (native-library-path)
                   (format-abi-version found)
                   found
                   (mapcar (lambda (entry) (format nil "~a (encoded ~d)" (cdr entry) (car entry)))
                           *admitted-abi-versions*)
                   +native-library-environment-variable+)))
    found))

(defun verify-struct-layouts ()
  "Check CFFI's own view of every bound struct against the recorded ABI layout.

The generated declarations pin each field to an explicit offset, so this proves
that the Lisp side agrees with the layout the C compiler measured -- independent
of the C probe, which proves the same layout against the headers."
  (let ((problems '()))
    (dolist (row ffi:*native-struct-layouts*)
      (destructuring-bind (name size align fields) row
        (let ((actual-size (cffi:foreign-type-size (list :struct name)))
              (actual-align (cffi:foreign-type-alignment (list :struct name))))
          (unless (= actual-size size)
            (push (list name :size size actual-size) problems))
          (unless (= actual-align align)
            (push (list name :alignment align actual-align) problems))
          (dolist (field fields)
            (destructuring-bind (field-name offset field-size) field
              (let ((actual-offset (cffi:foreign-slot-offset (list :struct name) field-name)))
                (unless (= actual-offset offset)
                  (push (list name field-name :offset offset actual-offset) problems))
                (let ((slot-size
                        (ignore-errors
                         (cffi:foreign-type-size
                          (cffi:foreign-slot-type (list :struct name) field-name)))))
                  (when (and slot-size (/= slot-size field-size)
                             ;; An array field's recorded size is the whole array.
                             (/= 0 (mod field-size slot-size)))
                    (push (list name field-name :size field-size slot-size) problems)))))))))
    (nreverse problems)))
