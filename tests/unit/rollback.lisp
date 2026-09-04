;;;; rollback.lisp --- the two rollback helpers, tested directly.
;;;;
;;;; These are correctness infrastructure now: `WITH-NATIVE-ROLLBACK' is what
;;;; makes a content load one transaction, and the construction ledger on
;;;; `NATIVE-OBJECT' is what makes a subclass initializer's failure cost nothing.
;;;; Everything else in this suite tests them *through* a resource, which proves
;;;; they work for that resource and not that they mean what they say.
;;;;
;;;; Pure, and deliberately: neither mechanism touches CNA. The thunks a rollback
;;;; runs are ordinary closures, and a NATIVE-OBJECT with no handle is an ordinary
;;;; CLOS object -- so these run in the no-library lane too, where a regression in
;;;; the machinery would otherwise be invisible.
;;;;
;;;; The two helpers want **opposite** things from a failing cleanup, and that
;;;; difference is the thing most likely to be lost in a later edit:
;;;;
;;;;   construction rollback   the body's condition wins; cleanup is quiet
;;;;   transient release       a release that fails after a body that *succeeded*
;;;;                           is news, and is reported
;;;;
;;;; The transient half needs CHECK-RESULT, which asks CNA for the text behind a
;;;; failing code, so it lives in tests/native/ownership.lisp. This file is the
;;;; half that can be pure.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

;;; --- WITH-NATIVE-ROLLBACK ---------------------------------------------------

(test a-rollback-that-finishes-undoes-nothing
  "A committed transaction runs no undo, and answers what the body answered --
all of its values, because a construction that answers two things must not be
narrowed to one on the way out."
  (let ((undone '()))
    (multiple-value-bind (first second)
        (int:with-native-rollback (record)
          (funcall record (lambda () (push :a undone)))
          (funcall record (lambda () (push :b undone)))
          (values :one :two))
      (is (eq :one first))
      (is (eq :two second)))
    (is (null undone) "a committed transaction undid ~a" undone)))

(test a-rollback-runs-every-recorded-undo-newest-first
  "Newest-first is leaf-first: a handle taken later is the child of one taken
earlier, and CNA refuses to destroy a parent while its child lives. An undo that
ran oldest-first would be refused half way through."
  (let ((undone '()))
    (signals error
      (int:with-native-rollback (record)
        (funcall record (lambda () (push :first undone)))
        (funcall record (lambda () (push :second undone)))
        (funcall record (lambda () (push :third undone)))
        (error "the body failed")))
    (is (equal '(:first :second :third) undone)
        "the undos ran in the order ~a" (reverse undone))))

(test a-rollback-undoes-only-the-steps-that-completed
  "The recorder is called after each step, so a step that never ran recorded
nothing and must not be undone."
  (let ((undone '()))
    (signals error
      (int:with-native-rollback (record)
        (funcall record (lambda () (push :taken undone)))
        (error "failed before the second step")
        (funcall record (lambda () (push :never-taken undone)))))
    (is (equal '(:taken) undone)
        "the rollback undid ~a" undone)))

(test each-recorded-undo-runs-exactly-once
  (let ((counts (make-hash-table)))
    (signals error
      (int:with-native-rollback (record)
        (dotimes (i 3)
          (let ((i i))
            (funcall record (lambda () (incf (gethash i counts 0))))))
        (error "the body failed")))
    (dotimes (i 3)
      (is (= 1 (gethash i counts 0))
          "undo ~d ran ~d time(s)" i (gethash i counts 0)))))

(test a-failing-undo-does-not-mask-the-condition-that-caused-the-rollback
  "The undo runs on the way out of a failure. A condition raised there would
*replace* the one worth reporting, which is how a diagnosable failure becomes an
unrelated one three frames later."
  (let ((later nil))
    (handler-case
        (int:with-native-rollback (record)
          (funcall record (lambda () (setf later t)))
          (funcall record (lambda () (error "the undo also failed")))
          (error 'xna:cna-usage-error :operation "test"
                                      :format-control "the original failure"))
      (xna:cna-usage-error (condition)
        (is (search "original failure" (princ-to-string condition))
            "a failing undo replaced the original condition with ~a" condition))
      (error (condition)
        (fail "a failing undo replaced the original condition with ~a" condition)))
    (is-true later
             "a failing undo stopped the rest of the ledger from running")))

(test a-rollback-recorder-answers-the-thunk-it-was-given
  (int:with-native-rollback (record)
    (let ((thunk (lambda () nil)))
      (is (eq thunk (funcall record thunk))))))

;;; --- the construction ledger on NATIVE-OBJECT -------------------------------
;;;
;;; A NATIVE-OBJECT with no handle needs no library, so the mechanism can be
;;; tested without one. What is being tested is the `:around' method: that it
;;; covers a *subclass's* `:after', which is the whole reason it exists and the
;;; one thing a per-class unwind-protect could not do.

(defclass ledger-probe (int:native-object)
  ((log :initarg :log :reader ledger-log))
  (:documentation "Records an undo during its own initializer."))

(defmethod initialize-instance :after ((object ledger-probe) &key)
  (let ((log (ledger-log object)))
    (int:record-construction-undo object (lambda () (push :base-undo (cdr log))))))

(defclass ledger-probe-subclass (ledger-probe) ())

(defmethod initialize-instance :after ((object ledger-probe-subclass) &key)
  (int:record-construction-undo object
                                (lambda () (push :subclass-undo (cdr (ledger-log object)))))
  (error "a subclass initializer signalled"))

(defclass quiet-subclass (ledger-probe) ())

(test a-committed-construction-undoes-nothing-and-drops-its-ledger
  (let* ((log (list :log))
         (object (make-instance 'quiet-subclass :log log)))
    (is (null (cdr log)) "a committed construction undid ~a" (cdr log))
    (is (null (int:construction-undo-of object))
        "a committed construction kept its ledger, so an undo could still be run")))

(test a-subclass-initializer-that-signals-undoes-the-base-classs-steps
  "The case the whole mechanism exists for. CLOS runs `:after' methods
least-specific-first, so the subclass's runs *after* the base class has taken
everything it takes. Undone newest-first, the subclass's own step goes back
before the base class's."
  (let ((log (list :log)))
    (signals error (make-instance 'ledger-probe-subclass :log log))
    (is (equal '(:base-undo :subclass-undo) (cdr log))
        "the undos ran as ~a" (reverse (cdr log)))))

(test a-construction-ledger-is-not-shared-between-instances
  "Each object's ledger is its own slot, so one failing construction cannot undo
another object's steps."
  (let* ((first-log (list :log))
         (survivor (make-instance 'quiet-subclass :log first-log))
         (second-log (list :log)))
    (signals error (make-instance 'ledger-probe-subclass :log second-log))
    (is (null (cdr first-log))
        "a failed construction undid another object's steps: ~a" (cdr first-log))
    (is-false (int:disposed-state-of survivor))))
