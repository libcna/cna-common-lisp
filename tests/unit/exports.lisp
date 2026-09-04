;;;; exports.lisp --- every exported symbol must name something.
;;;;
;;;; The structural verifier compares the *public* packages against the pinned
;;;; XNA contract, so a public symbol that names nothing is caught there as an
;;;; `unexpected_public_symbol'. Nothing was watching the internal packages, and
;;;; that is where the one real instance turned up: `WITH-STRING-VIEW-ARGS' sat
;;;; in CNA-LISP.INTERNAL's export list with no macro, function, variable, class
;;;; or type behind it -- a name that read like a helper and was not one.
;;;;
;;;; Exporting an undefined symbol is legal Common Lisp: the export creates the
;;;; symbol and the reader is then happy to accept `package:name' at every call
;;;; site, which is exactly what makes the mistake survive. It fails at run time,
;;;; in whichever caller reached it first.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

(defparameter *cna-lisp-packages*
  '("MICROSOFT.XNA.FRAMEWORK"
    "MICROSOFT.XNA.FRAMEWORK.GRAPHICS"
    "MICROSOFT.XNA.FRAMEWORK.GRAPHICS.PACKED-VECTOR"
    "MICROSOFT.XNA.FRAMEWORK.CONTENT"
    "MICROSOFT.XNA.FRAMEWORK.INPUT"
    "MICROSOFT.XNA.FRAMEWORK.INPUT.TOUCH"
    "CNA-LISP.INTERNAL"
    "CNA-LISP.INTERNAL.FFI")
  "Every package CNA-Lisp defines, public and internal alike.")

(defun %symbol-names-something-p (symbol)
  "True when SYMBOL has any definition a caller could reach.

Deliberately generous: a function, a macro, a special variable or constant, a
class, a type, or a SETF expander. The question is whether the name means
anything at all, not which kind of thing it means."
  (or (fboundp symbol)
      (macro-function symbol)
      (boundp symbol)
      (find-class symbol nil)
      (sb-int:info :type :kind symbol)
      (sb-int:info :setf :expander symbol)))

(test every-exported-symbol-names-something
  (let ((dangling '()))
    (dolist (name *cna-lisp-packages*)
      (let ((package (find-package name)))
        (is-true package "~a is not defined" name)
        (when package
          (do-external-symbols (symbol package)
            ;; Only symbols this package owns: a re-exported symbol is the
            ;; defining package's business, and checking it here would report the
            ;; same name twice.
            (when (and (eq (symbol-package symbol) package)
                       (not (%symbol-names-something-p symbol)))
              (push (format nil "~a:~a" name (symbol-name symbol)) dangling))))))
    (is-false dangling
        "~d exported symbol(s) name nothing at all: ~{~a~^, ~}. Exporting an ~
         undefined symbol is legal, so the reader accepts every call site that ~
         uses one and the failure arrives at run time instead."
        (length dangling) (nreverse dangling))))
