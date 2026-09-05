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

;;; --- the two cleanup shapes, and why they differ ----------------------------
;;;
;;; Construction wants a *quiet* undo: the condition that caused the rollback is
;;; the one worth reporting. A transient handle wants the opposite: if the work
;;; succeeded and CNA then refuses the handle back, nothing else will say so.

(test a-rollback-undoes-what-completed-newest-first
  (let ((log '()))
    (signals simple-error
      (int:with-native-rollback (record)
        (push :one log)
        (funcall record (lambda () (push :undo-one log)))
        (push :two log)
        (funcall record (lambda () (push :undo-two log)))
        (error "the step after two")))
    (is (equal '(:undo-one :undo-two :two :one) log)
        "the undo must run newest-first, which is leaf-first; the log is ~s"
        (reverse log))))

(test a-rollback-that-finishes-undoes-nothing
  (let ((log '()))
    (is (eq :value
            (int:with-native-rollback (record)
              (funcall record (lambda () (push :undone log)))
              :value)))
    (is (null log) "a construction that committed must undo nothing")))

(test a-rollback-does-not-mask-the-condition-that-caused-it
  "The undo runs on the way out of a failure. A condition raised there would
replace the one the caller needs to see, so the undo is quiet."
  (handler-case
      (int:with-native-rollback (record)
        (funcall record (lambda () (error "the undo blew up")))
        (error 'xna:cna-usage-error :operation "test"
                                    :format-control "the original failure"))
    (xna:cna-usage-error (condition)
      (is (search "original failure" (princ-to-string condition))
          "the caller saw ~a instead of the original failure" condition))
    (error (condition)
      (fail "a failing undo replaced the original condition with ~a" condition))))

;;; The two release-failure cases need a real library: CHECK-RESULT asks CNA for
;;; its diagnostic text, so a non-success code cannot be built without one. They
;;; are in tests/native/ownership.lisp.

(test a-transient-handle-answers-the-bodys-values
  (is (equal '(1 2 3)
             (multiple-value-list
              (int:with-transient-native (int::+result-success+ "test")
                (values 1 2 3))))))

;;; --- the CLR three-constructor set, and where its second argument goes -------

(test the-two-audio-exception-types-express-all-three-clr-constructors
  "`NoAudioHardwareException' and `InstancePlayLimitException' each declare
`new()', `new(String)' and `new(String, Exception)', and all three collapse onto
MAKE-CONDITION. The collapse is only honest if each one's arguments have
somewhere to go, and the third one's second argument did not until CNA-ERROR
gained a CAUSE slot: the reason used to say the inner exception \"is the condition
a handler already has in scope\", which is a statement about the dynamic
environment rather than about the argument.

`System.Exception' is not projected as a type -- it is the base-class library's,
and a Common Lisp condition is what it projects onto, the same rule
`System.IO.Stream' is read under -- so CAUSE holds a condition."
  (dolist (class '(audio:no-audio-hardware-error audio:instance-play-limit-error))
    ;; new()
    (let ((bare (make-condition class)))
      (is (null (xna:cna-error-cause bare)) "new() carries no cause")
      (is (plusp (length (princ-to-string bare)))
          "and still reports something a program can print"))
    ;; new(String)
    (let ((with-message (make-condition class :format-control "a message")))
      (is (search "a message" (princ-to-string with-message)))
      (is (null (xna:cna-error-cause with-message))))
    ;; new(String, Exception)
    (let* ((inner (make-condition 'simple-error
                                  :format-control "the native call failed"))
           (wrapped (make-condition class :format-control "outer"
                                          :cause inner)))
      (is (eq inner (xna:cna-error-cause wrapped))
          "the inner exception is the condition itself, not a string made from it")
      (is (search "the native call failed"
                  (princ-to-string (xna:cna-error-cause wrapped)))))))

(test every-cna-condition-can-carry-a-cause
  "CAUSE is on CNA-ERROR rather than on the two audio classes, because the CLR
puts `innerException' on `System.Exception' and every exception this binding
projects inherits it. Putting it on the leaves would have made the two audio
types special for a reason that is not theirs."
  (let ((inner (make-condition 'simple-error :format-control "inner")))
    (dolist (class '(xna:cna-invalid-state-error xna:cna-argument-error
                     xna:cna-not-supported-error xna:cna-usage-error))
      (is (eq inner (xna:cna-error-cause
                     (make-condition class :operation "x" :cause inner)))
          "~a cannot carry a cause" class))))
