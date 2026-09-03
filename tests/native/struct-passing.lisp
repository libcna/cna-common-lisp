;;;; struct-passing.lisp --- the by-value aggregate flattening, proved.
;;;;
;;;; CFFI cannot pass a structure by value without cffi-libffi. That is measured
;;;; here rather than assumed, and the flattening CNA-Lisp uses instead is proved
;;;; against a C compiler's own idea of the calling convention: the probe
;;;; functions take the aggregate *by value*, with the real prototype, and copy
;;;; back the bytes that actually arrived.
;;;;
;;;; The probe library is built by tools/native-abi/verify.sh, which needs a C
;;;; compiler and the CNA headers -- a maintenance gate. Where it is absent these
;;;; tests report that they did not run; they never report a pass.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defvar *valueprobe-loaded* nil)

(defun valueprobe-path ()
  (let ((explicit (uiop:getenv "CNA_LISP_VALUEPROBE")))
    (or (and explicit (string/= explicit "") (probe-file explicit))
        (probe-file (repository-path "build-probe/libcna-lisp-valueprobe.so")))))

(defun ensure-valueprobe ()
  (or *valueprobe-loaded*
      (let ((path (valueprobe-path)))
        (when path
          (cffi:load-foreign-library (namestring path))
          (setf *valueprobe-loaded* t)))))

(defmacro define-valueprobe-test (name &body body)
  `(define-native-test ,name
     (if (ensure-valueprobe)
         (progn ,@body)
         (skip "the by-value probe library is absent; build it with ~
                tools/native-abi/verify.sh <cna-header-root>. ~a did not run" ',name))))

;;; The flattened declarations, exactly as the generator would emit them for a
;;; route taking these aggregates by value.

(cffi:defcfun ("cna_lisp_valueprobe_cna_color" %probe-color) :void
  (value :uint32) (out :pointer))

(cffi:defcfun ("cna_lisp_valueprobe_cna_color_after" %probe-color-after) :void
  (before :int32) (value :uint32) (after :int32)
  (out :pointer) (out-before :pointer) (out-after :pointer))

(cffi:defcfun ("cna_lisp_valueprobe_cna_stringview" %probe-string-view) :void
  (data :pointer) (byte-length :uint64) (out :pointer))

(cffi:defcfun ("cna_lisp_valueprobe_cna_stringview_after" %probe-string-view-after) :void
  (before :int32) (data :pointer) (byte-length :uint64) (after :int32)
  (out :pointer) (out-before :pointer) (out-after :pointer))

(define-native-test cffi-cannot-pass-a-structure-by-value
  ;; The measurement the whole design rests on. If this ever stops being true --
  ;; because cffi-libffi got loaded, or CFFI grew the ability -- the flattening
  ;; is no longer the only option and that is worth knowing.
  (is (null (find-package "CFFI-LIBFFI"))
      "cffi-libffi is loaded in this image; the by-value measurement is no longer ~
       the one CNA-Lisp's design was chosen against")
  (signals error
    (eval '(cffi:foreign-funcall "cna_get_abi_version"
                                 (:struct cna-lisp.internal.ffi::cna-color)
                                 (cffi:mem-ref (cffi:null-pointer)
                                               '(:struct cna-lisp.internal.ffi::cna-color))
                                 :uint32))))

(define-valueprobe-test a-four-byte-integer-aggregate-arrives-intact
  (cffi:with-foreign-object (out :uint8 4)
    (dolist (packed '(#x00000000 #xFFFFFFFF #x04030201 #x80402010 #x000000FF))
      (%probe-color packed out)
      (is (= (ldb (byte 8 0) packed) (cffi:mem-aref out :uint8 0)))
      (is (= (ldb (byte 8 8) packed) (cffi:mem-aref out :uint8 1)))
      (is (= (ldb (byte 8 16) packed) (cffi:mem-aref out :uint8 2)))
      (is (= (ldb (byte 8 24) packed) (cffi:mem-aref out :uint8 3))))))

(define-valueprobe-test a-four-byte-aggregate-consumes-exactly-one-argument-slot
  ;; Integers before and after it prove that the flattened argument occupies the
  ;; register the aggregate would, and no more.
  (cffi:with-foreign-objects ((out :uint8 4) (before :int32) (after :int32))
    (%probe-color-after -12345 #x04030201 67890 out before after)
    (is (= -12345 (cffi:mem-ref before :int32)))
    (is (= 67890 (cffi:mem-ref after :int32)))
    (is (= 1 (cffi:mem-aref out :uint8 0)))
    (is (= 4 (cffi:mem-aref out :uint8 3)))))

(define-valueprobe-test a-sixteen-byte-two-eightbyte-aggregate-arrives-intact
  (int:with-utf8-view (data length "CNA-Lisp ✓")
    (cffi:with-foreign-object (out :uint8 16)
      (%probe-string-view data length out)
      (is (cffi:pointer-eq data (cffi:mem-ref out :pointer 0)))
      (is (= length (cffi:mem-ref (cffi:inc-pointer out 8) :uint64))))))

(define-valueprobe-test a-two-eightbyte-aggregate-consumes-exactly-two-slots
  (int:with-utf8-view (data length "two eightbytes")
    (cffi:with-foreign-objects ((out :uint8 16) (before :int32) (after :int32))
      (%probe-string-view-after 7 data length 11 out before after)
      (is (= 7 (cffi:mem-ref before :int32)))
      (is (= 11 (cffi:mem-ref after :int32)))
      (is (cffi:pointer-eq data (cffi:mem-ref out :pointer 0)))
      (is (= length (cffi:mem-ref (cffi:inc-pointer out 8) :uint64))))))

(define-native-test a-by-value-colour-reaches-a-real-cna-route
  ;; Not a probe: cna_game_clear takes CNA_Color by value, and this is a real
  ;; call through the flattened declaration the generator produced.
  (with-counting-game (game :exit-after 1)
    (is (zerop (ffi::%game-clear (int:handle-of game)
                                 (xna:color-packed-value (xna:cornflower-blue)))))))

(define-native-test a-by-value-string-view-reaches-a-real-cna-route
  ;; cna_game_set_window_title takes CNA_StringView by value.
  (with-counting-game (game)
    (setf (xna:window-title game) "CNA-Lisp — Ünïcödé ✓ спайк 日本語")
    (is (string= "CNA-Lisp — Ünïcödé ✓ спайк 日本語" (xna:window-title game)))))

(define-native-test an-embedded-nul-is-refused-by-the-encoding-contract
  ;; The view is pointer-plus-length, so an embedded NUL reaches CNA as data;
  ;; CNA refuses it, and CNA-Lisp reports that as an encoding failure rather
  ;; than truncating the title and claiming success.
  (with-counting-game (game)
    (handler-case
        (progn (setf (xna:window-title game) (format nil "a~ab" (code-char 0)))
               (fail "an embedded NUL was accepted"))
      (xna:cna-encoding-error (condition)
        (is (search "UTF-8" (princ-to-string condition)))))))

(define-native-test a-string-comes-back-through-count-then-copy
  (with-counting-game (game)
    (let ((name (xna:clr-type-name game)))
      (is (stringp name))
      (is (string= "Microsoft.Xna.Framework.Game" name)))))
