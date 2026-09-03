;;;; named-colors.lisp --- XNA's predefined Color values.
;;;;
;;;; Each is a function of no arguments answering a fresh Color. XNA's are static
;;;; properties on a value type, so every read there is a copy too; a Lisp
;;;; constant bound to one shared structure would not be the same thing, because
;;;; a consumer that set R on it would change what every later read answered.
;;;;
;;;; The RGBA bytes come from the CNA C ABI's own named-colour table, which is
;;;; generated from the canonical headers -- see
;;;; src/framework/predefined-colors.generated.lisp.

(in-package #:microsoft.xna.framework)

(defun %predefined-color-bytes (keyword)
  (let ((row (assoc keyword cna-lisp.internal.framework:*predefined-colors*)))
    (unless row
      (error 'cna-usage-error
             :operation "predefined-color"
             :format-control "~s is not a predefined XNA colour name."
             :format-arguments (list keyword)))
    (rest row)))

(defun predefined-color (keyword)
  "A fresh Color for one of XNA's predefined colour names, given as a keyword."
  (destructuring-bind (r g b a) (%predefined-color-bytes keyword)
    (make-color r g b a)))

(defun predefined-color-names ()
  "Every predefined XNA colour name CNA-Lisp knows, as keywords."
  (mapcar #'first cna-lisp.internal.framework:*predefined-colors*))

(macrolet ((define-named-colors (&rest names)
             `(progn
                ,@(loop for name in names
                        collect
                        `(defun ,(intern (symbol-name name) '#:microsoft.xna.framework) ()
                           ,(format nil "Color.~:(~a~): a fresh Color each call."
                                    (substitute #\Space #\- (symbol-name name)))
                           (predefined-color ,(intern (symbol-name name) :keyword)))))))
  (define-named-colors
    #:cornflower-blue #:white #:black #:transparent #:red #:green #:blue
    #:yellow #:magenta #:cyan #:gray #:orange #:purple))
