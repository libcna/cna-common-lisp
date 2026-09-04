;;;; sprite-font.lisp --- a SpriteFont over a real CNA font, and what owns what.
;;;;
;;;; `tests/unit/sprite-font.lisp' proves the measurement algorithm over a glyph
;;;; table this repository invents. That is the whole of XNA's behaviour and none
;;;; of CNA's. This file closes the other half: the table CNA hands back through
;;;; `cna_sprite_font_copy_glyphs' is the table it was given, so the algorithm
;;;; the unit tests pin is running over the real thing.
;;;;
;;;; It also pins the ownership decision, which is the part of this closure that
;;;; is neither XNA's nor obvious. XNA's SpriteFont is not IDisposable and CNA's
;;;; is an owned handle; the resource whose destruction would invalidate the font
;;;; is the atlas texture, and CNA says so -- "the source texture ... cannot be
;;;; destroyed until this SpriteFont is destroyed" -- so the binding records the
;;;; texture as the font's owner and disposing them in the wrong order is
;;;; refused here rather than discovered as a native failure.
;;;;
;;;; No assertion runs inside a lifecycle callback. Observations are collected
;;;; there and asserted after the loop has returned, because a FiveAM failure
;;;; crossing the callback containment layer is a test-framework restart reaching
;;;; C, not an application condition.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defparameter *glyph-atlas-fixture* "glyph-atlas-16x8.png"
  "A 16x8 atlas: 'A' is the opaque red left half, 'B' the opaque green right
half. Two colours rather than two shapes, so a pixel says which glyph reached
it. tools/qualification/make-pixel-fixtures.py states every texel.")

(defparameter +glyph-atlas-line-spacing+ 12)

(defun glyph-atlas-rows ()
  "The glyph table for *GLYPH-ATLAS-FIXTURE*.

Chosen so every expected position is an exact integer: each glyph is 8 wide with
no bearings, the spacing is zero, and the line spacing is 12 -- four more than a
glyph is tall, so consecutive lines leave a gap that a wrong line advance cannot
accidentally fill."
  (list (list 65 (xna:make-rectangle 0 0 8 8) (xna:make-rectangle 0 0 8 8)
              (xna:make-vector3 0.0 8.0 0.0))
        (list 66 (xna:make-rectangle 8 0 8 8) (xna:make-rectangle 0 0 8 8)
              (xna:make-vector3 0.0 8.0 0.0))))

(defclass sprite-font-game (graphics-game)
  ((atlas :initform nil :accessor atlas)
   (font :initform nil :accessor font)
   (rows :initarg :rows :initform nil :accessor rows)
   (font-line-spacing :initarg :font-line-spacing
                      :initform +glyph-atlas-line-spacing+ :accessor font-line-spacing)
   (font-spacing :initarg :font-spacing :initform 0.0f0 :accessor font-spacing)
   (build-error :initform nil :accessor build-error))
  (:documentation
   "Builds a real CNA SpriteFont over a real Texture2D during LoadContent."))

(defgeneric %build-fixture-font (game device)
  (:documentation
   "Answer (values FONT ATLAS) for GAME's fixture font.

A hook, so the same pixel proofs can run against a font that was *loaded* through
a ContentManager rather than built here. The two paths must put identical pixels
on the back buffer; if they do not, one of them is wrong, and the rasterization
suite is where that shows up rather than in a metrics comparison.")
  (:method ((game sprite-font-game) device)
    (let ((atlas (gfx:texture-2d-from-png-file
                  device (fixture-path *glyph-atlas-fixture*))))
      (values (gfx::%make-sprite-font-from-glyphs
               atlas (or (rows game) (glyph-atlas-rows))
               :line-spacing (font-line-spacing game)
               :spacing (font-spacing game))
              atlas))))

(defmethod xna:load-content ((game sprite-font-game))
  (call-next-method)
  (handler-case
      (multiple-value-bind (font atlas)
          (%build-fixture-font game (xna:graphics-device game))
        (setf (atlas game) atlas
              (font game) font))
    (error (condition) (setf (build-error game) condition))))

(defmacro with-sprite-font-game ((variable &rest initargs) &body body)
  "Run a SPRITE-FONT-GAME, then run BODY with the font still alive.

The font and its atlas outlive the loop -- they are game children, not callback
state -- so the assertions happen out here, where a failure is an ordinary Lisp
failure and not a condition crossing the callback boundary."
  `(let ((,variable (make-instance 'sprite-font-game :exit-after 2 ,@initargs)))
     (unwind-protect
          (progn (xna:run ,variable)
                 (when (build-error ,variable) (error (build-error ,variable)))
                 ,@body)
       (progn
         (when (font ,variable) (ignore-errors (xna:dispose (font ,variable))))
         (when (atlas ,variable) (ignore-errors (xna:dispose (atlas ,variable))))
         (when (batch ,variable) (ignore-errors (xna:dispose (batch ,variable))))
         (when (texture ,variable) (ignore-errors (xna:dispose (texture ,variable))))
         (when (manager ,variable) (ignore-errors (xna:dispose (manager ,variable))))
         (ignore-errors (xna:dispose ,variable))))))

;;; --- the table survives the round trip through CNA --------------------------

(define-native-test a-sprite-font-reads-its-glyph-table-back-out-of-cna
  "cna_sprite_font_copy_glyphs is documented as the inverse of
cna_sprite_font_create. This is that claim, checked: every character, every atlas
rectangle, every cropping rectangle and all three kerning values come back as
they went in, in the same order."
  (with-sprite-font-game (game)
    (let ((font (font game))
          (rows (glyph-atlas-rows)))
      (is (equalp #(65 66) (gfx:characters font)))
      (loop for row in rows
            for index from 0
            do (destructuring-bind (unit bounds cropping kerning) row
                 (let ((back-bounds (aref (gfx::%font-glyphs font) index))
                       (back-cropping (aref (gfx::%font-cropping font) index))
                       (back-kerning (aref (gfx::%font-kerning font) index)))
                   (is (= unit (aref (gfx::%font-characters font) index)))
                   (is (xna:rectangle-equal bounds back-bounds)
                       "glyph ~d's atlas rectangle came back as ~a" index back-bounds)
                   (is (xna:rectangle-equal cropping back-cropping)
                       "glyph ~d's cropping came back as ~a" index back-cropping)
                   (is (xna:vector3-equal kerning back-kerning)
                       "glyph ~d's kerning came back as ~a" index back-kerning)))))))

(define-native-test a-real-sprite-font-measures-what-the-algorithm-says
  "The same numbers tests/unit/sprite-font.lisp derives from the assembly, over a
table that has been through the C ABI. 'A' is 8 wide with no bearings and the
line is 12 high; 'AB' is 16 wide because the spacing is zero."
  (with-sprite-font-game (game)
    (let ((font (font game)))
      (is (= 12 (gfx:line-spacing font)))
      (is (= 0.0f0 (gfx:spacing font)))
      (is (null (gfx:default-character font)))
      (let ((a (gfx:measure-string font "A"))
            (ab (gfx:measure-string font "AB"))
            (empty (gfx:measure-string font "")))
        (is (= 8.0f0 (xna:vector2-x a)))
        (is (= 12.0f0 (xna:vector2-y a)))
        (is (= 16.0f0 (xna:vector2-x ab)))
        (is (= 12.0f0 (xna:vector2-y ab)))
        (is (= 0.0f0 (xna:vector2-x empty)))
        (is (= 0.0f0 (xna:vector2-y empty))))
      ;; Two lines: the widest line, and one extra LineSpacing of height.
      (let ((two (gfx:measure-string font (format nil "AB~cA" #\Newline))))
        (is (= 16.0f0 (xna:vector2-x two)))
        (is (= 24.0f0 (xna:vector2-y two)))))))

(define-native-test cna-measures-the-same-string-the-same-way
  "A cross-check, not an authority. CNA-Lisp computes MeasureString itself, from
the assembly; CNA has `cna_sprite_font_measure_utf8' and computes its own answer.
Where the two input domains overlap -- text that is valid UTF-8, which excludes
the unpaired surrogates a System.String can hold -- they should agree, and a
disagreement is an upstream finding worth having rather than a reason to adopt
CNA's number."
  (with-sprite-font-game (game)
    (let ((font (font game)))
      (dolist (text '("" "A" "B" "AB" "BA" "ABAB"))
        (let ((ours (gfx:measure-string font text))
              (theirs (cna-measure-utf8 font text)))
          (is (= (xna:vector2-x ours) (xna:vector2-x theirs))
              "~s: CNA-Lisp measures width ~a and CNA measures ~a"
              text (xna:vector2-x ours) (xna:vector2-x theirs))
          (is (= (xna:vector2-y ours) (xna:vector2-y theirs))
              "~s: CNA-Lisp measures height ~a and CNA measures ~a"
              text (xna:vector2-y ours) (xna:vector2-y theirs)))))))

(defun cna-measure-utf8 (font text)
  "Ask CNA to measure TEXT, for cross-checking only.

Deliberately not what MEASURE-STRING calls. The route takes UTF-8, so it cannot
express an unpaired surrogate, and it is CNA's algorithm rather than the one read
out of the pinned assembly."
  (int:with-utf8-view (data length text)
    (cffi:with-foreign-object (size '(:struct ffi::cna-vector-2))
      (int:check-result
       (ffi::%sprite-font-measure-utf-8 (int:handle-of font) data length size)
       "cna-measure-utf8")
      (gfx::%read-vector2 size))))

;;; --- ownership --------------------------------------------------------------

(define-native-test a-sprite-font-is-not-a-graphics-resource
  "XNA's SpriteFont extends System.Object. It has no Name, no Tag, no
GraphicsDevice and no Disposing event, and the projection must not give it any of
them just because every other graphics object here has them."
  (with-sprite-font-game (game)
    (is (not (typep (font game) 'gfx:graphics-resource))
        "SpriteFont must not be a GraphicsResource; the contract says baseType
System.Object")
    (is (typep (atlas game) 'gfx:graphics-resource)
        "its atlas is one, though")))

(define-native-test the-atlas-cannot-be-disposed-while-the-font-is-alive
  "CNA retains the texture for the font's lifetime and says it cannot be
destroyed first. Recording the texture as the font's owner is what turns that
into a refusal naming both types instead of a native failure later."
  (with-sprite-font-game (game)
    (signals xna:cna-ownership-error (xna:dispose (atlas game)))
    ;; And the refusal left both of them usable.
    (is (not (xna:disposed-p (atlas game))))
    (is (not (xna:disposed-p (font game))))
    (is (= 8.0f0 (xna:vector2-x (gfx:measure-string (font game) "A"))))))

(define-native-test disposing-the-font-then-the-atlas-is-accepted
  (with-sprite-font-game (game)
    (let ((font (font game)) (atlas (atlas game)))
      (xna:dispose font)
      (is (xna:disposed-p font))
      (xna:dispose atlas)
      (is (xna:disposed-p atlas))
      ;; Idempotent, as IDisposable.Dispose is -- even though XNA's SpriteFont
      ;; has no Dispose of its own and this one is the binding's.
      (finishes (xna:dispose font))
      (finishes (xna:dispose atlas)))))

(define-native-test a-disposed-sprite-font-refuses-every-member
  "Not merely the ones that cross the ABI. LineSpacing and MeasureString read
cached tables and could quietly keep answering; a disposed object answering
anything at all is what the ownership model exists to prevent."
  (with-sprite-font-game (game)
    (let ((font (font game)))
      (xna:dispose font)
      (signals xna:cna-disposed-error (gfx:measure-string font "A"))
      (signals xna:cna-disposed-error (gfx:line-spacing font))
      (signals xna:cna-disposed-error (gfx:spacing font))
      (signals xna:cna-disposed-error (gfx:characters font))
      (signals xna:cna-disposed-error (gfx:default-character font))
      (signals xna:cna-disposed-error (setf (gfx:line-spacing font) 3))
      (signals xna:cna-disposed-error (setf (gfx:default-character font) nil)))))

(define-native-test the-game-refuses-to-be-disposed-while-a-font-is-alive
  "Transitively: the font is the atlas's child and the atlas is the game's, so
the game refuses while the atlas lives and the atlas refuses while the font
does. CNA-Lisp does not cascade."
  (with-sprite-font-game (game)
    (signals xna:cna-ownership-error (xna:dispose game))
    (is (not (xna:disposed-p game)))))

;;; --- the native properties, and where CNA is stricter than XNA ---------------

(define-native-test a-spacing-cna-would-refuse-is-still-stored
  "XNA's setter is a bare stfld and takes a NaN. CNA's
`cna_sprite_font_set_spacing' documents \"Must be finite\" and would refuse it,
which is exactly why the projection keeps LineSpacing, Spacing and
DefaultCharacter as managed fields and does not write them through: the three CNA
setters are not bound at all. Measuring afterwards uses the managed value, so the
NaN propagates the way XNA's would. docs/limitations.md records the divergence."
  (with-sprite-font-game (game)
    (let ((font (font game)))
      (int:with-binary32-semantics
        (setf (gfx:spacing font) (/ 0.0f0 0.0f0))
        (is (int:nan-p (gfx:spacing font)))
        ;; One glyph never pays Spacing, so it still measures exactly.
        (is (= 8.0f0 (xna:vector2-x (gfx:measure-string font "A"))))
        ;; Two do, and Math.Max(NaN, x) is NaN, so the width becomes one.
        (is (int:nan-p (xna:vector2-x (gfx:measure-string font "AB"))))))))

(define-native-test a-default-character-is-validated-against-the-real-table
  (with-sprite-font-game (game)
    (let ((font (font game)))
      (signals xna:cna-argument-error (setf (gfx:default-character font) 67))  ; 'C'
      (setf (gfx:default-character font) 65)
      (is (= 65 (gfx:default-character font)))
      ;; 'C' has no glyph and now falls back to 'A'.
      (is (= 8.0f0 (xna:vector2-x (gfx:measure-string font "C"))))
      (setf (gfx:default-character font) nil)
      (signals xna:cna-argument-error (gfx:measure-string font "C")))))

;;; --- construction is all or nothing ------------------------------------------

(defclass refused-font-game (graphics-game)
  ((atlas :initform nil :accessor atlas)
   (refusal :initform nil :accessor refusal)
   (accepted :initform nil :accessor accepted)
   (rows :initarg :rows :accessor rows))
  (:documentation
   "Tries to build a SpriteFont from a glyph table CNA should refuse, and records
what happened instead of asserting it."))

(defmethod xna:load-content ((game refused-font-game))
  (call-next-method)
  (setf (atlas game) (gfx:texture-2d-from-png-file
                      (xna:graphics-device game) (fixture-path *glyph-atlas-fixture*)))
  (handler-case
      (setf (accepted game)
            (gfx::%make-sprite-font-from-glyphs (atlas game) (rows game) :line-spacing 12))
    (error (condition) (setf (refusal game) condition))))

(define-native-test a-refused-sprite-font-leaves-nothing-behind
  "A construction CNA refuses must leave no handle and no child. What is checked
afterwards is that the atlas is childless and can still be disposed, which it
could not be if a font were still registered against it -- and, since the handle
is destroyed on the way out of the rollback, the game shuts down cleanly rather
than reporting an outstanding child."
  (let ((game (make-instance 'refused-font-game :exit-after 2
                             ;; A glyph whose cropping is versioned wrongly cannot
                             ;; be built here, so the refusal is asked for the way
                             ;; a caller would hit it: a reserved field CNA
                             ;; requires to be zero is the binding's to get right,
                             ;; so this uses a count CNA cannot satisfy instead --
                             ;; a table with no glyphs at all.
                             :rows '())))
    (unwind-protect
         (progn
           (xna:run game)
           (cond
             ((refusal game)
              (is (typep (refusal game) 'xna:cna-error))
              (is (null (accepted game)))
              (is (null (int:children-of (atlas game)))
                  "a refused construction left ~d child(ren) on the atlas"
                  (length (int:children-of (atlas game))))
              (finishes (xna:dispose (atlas game))))
             (t
              ;; CNA accepted an empty font. That is legal, and then the thing
              ;; worth checking is that the accepted font is well-formed and
              ;; owned, not that a rollback happened.
              (is (not (null (accepted game))))
              (is (equalp #() (gfx:characters (accepted game))))
              (is (eq (accepted game) (first (int:children-of (atlas game)))))
              (signals xna:cna-ownership-error (xna:dispose (atlas game))))))
      (progn
        (when (accepted game) (ignore-errors (xna:dispose (accepted game))))
        (when (atlas game) (ignore-errors (xna:dispose (atlas game))))
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (ignore-errors (xna:dispose game))))))
