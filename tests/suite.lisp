;;;; suite.lisp --- the CNA-Lisp test suite's shape.
;;;;
;;;; Four layers, and the difference between them matters:
;;;;
;;;;   :unit       pure Lisp; no native library, no CNA
;;;;   :structure  the public surface and the generated files, in this image
;;;;   :behavior   the behaviour corpus, with each observation's origin recorded
;;;;   :native     a real CNA C ABI library, exercised for real
;;;;
;;;; The native layer never "passes" without a library. When CNA_NATIVE_LIBRARY
;;;; is unset it is reported as NOT RUN and the runner says so; when it is set
;;;; and the library is unusable the tests fail, they do not skip.

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require :sb-introspect))

(defpackage #:cna-common-lisp.tests
  (:use #:cl #:fiveam)
  (:local-nicknames (#:xna   #:microsoft.xna.framework)
                    (#:gfx   #:microsoft.xna.framework.graphics)
                    (#:pv    #:microsoft.xna.framework.graphics.packed-vector)
                    (#:xna.content #:microsoft.xna.framework.content)
                    (#:input #:microsoft.xna.framework.input)
                    (#:touch #:microsoft.xna.framework.input.touch)
                    (#:audio #:microsoft.xna.framework.audio)
                    (#:media #:microsoft.xna.framework.media)
                    (#:int   #:cna-lisp.internal)
                    (#:ffi   #:cna-lisp.internal.ffi))
  (:shadow #:run-all-tests)
  (:export #:run-all-tests #:all-tests))

(in-package #:cna-common-lisp.tests)

(def-suite all-tests :description "Every CNA-Lisp test.")

(def-suite unit-tests      :in all-tests :description "Pure Lisp; no CNA.")
(def-suite structure-tests :in all-tests :description "Public surface and generated files.")
(def-suite behavior-tests  :in all-tests :description "The behaviour corpus.")
(def-suite native-tests    :in all-tests :description "A real CNA C ABI library.")

(defun native-library-requested-p ()
  "True when the environment names a CNA native library to test against."
  (let ((value (uiop:getenv "CNA_NATIVE_LIBRARY")))
    (and value (string/= value ""))))

(defun fixture-path (name)
  (merge-pathnames (format nil "fixtures/~a" name)
                   (asdf:system-relative-pathname "cna-common-lisp" "tests/")))

(defun repository-path (relative)
  (asdf:system-relative-pathname "cna-common-lisp" relative))
