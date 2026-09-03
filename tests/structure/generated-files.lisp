;;;; generated-files.lisp --- the generated foreign layer must be current.
;;;;
;;;; A generated file that someone edited by hand, or that a manifest change left
;;;; behind, is the most dangerous kind of stale: it still compiles, and it
;;;; describes an ABI that is not the one being called. The digest check below
;;;; catches that in an image with no CNA headers and no C compiler; when a header
;;;; root is available, the generator itself is re-run and compared.

(in-package #:cna-common-lisp.tests)
(in-suite structure-tests)

(defparameter *generated-files*
  '("src/internal/ffi/constants.generated.lisp"
    "src/internal/ffi/structs.generated.lisp"
    "src/internal/ffi/functions.generated.lisp"
    "src/framework/predefined-colors.generated.lisp"
    "tools/native-abi/probe.generated.c"
    "tools/native-abi/valueprobe.generated.c"))

(defun read-generated-digest-file ()
  (with-open-file (stream (repository-path "docs/generated/generated-files.json"))
    (let ((text (make-string (file-length stream))))
      (subseq text 0 (read-sequence text stream)))))

(defun sha256-of-file (path)
  "The SHA-256 of PATH, computed by the platform's own sha256sum.

SBCL has no SHA-256, and pulling in a digest library to check a digest would be a
poor trade. Where sha256sum is absent the caller answers NIL and the test reports
that it did not run rather than passing."
  (handler-case
      (let ((output (uiop:run-program (list "sha256sum" (namestring path))
                                      :output :string :ignore-error-status t)))
        (let ((space (position #\Space output)))
          (and space (string-downcase (subseq output 0 space)))))
    (error () nil)))

(defun recorded-digests ()
  "The path/digest pairs docs/generated/generated-files.json records."
  (let ((text (read-generated-digest-file))
        (pairs '()))
    (dolist (relative *generated-files* (nreverse pairs))
      (let ((at (search (format nil "~s" relative) text)))
        (when at
          (let* ((colon (position #\: text :start at))
                 (open (position #\" text :start (1+ colon)))
                 (close (position #\" text :start (1+ open))))
            (push (cons relative (subseq text (1+ open) close)) pairs)))))))

(defun manifest-count (key)
  "One of the generated native-ABI manifest's counts, read out of the JSON.

A literal here would mean editing a test to bind one more native route, which is
the wrong direction: the manifest is the record, so the test reads it."
  (let ((text (with-open-file (stream (repository-path
                                       "docs/generated/native-abi-manifest.json"))
                (let ((buffer (make-string (file-length stream))))
                  (subseq buffer 0 (read-sequence buffer stream)))))
        (needle (format nil "~s:" key)))
    (let ((at (search needle text)))
      (assert at () "the manifest records no ~a count" key)
      (parse-integer text :start (+ at (length needle)) :junk-allowed t))))

(test every-generated-file-says-it-is-generated
  (dolist (relative *generated-files*)
    (let ((path (repository-path relative)))
      (is (probe-file path) "~a is missing" relative)
      (when (probe-file path)
        (with-open-file (stream path)
          (let ((head (make-string 400)))
            (setf head (subseq head 0 (read-sequence head stream)))
            (is (search "GENERATED FILE, DO NOT EDIT" head)
                "~a has no do-not-edit header" relative)
            (is (search "tools/native-abi/generate.py" head)
                "~a does not name its generator" relative)))))))

(test the-digest-record-covers-every-generated-file
  (let ((json (read-generated-digest-file)))
    (dolist (relative *generated-files*)
      (is (search relative json) "~a is absent from the digest record" relative))))

(test no-generated-file-has-been-edited-by-hand
  ;; A hand-edited generated file still compiles, and describes an ABI that is
  ;; not the one being called. That is the failure mode this catches, in an image
  ;; with no CNA headers and no C compiler.
  (let ((recorded (recorded-digests)))
    (is (= (length *generated-files*) (length recorded))
        "the digest record does not cover every generated file")
    (let ((probe (sha256-of-file (repository-path (first *generated-files*)))))
      (if (null probe)
          (skip "sha256sum is unavailable; the digest check did not run")
          (dolist (entry recorded)
            (let ((actual (sha256-of-file (repository-path (car entry)))))
              (is (string= (cdr entry) actual)
                  "~a does not match its recorded digest; regenerate it with ~
                   tools/native-abi/generate.py rather than editing it"
                  (car entry))))))))

(test the-generator-is-reproducible-when-headers-are-available
  ;; A maintenance gate: it runs only where a CNA source checkout is named, which
  ;; is the only place it can mean anything.
  (let ((headers (uiop:getenv "CNA_HEADERS"))
        (baseline (uiop:getenv "CNA_ABI_BASELINE")))
    (if (and headers baseline (string/= headers "") (string/= baseline ""))
        (multiple-value-bind (output error-output code)
            (uiop:run-program (list "python3"
                                    (namestring (repository-path "tools/native-abi/generate.py"))
                                    "--check" "--headers" headers "--baseline" baseline)
                              :output :string :error-output :string :ignore-error-status t)
          (declare (ignore output))
          (is (zerop code) "generated files are stale:~%~a" error-output))
        (skip "CNA_HEADERS and CNA_ABI_BASELINE are not set; the regeneration gate ~
               is a maintenance check and did not run"))))

(test the-bound-function-table-matches-the-declarations
  ;; The generated table is what the ABI report is built from; it must describe
  ;; the routes that actually exist in this image.
  (dolist (row ffi:*bound-native-functions*)
    (destructuring-bind (c-name lisp-name returns argument-types &key thread ownership) row
      (declare (ignore returns))
      (is (stringp c-name))
      (is (keywordp thread))
      (is (stringp ownership))
      (is (fboundp lisp-name) "~a has no bound Lisp function ~a" c-name lisp-name)
      (is (= (length argument-types)
             (length (sb-introspect:function-lambda-list lisp-name)))
          "~a is declared with ~d argument~:p but bound with ~d"
          c-name (length argument-types)
          (length (sb-introspect:function-lambda-list lisp-name))))))

(test every-bound-struct-has-a-recorded-layout
  ;; The count comes from the generated manifest rather than a literal, so
  ;; binding one more struct does not mean editing a number in a test.
  (is (= (manifest-count "structs") (length ffi:*native-struct-layouts*)))
  (is (= (manifest-count "functions") (length ffi:*bound-native-functions*)))
  (dolist (row ffi:*native-struct-layouts*)
    (destructuring-bind (name size align fields) row
      (is (symbolp name))
      (is (plusp size))
      (is (plusp align))
      (is (plusp (length fields))))))
