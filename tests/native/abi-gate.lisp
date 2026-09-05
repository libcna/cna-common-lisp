;;;; abi-gate.lisp --- the ABI gate, against a real library.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(define-native-test the-library-resolves-to-an-absolute-regular-file
  (int:ensure-native-library)
  (is (int:native-library-loaded-p))
  (let ((path (int:native-library-path)))
    (is (uiop:absolute-pathname-p (pathname path)))
    (is (probe-file path))
    (is (not (uiop:directory-pathname-p (probe-file path))))))

(define-native-test the-loaded-abi-version-is-admitted
  (let ((found (int:ensure-abi-admitted)))
    (is (member found (int:admitted-abi-versions))
        "the library reports ~a, which is not in the admitted set ~s"
        (int:format-abi-version found) (int:admitted-abi-versions))
    (is (= found (int:loaded-abi-version)))))

(define-native-test the-admitted-set-is-explicit-and-small
  ;; Not a range and not "any 0.x": each entry is a version whose whole bound
  ;; surface a compiler has checked, and the set is written out so that adding one
  ;; is a decision rather than a consequence.
  (int:ensure-abi-admitted)
  (is (= 2 (length (int:admitted-abi-versions))))
  (is (equal '(5376 5632) (int:admitted-abi-versions))
      "0.21.0 and 0.22.0, in that order"))

(define-native-test the-loaded-library-is-one-of-the-two-admitted-versions
  ;; Which one depends on which library CNA_NATIVE_LIBRARY names, and both are
  ;; qualified: docs/qualification.md records a run against each. This asserts the
  ;; set has not quietly become a range -- a third version would be admitted by
  ;; neither branch.
  (let ((found (int:ensure-abi-admitted)))
    (is (member found '(5376 5632))
        "the loaded library reports ~a, which is neither admitted version"
        (int:format-abi-version found))))

(define-native-test a-version-outside-the-set-is-refused
  ;; The rejection path is exercised for real by narrowing the admitted set, not
  ;; by trusting that it would work.
  ;; The expected version is read from the library rather than written down: this
  ;; test runs against each admitted ABI in turn, and a literal here would make it
  ;; a test of which library the runner happened to build.
  (let ((loaded (int:ensure-abi-admitted)))
    (let ((int::*admitted-abi-versions* '((1 . "0.0.1"))))
      (handler-case (progn (int:ensure-abi-admitted) (fail "an unadmitted ABI was accepted"))
        (xna:cna-abi-rejected-error (condition)
          (is (= loaded (xna:cna-abi-found-version condition)))
          (is (equal '(1) (xna:cna-abi-admitted-versions condition)))
          (is (string= (int:native-library-path) (xna:cna-native-library-path condition)))
          (let ((text (princ-to-string condition)))
            (is (search (int:native-library-path) text)
                "the rejection does not name the library")
            (is (search (int:format-abi-version loaded) text)
                "the rejection does not name the version found")
            (is (search "0.0.1" text) "the rejection does not name the admitted set")
            (is (search "CNA_NATIVE_LIBRARY" text)
                "the rejection does not say how to supply a qualified library")))))))

(define-native-test cffi-agrees-with-the-recorded-struct-layouts
  ;; Independent of the C probe: that one proves the recorded layout matches the
  ;; headers, this one proves the Lisp side matches the recorded layout.
  (int:ensure-abi-admitted)
  (let ((problems (int:verify-struct-layouts)))
    (is (null problems) "CFFI disagrees with the recorded ABI layout: ~s" problems)))

(define-native-test every-bound-route-resolves-in-the-loaded-library
  (int:ensure-abi-admitted)
  (let ((missing '()))
    (dolist (row ffi:*bound-native-functions*)
      (let ((name (first row)))
        (unless (ignore-errors (cffi:foreign-symbol-pointer name))
          (push name missing))))
    (is (null missing) "routes absent from the loaded library: ~s" missing)))

(define-native-test the-resolver-refuses-and-names-what-it-attempted
  ;; The resolver is deliberately unhelpful: it loads what the variable names and
  ;; searches nowhere else. Each refusal below is checked to name the exact path.
  (int:ensure-abi-admitted)
  (unwind-protect
       (progn
         ;; A path that does not exist.
         (let ((int::*native-library-path* nil)
               (int::*native-library-handle* nil))
           (sb-posix:setenv "CNA_NATIVE_LIBRARY" "/nonexistent/cna-lisp/libcna_c_api.so" 1)
           (handler-case (progn (int:ensure-native-library)
                                (fail "a nonexistent library path was accepted"))
             (xna:cna-native-library-error (condition)
               (is (string= "/nonexistent/cna-lisp/libcna_c_api.so"
                            (xna:cna-native-library-path condition)))
               (is (search "/nonexistent/cna-lisp/libcna_c_api.so"
                           (princ-to-string condition))
                   "the refusal does not name the path attempted"))))
         ;; A relative path, refused before anything is opened: which library got
         ;; loaded must not depend on where the process was started.
         (let ((int::*native-library-path* nil)
               (int::*native-library-handle* nil))
           (sb-posix:setenv "CNA_NATIVE_LIBRARY" "libcna_c_api.so" 1)
           (signals xna:cna-native-library-error (int:ensure-native-library)))
         ;; A directory is not a shared library.
         (let ((int::*native-library-path* nil)
               (int::*native-library-handle* nil))
           (sb-posix:setenv "CNA_NATIVE_LIBRARY" "/tmp" 1)
           (signals xna:cna-native-library-error (int:ensure-native-library)))
         ;; An empty variable is refused, and the refusal names the variable.
         (let ((int::*native-library-path* nil)
               (int::*native-library-handle* nil))
           (sb-posix:setenv "CNA_NATIVE_LIBRARY" "" 1)
           (handler-case (progn (int:ensure-native-library)
                                (fail "an empty library variable was accepted"))
             (xna:cna-native-library-error (condition)
               (is (search "CNA_NATIVE_LIBRARY" (princ-to-string condition)))))))
    (restore-qualified-library))
  (is (int:native-library-loaded-p))
  (is (string= *qualified-library-path* (int:native-library-path))))

;;; --- the host the flattening is correct for -------------------------------------------
;;;
;;; The by-value flattening in the generated foreign layer is the System V AMD64
;;; ABI's rule, and only that: CNA_Vector3 travels as a :double and a :float
;;; because that is what SysV does with two SSE eightbytes. The Microsoft x64 ABI
;;; passes a 12-byte aggregate by *reference*. So opening the native boundary on
;;; another host would not be an unqualified configuration -- it would be the
;;; wrong calling convention, putting arguments in the wrong registers with
;;; nothing to report it.
;;;
;;; The guard therefore sits at the boundary and nowhere earlier: everything in
;;; CNA-Lisp that touches no native route is ordinary ANSI Common Lisp.

(test the-qualified-host-is-recognised
  ;; This image is the qualified host, so the guard passes and says nothing.
  (is (null (int:qualified-host-mismatch))
      "the reference host reports a mismatch: ~a" (int:qualified-host-mismatch))
  (is-true (int:check-qualified-host "test"))
  ;; And it is reading the real image, not a stale constant.
  (let ((facts (int:host-facts)))
    (is (search "X86-64" (string-upcase (getf facts :machine))))
    (is (search "LINUX" (string-upcase (getf facts :software))))))

(test another-host-abi-is-refused-at-the-native-boundary
  ;; Each of the three facts, faked one at a time. The facts are injected rather
  ;; than the functions encapsulated: what is being tested is the decision, and an
  ;; encapsulation of MACHINE-TYPE is at the mercy of whether the compiler folded
  ;; the call.
  (dolist (case '((:machine "ARM64" "the machine")
                  (:software "Win32" "the operating system")
                  (:implementation "Clozure Common Lisp" "the implementation")))
    (destructuring-bind (key value what) case
      (let* ((facts (list :machine "X86-64" :software "Linux" :implementation "SBCL"))
             (int::*host-facts* (progn (setf (getf facts key) value) facts))
             (refusal (handler-case (progn (int:check-qualified-host "test") nil)
                        (xna:cna-not-supported-error (condition)
                          (princ-to-string condition)))))
        (is (stringp refusal) "a foreign ~a was not refused" what)
        (is (search "System V AMD64" refusal)
            "the refusal must say why this is a correctness matter and not a ~
             support matter: ~a" refusal))))
  ;; And the guard is on the path that opens the library, not merely available to
  ;; be called: with the resolver reset, ENSURE-NATIVE-LIBRARY must refuse before
  ;; it even looks at CNA_NATIVE_LIBRARY -- which is why this holds whether or not
  ;; a library was named for this run.
  (let* ((int::*host-facts* (list :machine "ARM64" :software "Linux"
                                  :implementation "SBCL"))
         (saved-path int::*native-library-path*)
         (saved-handle int::*native-library-handle*)
         (refusal (unwind-protect
                       (progn
                         (setf int::*native-library-path* nil
                               int::*native-library-handle* nil)
                         (handler-case (progn (int:ensure-native-library) nil)
                           (xna:cna-not-supported-error (condition)
                             (princ-to-string condition))))
                    (setf int::*native-library-path* saved-path
                          int::*native-library-handle* saved-handle))))
    (is (stringp refusal)
        "ENSURE-NATIVE-LIBRARY did not refuse on a host the flattening is not ~
         correct for")
    (is (search "x86-64" refusal))))
