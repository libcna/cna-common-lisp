;;;; conditions.lisp --- the condition hierarchy, and what it does not expose.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

(test condition-hierarchy
  (dolist (name '(xna:cna-invalid-argument-error xna:cna-invalid-object-error
                  xna:cna-invalid-state-error xna:cna-out-of-memory-error
                  xna:cna-io-error xna:cna-not-supported-error
                  xna:cna-platform-error xna:cna-thread-error
                  xna:cna-callback-error xna:cna-overflow-error
                  xna:cna-encoding-error xna:cna-internal-error
                  xna:cna-shutting-down-error xna:cna-buffer-too-small-error))
    (is (subtypep name 'xna:cna-native-error) "~a is not a native error" name)
    (is (subtypep name 'xna:cna-error)))
  (dolist (name '(xna:cna-disposed-error xna:cna-ownership-error xna:cna-scope-error
                  xna:cna-native-library-error xna:cna-abi-rejected-error))
    (is (subtypep name 'xna:cna-usage-error) "~a is not a usage error" name))
  (is (subtypep 'xna:cna-error 'error)))

(test conditions-do-not-expose-a-result-code
  ;; The CNA result code is an ABI detail. It is kept privately so diagnostics
  ;; and tests can see it, and it is not a public reader.
  (let ((symbols '()))
    (do-external-symbols (symbol '#:microsoft.xna.framework)
      (when (search "RESULT" (symbol-name symbol)) (push symbol symbols)))
    (is (null symbols) "these exported symbols mention a result code: ~s" symbols)))

(test every-result-code-maps-to-a-condition-class
  ;; A code with no mapping would become a bare native error; none may be
  ;; missing, because a code CNA-Lisp cannot name is a code it cannot report.
  (dolist (code '(1 2 3 4 5 6 7 8 9 10 11 12 13 14))
    (is (not (null (cdr (assoc code int::*result-conditions*))))
        "CNA result ~d has no condition class" code)
    (is (not (eq :unknown (int:result-name code)))
        "CNA result ~d has no name" code)))

(test success-is-not-an-error
  (is (eq :success (int:result-name 0)))
  (is (null (assoc 0 int::*result-conditions*))))

(test a-condition-reports-its-operation-and-object
  (let ((condition (make-condition 'xna:cna-invalid-state-error
                                   :operation "draw" :object-type 'xna:game
                                   :native-message "the device is not ready")))
    (is (string= "draw" (xna:cna-error-operation condition)))
    (is (eq 'xna:game (xna:cna-error-object-type condition)))
    (is (search "the device is not ready" (princ-to-string condition)))
    (is (search "GAME" (princ-to-string condition)))))

(test a-callback-error-keeps-the-original-condition
  ;; The whole point of containment: the condition object survives, it is not
  ;; flattened into a string.
  (let* ((original (make-condition 'simple-error
                                   :format-control "the original condition"))
         (wrapper (make-condition 'xna:cna-callback-error
                                  :operation "update"
                                  :underlying-condition original)))
    (is (eq original (xna:cna-callback-underlying-condition wrapper)))
    (is (search "the original condition" (princ-to-string wrapper)))))

(test the-abi-rejection-names-the-admitted-set
  (let ((condition (make-condition 'xna:cna-abi-rejected-error
                                   :found-version 1792
                                   :admitted-versions '(5376)
                                   :native-library-path "/tmp/whatever.so"
                                   :format-control "~a ~a ~a ~a ~a"
                                   :format-arguments (list "/tmp/whatever.so" "0.7.0" 1792
                                                           '("0.21.0") "CNA_NATIVE_LIBRARY"))))
    (is (= 1792 (xna:cna-abi-found-version condition)))
    (is (equal '(5376) (xna:cna-abi-admitted-versions condition)))
    (is (string= "/tmp/whatever.so" (xna:cna-native-library-path condition)))))

(test abi-version-encoding-round-trips
  (is (= 5376 (int:encode-abi-version 0 21 0)))
  (is (= 1792 (int:encode-abi-version 0 7 0)))
  (is (string= "0.21.0" (int:format-abi-version 5376)))
  (is (string= "0.7.0" (int:format-abi-version 1792)))
  (multiple-value-bind (major minor patch) (int:decode-abi-version 5376)
    (is (= 0 major)) (is (= 21 minor)) (is (= 0 patch))))
