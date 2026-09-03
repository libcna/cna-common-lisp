;;;; enums.lisp --- how CNA-Lisp represents XNA enumerations.
;;;;
;;;; One representation, used everywhere: **an enum member is a keyword**, and
;;;; each enum gets a Common Lisp type of that name plus three functions. Keywords
;;;; read naturally, cannot be confused with an unrelated enum's member of the
;;;; same numeric value, and let CHECK-TYPE do the checking. The exact numeric
;;;; values the ABI and the contract define are preserved -- privately, in the
;;;; tables below and in the generated ones -- and are reachable through the
;;;; conversion functions for the cases where the number is itself the contract.
;;;;
;;;; A flags enum is a *list* of keywords. The empty list is the named zero
;;;; member where the enum has one.
;;;;
;;;; DEFINE-XNA-ENUM is the single place this shape is defined, so no enum can
;;;; drift into representing itself differently. It is private: it lives in the
;;;; framework package but is not exported, and the graphics package reaches it
;;;; with a double colon.

(in-package #:microsoft.xna.framework)

(defmacro define-xna-enum (name table-form &key (documentation "") flags)
  "Define the Common Lisp projection of one XNA enumeration.

Defines the type NAME over its keywords, NAME-VALUE, NAME-FROM-VALUE and
ALL-NAME, interning each in the calling file's package. TABLE-FORM evaluates to
an alist of (KEYWORD . INTEGER) and is also bound to *NAME-TABLE*."
  (let* ((sname (symbol-name name))
         (table (intern (format nil "*~a-TABLE*" sname)))
         (value-fn (intern (format nil "~a-VALUE" sname)))
         (from-fn (intern (format nil "~a-FROM-VALUE" sname)))
         (all-fn (intern (format nil "ALL-~a" sname))))
    `(progn
       (defparameter ,table ,table-form ,(format nil "~a" documentation))
       (deftype ,name () ,(format nil "~a" documentation)
         '(member ,@(mapcar #'car (eval table-form))))
       (defun ,all-fn ()
         ,(format nil "Every member of ~a, as keywords, in value order." sname)
         (mapcar #'car ,table))
       (defun ,value-fn (member)
         ,(format nil "The exact value of a ~a member.~@[ ~a~]" sname
                  (when flags "A list of members combines their bits."))
         ,(if flags
              `(let ((members (if (listp member) member (list member))))
                 (reduce #'logior members :initial-value 0
                         :key (lambda (m)
                                (or (cdr (assoc m ,table))
                                    (error 'microsoft.xna.framework:cna-usage-error
                                           :operation ,(format nil "~a-value" sname)
                                           :format-control "~s is not a ~a member."
                                           :format-arguments (list m ,sname))))))
              `(or (cdr (assoc member ,table))
                   (error 'microsoft.xna.framework:cna-usage-error
                          :operation ,(format nil "~a-value" sname)
                          :format-control "~s is not a ~a member."
                          :format-arguments (list member ,sname)))))
       (defun ,from-fn (value)
         ,(format nil "The ~a member~:[~; list~] a value names." sname flags)
         ,(if flags
              `(if (zerop value)
                   (let ((zero (rassoc 0 ,table))) (if zero (list (car zero)) '()))
                   (let ((found '()))
                     (dolist (row ,table (nreverse found))
                       (unless (zerop (cdr row))
                         (when (= (cdr row) (logand value (cdr row)))
                           (push (car row) found))))))
              `(or (car (rassoc value ,table))
                   (error 'microsoft.xna.framework:cna-usage-error
                          :operation ,(format nil "~a-from-value" sname)
                          :format-control "~d is not a ~a value."
                          :format-arguments (list value ,sname)))))
       ',name)))
