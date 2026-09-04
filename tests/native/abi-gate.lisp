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
  ;; surface a compiler has checked.
  (int:ensure-abi-admitted)
  (is (= 1 (length (int:admitted-abi-versions))))
  (is (equal '(5376) (int:admitted-abi-versions))))

(define-native-test a-version-outside-the-set-is-refused
  ;; The rejection path is exercised for real by narrowing the admitted set, not
  ;; by trusting that it would work.
  (int:ensure-abi-admitted)
  (let ((int::*admitted-abi-versions* '((1 . "0.0.1"))))
    (handler-case (progn (int:ensure-abi-admitted) (fail "an unadmitted ABI was accepted"))
      (xna:cna-abi-rejected-error (condition)
        (is (= 5376 (xna:cna-abi-found-version condition)))
        (is (equal '(1) (xna:cna-abi-admitted-versions condition)))
        (is (string= (int:native-library-path) (xna:cna-native-library-path condition)))
        (let ((text (princ-to-string condition)))
          (is (search (int:native-library-path) text)
              "the rejection does not name the library")
          (is (search "0.21.0" text) "the rejection does not name the version found")
          (is (search "0.0.1" text) "the rejection does not name the admitted set")
          (is (search "CNA_NATIVE_LIBRARY" text)
              "the rejection does not say how to supply a qualified library"))))))

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
  ;; This image is the qualified host, so the guard must pass and say nothing.
  (is (null (int:qualified-host-mismatch))
      "the reference host reports a mismatch: ~a" (int:qualified-host-mismatch))
  (is-true (int:check-qualified-host "test")))

(test another-host-abi-is-refused-at-the-native-boundary
  ;; Each of the three facts the guard checks, faked one at a time. What is being
  ;; tested is that the guard *is* consulted and *does* refuse -- there is no way
  ;; to run this suite on a Windows x64 image to find out the honest way.
  (dolist (case (list (list "machine" (lambda () "ARM64") #'machine-type)
                      (list "operating system" (lambda () "Win32") #'software-type)))
    (destructuring-bind (what faked real) case
      (declare (ignore real))
      (let ((mismatch
              (handler-case
                  (progn
                    (if (string= what "machine")
                        (sb-int:encapsulate 'machine-type 'host-test
                                            (lambda (f &rest args)
                                              (declare (ignore f args))
                                              (funcall faked)))
                        (sb-int:encapsulate 'software-type 'host-test
                                            (lambda (f &rest args)
                                              (declare (ignore f args))
                                              (funcall faked))))
                    (unwind-protect
                         (handler-case (progn (int:check-qualified-host "test") nil)
                           (xna:cna-not-supported-error (condition)
                             (princ-to-string condition)))
                      (sb-int:unencapsulate (if (string= what "machine")
                                                'machine-type
                                                'software-type)
                                            'host-test)))
                (error (condition) (princ-to-string condition)))))
        (is (stringp mismatch) "a foreign ~a was not refused" what)
        (is (search "System V AMD64" mismatch)
            "the refusal must say why it is a correctness matter, not a support ~
             matter: ~a" mismatch))))
  ;; And the guard is on the path that opens the library, not merely available to
  ;; be called: with the resolver reset, ENSURE-NATIVE-LIBRARY itself must refuse
  ;; before it ever looks at CNA_NATIVE_LIBRARY.
  (let ((refusal
          (unwind-protect
               (progn
                 (sb-int:encapsulate 'machine-type 'host-test
                                     (lambda (f &rest args)
                                       (declare (ignore f args))
                                       "ARM64"))
                 (setf int::*native-library-path* nil
                       int::*native-library-handle* nil)
                 (handler-case (progn (int:ensure-native-library) nil)
                   (xna:cna-not-supported-error (condition)
                     (princ-to-string condition))))
            (progn (sb-int:unencapsulate 'machine-type 'host-test)
                   (restore-qualified-library)))))
    (is (stringp refusal)
        "ENSURE-NATIVE-LIBRARY loaded a library on a host the flattening is not ~
         correct for")
    (is (search "x86-64" refusal)))
  ;; The resolver is back, so the rest of the suite still has its library.
  (is-true (int:native-library-loaded-p)))
