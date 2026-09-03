;;;; enums.lisp --- how CNA-Lisp represents XNA enumerations.
;;;;
;;;; One representation, used everywhere: **an enum member is a keyword**, and
;;;; each enum gets a Common Lisp type of that name plus two conversion
;;;; functions. Keywords read naturally, cannot be confused with an unrelated
;;;; enum's member of the same numeric value, and let CHECK-TYPE do the checking.
;;;; The exact numeric values the ABI defines are preserved -- privately, in the
;;;; generated tables -- and are reachable through the conversion functions for
;;;; the cases where the number is itself part of the contract.
;;;;
;;;; A flags enum is a *list* of keywords. The empty list is the named zero
;;;; member where the enum has one.
;;;;
;;;; DEFINE-XNA-ENUM is the single place this shape is defined, so no enum can
;;;; drift into representing itself differently.

(in-package #:microsoft.xna.framework.graphics)

(defmacro define-xna-enum (name table-form &key (documentation "") flags)
  "Define the Common Lisp projection of one XNA enumeration.

Defines the type NAME over its keywords, NAME-VALUE, NAME-FROM-VALUE, and
ALL-NAME. TABLE-FORM evaluates to an alist of (KEYWORD . INTEGER)."
  (let* ((sname (symbol-name name))
         (table (intern (format nil "*~a-TABLE*" sname)))
         (value-fn (intern (format nil "~a-VALUE" sname)))
         (from-fn (intern (format nil "~a-FROM-VALUE" sname)))
         (all-fn (intern (format nil "ALL-~a" sname))))
    `(progn
       (defparameter ,table ,table-form)
       (deftype ,name () ,(format nil "~a" documentation)
         '(member ,@(mapcar #'car (eval table-form))))
       (defun ,all-fn ()
         ,(format nil "Every member of ~a, as keywords, in ABI value order." sname)
         (mapcar #'car ,table))
       (defun ,value-fn (member)
         ,(format nil "The exact ABI value of a ~a member.~@[ ~a~]" sname
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
         ,(format nil "The ~a member~:[~; list~] an ABI value names." sname flags)
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

(define-xna-enum sprite-sort-mode
  '((:deferred . 0) (:immediate . 1) (:texture . 2)
    (:back-to-front . 3) (:front-to-back . 4))
  :documentation "Microsoft.Xna.Framework.Graphics.SpriteSortMode.")

(define-xna-enum sprite-effects
  '((:none . 0) (:flip-horizontally . 1) (:flip-vertically . 2))
  :documentation "Microsoft.Xna.Framework.Graphics.SpriteEffects, a flags enum."
  :flags t)

(define-xna-enum surface-format
  (copy-alist cna-lisp.internal.ffi:*surface-format-table*)
  :documentation "Microsoft.Xna.Framework.Graphics.SurfaceFormat.")
