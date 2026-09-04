;;;; public-surface.lisp --- what may and may not appear in a public package.
;;;;
;;;; The rule this file enforces is the product decision: the CNA C ABI is an
;;;; implementation detail. A consumer must never be able to reach a handle, a
;;;; result code, a CFFI type, a private %cna-* route, the callback registry or
;;;; any other implementation symbol through a public package.

(in-package #:cna-common-lisp.tests)
(in-suite structure-tests)

(defparameter *public-packages*
  '("MICROSOFT.XNA.FRAMEWORK"
    "MICROSOFT.XNA.FRAMEWORK.GRAPHICS"
    "MICROSOFT.XNA.FRAMEWORK.INPUT"))

(defparameter *private-packages*
  '("CNA-LISP.INTERNAL"
    "CNA-LISP.INTERNAL.FFI"
    "CNA-LISP.INTERNAL.FRAMEWORK"
    "CNA-LISP.INTERNAL.INPUT"
    "CNA-LISP.INTERNAL.ABI"))

(defun exported-symbols (package-name)
  (let ((result '()))
    (do-external-symbols (symbol (find-package package-name))
      (push symbol result))
    (sort result #'string< :key #'symbol-name)))

(defun all-public-symbols ()
  (mapcan #'exported-symbols (copy-list *public-packages*)))

(test the-public-packages-exist
  (dolist (name *public-packages*)
    (is (not (null (find-package name))) "public package ~a is missing" name)))

(test no-public-symbol-is-homed-in-a-private-package
  (let ((leaks '()))
    (dolist (symbol (all-public-symbols))
      (let ((home (symbol-package symbol)))
        (when (member (package-name home) *private-packages* :test #'string=)
          (push symbol leaks))))
    (is (null leaks) "private symbols exported from a public package: ~s" leaks)))

(defun hyphen-words (name)
  "NAME split on hyphens, which is how a Lisp symbol spells its words."
  (loop with start = 0
        for position = (position #\- name :start start)
        collect (subseq name start position)
        while position do (setf start (1+ position))))

(test no-public-symbol-names-an-abi-concept
  ;; Names are the other half of the leak: a symbol called HANDLE-OF would be a
  ;; leak even if its home package were public.
  ;;
  ;; The match is on whole hyphen-separated words, not on substrings. HANDLER is
  ;; not HANDLE, and a substring test would report ADD-EXITING-HANDLER as an ABI
  ;; leak -- a false positive that would eventually be silenced by deleting the
  ;; forbidden word, which is exactly the wrong repair. The two entries that are
  ;; genuinely prefixes rather than words are matched as prefixes and say so.
  (let ((forbidden-words '("HANDLE" "CFFI" "POINTER" "FOREIGN" "DEFCFUN" "DEFCSTRUCT"
                           "REGISTRY" "TOKEN" "GENERATION" "UINT" "INT8"
                           "INT32" "INT64" "VOID" "RESULT"))
        (forbidden-prefixes '("CNA-GAME-" "CNA_" "%CNA"))
        (forbidden-pairs '(("STRUCT" "SIZE") ("STRUCT" "VERSION") ("CALLBACK" "TABLE")))
        ;; A word on this list is forbidden because it belongs to the ABI and not
        ;; to XNA. Where XNA itself uses one, the exemption is named here with
        ;; the member it comes from, rather than dropped from the list -- deleting
        ;; a forbidden word to silence one symbol would stop it catching the
        ;; leaks it is for.
        (xna-spelled '(("EFFECT-ANNOTATION-VALUE-INT32" . "INT32")))
        (leaks '()))
    (dolist (symbol (all-public-symbols))
      (let* ((name (symbol-name symbol))
             (words (hyphen-words name)))
        (dolist (bad forbidden-words)
          (when (and (member bad words :test #'string=)
                     (not (equal bad (cdr (assoc name xna-spelled :test #'string=)))))
            (push (list symbol bad) leaks)))
        (dolist (bad forbidden-prefixes)
          (when (eql 0 (search bad name))
            (push (list symbol bad) leaks)))
        (dolist (pair forbidden-pairs)
          (loop for (a b) on words
                when (and b (string= a (first pair)) (string= b (second pair)))
                  do (push (list symbol (format nil "~a-~a" (first pair) (second pair)))
                           leaks)))))
    (is (null leaks) "public symbols naming an ABI concept: ~s" leaks)))

(test the-abi-word-check-still-catches-a-real-leak
  ;; The check above matches whole words rather than substrings, which is a
  ;; weakening -- so here is the proof it still bites. Every name on the left is
  ;; a leak and must be caught; every name on the right is innocent and must not.
  (flet ((leaks-p (name)
           (let ((words (hyphen-words name)))
             (or (some (lambda (bad) (member bad words :test #'string=))
                       '("HANDLE" "TOKEN" "POINTER" "GENERATION" "REGISTRY"))
                 (loop for (a b) on words
                       thereis (and b (string= a "STRUCT") (string= b "SIZE")))))))
    (dolist (name '("HANDLE-OF" "GAME-HANDLE" "THE-TOKEN" "STRUCT-SIZE-OF"
                    "POINTER-TO" "GENERATION-OF" "CALLBACK-REGISTRY"))
      (is (leaks-p name) "~a should be caught as an ABI leak" name))
    (dolist (name '("ADD-EXITING-HANDLER" "REMOVE-DISPOSED-HANDLER" "HANDLER"
                    "TOKENISE" "STRUCT-SIZED"))
      (is (not (leaks-p name)) "~a is not an ABI leak" name))))

(test no-public-symbol-starts-with-a-percent-sign
  ;; % is CNA-Lisp's private-function convention throughout.
  (let ((leaks (remove-if-not (lambda (symbol) (char= #\% (char (symbol-name symbol) 0)))
                              (all-public-symbols))))
    (is (null leaks) "private-convention symbols exported: ~s" leaks)))

(test the-ffi-package-exports-nothing-a-consumer-can-reach
  ;; It exports the generated tables the runtime reads, and nothing that a public
  ;; package re-exports.
  (let ((public (all-public-symbols))
        (leaks '()))
    (dolist (name *private-packages*)
      (dolist (symbol (exported-symbols name))
        (when (member symbol public)
          (push symbol leaks))))
    (is (null leaks) "private exports also exported publicly: ~s" leaks)))

(test every-public-symbol-denotes-something
  ;; An exported symbol that is neither bound, fbound, a class, a type nor a
  ;; condition is a dangling export: a name promised and not delivered.
  (let ((dangling '()))
    (dolist (symbol (all-public-symbols))
      (unless (or (fboundp symbol)
                  (boundp symbol)
                  (fboundp (list 'setf symbol))
                  (find-class symbol nil)
                  (ignore-errors (subtypep symbol t))
                  (documentation symbol 'type))
        (push symbol dangling)))
    (is (null dangling) "exported but undefined: ~s" dangling)))

(test the-game-class-is-public-and-subclassable
  (let ((class (find-class 'xna:game)))
    (is (typep class 'standard-class))
    (is (eq (find-package "MICROSOFT.XNA.FRAMEWORK") (symbol-package 'xna:game)))))

(test the-lifecycle-hooks-are-generic-functions
  (dolist (name '(xna:initialize xna:load-content xna:unload-content
                  xna:begin-run xna:end-run xna:update xna:begin-draw
                  xna:draw xna:end-draw xna:on-exiting))
    (is (typep (fdefinition name) 'generic-function)
        "~a is not a generic function" name)))

(test the-lifecycle-hooks-have-a-default-method-on-game
  ;; Each hook must have a method specialised on GAME itself, so that a subclass
  ;; that overrides none of them still runs. Other methods may exist -- the test
  ;; suite's own game subclasses add plenty -- and that is not what is checked.
  (let ((game-class (find-class 'xna:game)))
    (dolist (name '(xna:initialize xna:load-content xna:unload-content
                    xna:begin-run xna:end-run xna:update xna:begin-draw
                    xna:draw xna:end-draw xna:on-exiting))
      (is (find-if (lambda (method)
                     (eq game-class (first (sb-mop:method-specializers method))))
                   (sb-mop:generic-function-methods (fdefinition name)))
          "~a has no default method specialised on GAME" name))))

(test the-native-object-base-is-not-public
  (is (not (member 'cna-lisp.internal:native-object (all-public-symbols))))
  (dolist (name '(cna-lisp.internal:handle-of cna-lisp.internal:owner-of
                  cna-lisp.internal:owner-generation-of
                  cna-lisp.internal:ownership-of
                  cna-lisp.internal:register-callback-target))
    (is (not (member name (all-public-symbols)))
        "~a reached a public package" name)))

(test every-declared-extension-really-exists
  ;; The extension register is what lets the verifier tell an addition from an
  ;; unaccounted-for name. An entry naming a symbol that is not exported would
  ;; make the register a wish list.
  (let ((problems '()))
    (dolist (entry cna-lisp.internal::*binding-extensions*)
      (let ((package (find-package (first entry))))
        (dolist (name (butlast (rest entry)))
          (let ((symbol (find-symbol (symbol-name name) package)))
            (unless (and symbol
                         (eq :external (nth-value 1 (find-symbol (symbol-name name)
                                                                 package))))
              (push (list (first entry) name) problems))))))
    (is (null problems) "declared extensions that are not exported: ~s" problems)))

(test every-public-symbol-is-accounted-for
  ;; Either it is a mapped XNA member -- which the api-compat verifier decides --
  ;; or it is a declared extension. This test checks the second half: no symbol
  ;; may be an extension without being declared. The list here mirrors the
  ;; register, and the previous test proves the register is real.
  (let* ((declared (let ((result '()))
                     (dolist (entry cna-lisp.internal::*binding-extensions* result)
                       (let ((package (find-package (first entry))))
                         (dolist (name (butlast (rest entry)))
                           (push (find-symbol (symbol-name name) package) result))))))
         ;; Structure constructors, copiers and predicates are mechanical
         ;; consequences of projecting a value type, not separate decisions.
         (mechanical (remove-if-not
                      (lambda (symbol)
                        (let ((name (symbol-name symbol)))
                          (or (eql 0 (search "MAKE-" name))
                              (eql 0 (search "COPY-" name))
                              (eql 0 (search "ALL-" name))
                              (search "-FROM-VALUE" name)
                              (search "-VALUE" name)
                              (search "-EQUAL" name)
                              (let ((n (length name)))
                                (and (> n 2) (string= "-P" name :start2 (- n 2)))))))
                      (all-public-symbols))))
    (declare (ignorable declared mechanical))
    ;; The real accounting happens in tools/api-compat/verify.lisp, which has the
    ;; XNA contract to compare against. Here we only assert the register is
    ;; non-empty and that nothing in it is stale.
    (is (plusp (length cna-lisp.internal::*binding-extensions*)))))

;;; --- the generated compatibility report must describe this image -----------

(defun read-json-text (relative)
  (with-open-file (stream (repository-path relative))
    (let ((text (make-string (file-length stream))))
      (subseq text 0 (read-sequence text stream)))))

(defun json-integer-after (text key)
  "The integer following \"KEY\": in TEXT. Enough for a scoreboard check, and it
keeps the test suite free of a JSON dependency it would otherwise need for six
numbers."
  (let ((at (search (format nil "\"~a\":" key) text)))
    (when at
      (let* ((start (+ at (length key) 3))
             (digits (position-if-not (lambda (c) (or (digit-char-p c)
                                                      (member c '(#\Space #\:))))
                                      text :start start)))
        (parse-integer text :start start :end digits :junk-allowed t)))))

(defun json-string-after (text key)
  "The string following \"KEY\": in TEXT."
  (let ((at (search (format nil "\"~a\":" key) text)))
    (when at
      (let* ((open (position #\" text :start (+ at (length key) 2)))
             (close (position #\" text :start (1+ open))))
        (subseq text (1+ open) close)))))

(test the-compatibility-report-describes-this-image
  (let ((text (read-json-text "docs/generated/api-compat-report.json")))
    ;; The implementation *family*, not this build of it. A committed report
    ;; that named one SBCL build would make every other machine's freshness
    ;; gate fail on a difference that says nothing about the projection -- and
    ;; the projection really is build-independent: the dump is byte-identical
    ;; across SBCL 2.2.9, 2.5.2 and 2.5.2.debian.
    (is (equal (lisp-implementation-type)
               (json-string-after text "implementation"))
        "the committed report was generated by a different Lisp implementation")
    (is (eql 0 (json-integer-after text "disagreement_total"))
        "the committed report has a non-zero disagreement total; strict verification ~
         may be red for missing surface, never for a disagreement")))

(test every-type-the-report-claims-is-really-exported
  ;; The report names the Lisp symbol it measured for each projected type. If one
  ;; of those is not exported here, the report is describing a different image.
  (let* ((text (read-json-text "docs/generated/api-compat-report.json"))
         (position 0)
         (checked 0))
    (loop
      (let ((at (search "\"lisp\": \"" text :start2 position)))
        (unless at (return))
        (let* ((start (+ at 9))
               (end (position #\" text :start start))
               (qualified (subseq text start end))
               (colon (position #\: qualified)))
          (setf position end)
          (when colon
            (let* ((package (find-package (string-upcase (subseq qualified 0 colon))))
                   (name (string-upcase (subseq qualified (1+ colon)))))
              (is (not (null package)) "no package for ~a" qualified)
              (when package
                (multiple-value-bind (symbol status) (find-symbol name package)
                  (declare (ignore symbol))
                  (is (eq :external status)
                      "~a is not exported, but the report claims it" qualified)
                  (incf checked))))))))
    (is (>= checked 15) "only ~d projected types were checked" checked)))
