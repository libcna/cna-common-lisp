;;;; dump-surface.lisp --- write the live public surface of CNA-Lisp as JSON.
;;;;
;;;; Introspection, not a hand-maintained register: whatever the image actually
;;;; exports is what gets written. tools/api-compat/verify.py then compares this
;;;; against the pinned XNA contract.
;;;;
;;;;   sbcl --script tools/api-compat/dump-surface.lisp [output.json]

(require :asdf)
(require :sb-introspect)

(let ((quicklisp (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (when (probe-file quicklisp) (load quicklisp)))

(defparameter cl-user::*cna-lisp-root*
  (truename (merge-pathnames "../../" (directory-namestring *load-truename*))))
(push cl-user::*cna-lisp-root* asdf:*central-registry*)

(asdf:load-system "cna-common-lisp")

(defpackage #:cna-lisp.surface-dump (:use #:cl))
(in-package #:cna-lisp.surface-dump)

(defparameter *packages*
  '("MICROSOFT.XNA.FRAMEWORK"
    "MICROSOFT.XNA.FRAMEWORK.GRAPHICS"
    "MICROSOFT.XNA.FRAMEWORK.GRAPHICS.PACKED-VECTOR"
    "MICROSOFT.XNA.FRAMEWORK.INPUT"
    "MICROSOFT.XNA.FRAMEWORK.INPUT.TOUCH"))

;;; --- a very small JSON writer -------------------------------------------
;;; CNA-Lisp has no JSON dependency and does not need one for this.

(defun json-escape (string)
  (with-output-to-string (out)
    (loop for character across string
          do (case character
               (#\" (write-string "\\\"" out))
               (#\\ (write-string "\\\\" out))
               (#\Newline (write-string "\\n" out))
               (#\Tab (write-string "\\t" out))
               (#\Return (write-string "\\r" out))
               (t (if (< (char-code character) 32)
                      (format out "\\u~4,'0x" (char-code character))
                      (write-char character out)))))))

(defun write-json (value stream &optional (indent 0))
  (let ((pad (make-string (* 2 indent) :initial-element #\Space)))
    (etypecase value
      (null (write-string "null" stream))
      ((member t) (write-string "true" stream))
      ((member :false) (write-string "false" stream))
      (string (format stream "\"~a\"" (json-escape value)))
      (symbol (format stream "\"~a\"" (json-escape (string-downcase (symbol-name value)))))
      (integer (format stream "~d" value))
      (cons
       (if (eq (car value) :object)
           (let ((pairs (cdr value)))
             (if (null pairs)
                 (write-string "{}" stream)
                 (progn
                   (format stream "{~%")
                   (loop for (entry . rest) on pairs
                         do (format stream "~a  \"~a\": " pad
                                    (json-escape (string (car entry))))
                            (write-json (cdr entry) stream (1+ indent))
                            (format stream "~:[~;,~]~%" rest))
                   (format stream "~a}" pad))))
           (let ((items (if (eq (car value) :array) (cdr value) value)))
             (if (null items)
                 (write-string "[]" stream)
                 (progn
                   (format stream "[~%")
                   (loop for (item . rest) on items
                         do (format stream "~a  " pad)
                            (write-json item stream (1+ indent))
                            (format stream "~:[~;,~]~%" rest))
                   (format stream "~a]" pad)))))))))

(defmacro object (&rest pairs)
  `(list* :object (list ,@(loop for (key value) on pairs by #'cddr
                                collect `(cons ,key ,value)))))

;;; --- surface description --------------------------------------------------

(defun lambda-list-of (name)
  (handler-case
      (mapcar (lambda (item) (string-downcase (princ-to-string item)))
              (sb-introspect:function-lambda-list name))
    (error () nil)))

(defun qualified-name (symbol)
  (string-downcase (format nil "~a:~a"
                           (package-name (symbol-package symbol))
                           (symbol-name symbol))))

(defun keyword-names (lambda-list)
  "The &key parameter names of one lambda list, as strings."
  (let ((tail (member '&key lambda-list)))
    (loop for item in (rest tail)
          until (member item lambda-list-keywords)
          collect (string-downcase
                   (princ-to-string (if (consp item)
                                        (if (consp (first item))
                                            (second (first item))
                                            (first item))
                                        item))))))

(defun effective-keywords (name)
  "Every keyword the generic function NAME accepts, across all its methods.

A DEFGENERIC lambda list says `&key' and stops; the keywords live on the methods.
A verifier that checked the generic function's own lambda list would conclude
that a keyword-taking projection accepts no keywords at all."
  (handler-case
      (let ((function (and (fboundp name) (fdefinition name))))
        (if (typep function 'generic-function)
            (sort (remove-duplicates
                   (loop for method in (sb-mop:generic-function-methods function)
                         append (keyword-names (sb-mop:method-lambda-list method)))
                   :test #'string=)
                  #'string<)
            (sort (keyword-names (sb-introspect:function-lambda-list name)) #'string<)))
    (error () nil)))

(defun class-precedence (class)
  (handler-case
      (progn
        (unless (sb-mop:class-finalized-p class) (sb-mop:finalize-inheritance class))
        (mapcar (lambda (c) (qualified-name (class-name c)))
                (sb-mop:class-precedence-list class)))
    (error () nil)))

(defun describe-symbol (symbol)
  (let* ((class (find-class symbol nil))
         (structure-p (and class (typep class 'structure-class)))
         (condition-p (and class (subtypep symbol 'condition)))
         (generic-p (and (fboundp symbol) (typep (fdefinition symbol) 'generic-function)))
         (setf-name (list 'setf symbol)))
    (object
     "name" (string-downcase (symbol-name symbol))
     "fbound" (if (fboundp symbol) t :false)
     "macro" (if (macro-function symbol) t :false)
     "generic" (if generic-p t :false)
     "lambda_list" (or (and (fboundp symbol) (not (macro-function symbol))
                            (lambda-list-of symbol))
                       '(:array))
     "keywords" (or (and (fboundp symbol) (not (macro-function symbol))
                         (effective-keywords symbol))
                    '(:array))
     "setf_fbound" (if (fboundp setf-name) t :false)
     "setf_lambda_list" (or (and (fboundp setf-name) (lambda-list-of setf-name)) '(:array))
     "class" (if class t :false)
     "structure" (if structure-p t :false)
     "condition" (if condition-p t :false)
     "metaclass" (if class
                     (string-downcase (princ-to-string (class-name (class-of class))))
                     nil)
     "precedence" (or (and class (class-precedence class)) '(:array))
     "type" (if (or class (documentation symbol 'type)) t :false)
     "constant" (if (and (boundp symbol) (constantp symbol)) t :false)
     "value" (if (and (boundp symbol) (constantp symbol) (integerp (symbol-value symbol)))
                 (symbol-value symbol)
                 nil)
     "documentation" (or (documentation symbol 'function)
                         (documentation symbol 'type)
                         (documentation symbol 'variable)
                         nil))))

(defun package-surface (name)
  (let ((symbols '()))
    (do-external-symbols (symbol (find-package name))
      (push symbol symbols))
    (object
     "package" (string-downcase name)
     "symbols" (mapcar #'describe-symbol
                       (sort symbols #'string< :key #'symbol-name)))))

(defun alist-object (alist)
  (list* :object (mapcar (lambda (row)
                           (cons (string-downcase (symbol-name (car row))) (cdr row)))
                         alist)))

(defun enum-tables ()
  (object
   "keys" (alist-object microsoft.xna.framework.input::*keys-table*)
   "key-state" (alist-object microsoft.xna.framework.input::*key-state-table*)
   "player-index" (alist-object microsoft.xna.framework::*player-index-table*)
   "button-state" (alist-object microsoft.xna.framework.input::*button-state-table*)
   "buttons" (alist-object microsoft.xna.framework.input::*buttons-table*)
   "game-pad-type" (alist-object microsoft.xna.framework.input::*game-pad-type-table*)
   "game-pad-dead-zone"
   (alist-object microsoft.xna.framework.input::*game-pad-dead-zone-table*)
   "display-orientation"
   (alist-object microsoft.xna.framework::*display-orientation-table*)
   "touch-location-state"
   (alist-object microsoft.xna.framework.input.touch::*touch-location-state-table*)
   "gesture-type"
   (alist-object microsoft.xna.framework.input.touch::*gesture-type-table*)
   "sprite-sort-mode" (alist-object microsoft.xna.framework.graphics::*sprite-sort-mode-table*)
   "sprite-effects" (alist-object microsoft.xna.framework.graphics::*sprite-effects-table*)
   "surface-format" (alist-object microsoft.xna.framework.graphics::*surface-format-table*)
   "containment-type" (alist-object microsoft.xna.framework::*containment-type-table*)
   "plane-intersection-type"
   (alist-object microsoft.xna.framework::*plane-intersection-type-table*)
   "curve-continuity" (alist-object microsoft.xna.framework::*curve-continuity-table*)
   "curve-loop-type" (alist-object microsoft.xna.framework::*curve-loop-type-table*)
   "curve-tangent" (alist-object microsoft.xna.framework::*curve-tangent-table*)
   "blend" (alist-object microsoft.xna.framework.graphics::*blend-table*)
   "blend-function" (alist-object microsoft.xna.framework.graphics::*blend-function-table*)
   "color-write-channels"
   (alist-object microsoft.xna.framework.graphics::*color-write-channels-table*)
   "compare-function"
   (alist-object microsoft.xna.framework.graphics::*compare-function-table*)
   "stencil-operation"
   (alist-object microsoft.xna.framework.graphics::*stencil-operation-table*)
   "cull-mode" (alist-object microsoft.xna.framework.graphics::*cull-mode-table*)
   "fill-mode" (alist-object microsoft.xna.framework.graphics::*fill-mode-table*)
   "texture-address-mode"
   (alist-object microsoft.xna.framework.graphics::*texture-address-mode-table*)
   "texture-filter"
   (alist-object microsoft.xna.framework.graphics::*texture-filter-table*)
   "vertex-element-format"
   (alist-object microsoft.xna.framework.graphics::*vertex-element-format-table*)
   "vertex-element-usage"
   (alist-object microsoft.xna.framework.graphics::*vertex-element-usage-table*)
   "buffer-usage" (alist-object microsoft.xna.framework.graphics::*buffer-usage-table*)
   "index-element-size"
   (alist-object microsoft.xna.framework.graphics::*index-element-size-table*)
   "set-data-options"
   (alist-object microsoft.xna.framework.graphics::*set-data-options-table*)
   "primitive-type"
   (alist-object microsoft.xna.framework.graphics::*primitive-type-table*)
   "effect-parameter-class"
   (alist-object microsoft.xna.framework.graphics::*effect-parameter-class-table*)
   "effect-parameter-type"
   (alist-object microsoft.xna.framework.graphics::*effect-parameter-type-table*)))

(defun extensions ()
  (mapcar (lambda (entry)
            (object "package" (string-downcase (symbol-name (first entry)))
                    "symbols" (mapcar (lambda (s) (string-downcase (symbol-name s)))
                                      (butlast (rest entry)))
                    "reason" (car (last entry))))
          cna-lisp.internal::*binding-extensions*))

(defun absences ()
  (mapcar (lambda (entry)
            (object "subject" (or (getf entry :type) (getf entry :member))
                    "kind" (if (getf entry :type) "type" "member")
                    "status" (string-downcase (symbol-name (getf entry :status)))
                    "reason_code" (getf entry :reason-code)
                    "reason" (getf entry :reason)))
          cna-lisp.internal::*declared-absences*))

(defun main ()
  (let* ((argument (second sb-ext:*posix-argv*))
         (path (or argument
                   (merge-pathnames "docs/generated/public-surface.json"
                                    cl-user::*cna-lisp-root*))))
    (ensure-directories-exist path)
    (with-open-file (stream path :direction :output :if-exists :supersede)
      (write-json
       (object
        "schema_version" 1
        ;; The implementation *family*, not this build of it. The projection is
        ;; a property of the source, and the dump is byte-identical across SBCL
        ;; builds -- measured across 2.2.9, 2.5.2 and 2.5.2.debian. Writing the
        ;; exact version here would make a committed report describe one
        ;; machine, and every other machine's freshness gate would then fail on
        ;; a difference that says nothing. The version is a fact about the run,
        ;; and the run prints it below.
        "implementation" (lisp-implementation-type)
        "system_version" (asdf:component-version (asdf:find-system "cna-common-lisp"))
        "packages" (mapcar #'package-surface *packages*)
        "enum_tables" (enum-tables)
        "predefined_colors" (mapcar (lambda (k) (string-downcase (symbol-name k)))
                                    (microsoft.xna.framework:predefined-color-names))
        "declared_extensions" (extensions)
        "declared_absences" (absences))
       stream)
      (terpri stream))
    (format t "~&wrote ~a~%  dumped by ~a ~a on ~a~%"
            (namestring path)
            (lisp-implementation-type) (lisp-implementation-version)
            (machine-type))))

(main)
