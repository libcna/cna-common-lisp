;;;; sprite-font.lisp --- Microsoft.Xna.Framework.Graphics.SpriteFont.
;;;;
;;;; Six public members -- `LineSpacing', `Spacing', `DefaultCharacter',
;;;; `Characters' and the two `MeasureString' overloads -- and four decisions
;;;; behind them that the pinned assembly, not CNA, settled.
;;;;
;;;; **SpriteFont is not a GraphicsResource and is not IDisposable.** The
;;;; contract says `baseType System.Object', the assembly says `sealed ...
;;;; extends [mscorlib]System.Object', and there is no `Dispose' anywhere on it.
;;;; CNA nevertheless hands out an *owned* handle that must be given back. Those
;;;; are two different questions and this file answers them separately: the public
;;;; shape is XNA's, and the handle is released through the binding's own
;;;; DISPOSE, which is a declared CNA-Lisp extension on every native object and
;;;; not an XNA member of this type. See `docs/ownership-and-lifetimes.md'.
;;;;
;;;; **There is no public constructor, so this file exposes none.** XNA's `.ctor'
;;;; is `assembly'-visible: a consumer obtains a SpriteFont from
;;;; `ContentManager.Load<SpriteFont>' and from nowhere else. CNA does have
;;;; `cna_sprite_font_create', and projecting it as a public constructor would
;;;; invent a member XNA has not got. `%MAKE-SPRITE-FONT-FROM-GLYPHS' is
;;;; unexported and exists so the closure can be tested before the content
;;;; closure lands; `docs/limitations.md' records that a consumer therefore
;;;; cannot yet obtain one.
;;;;
;;;; **Measurement and drawing are computed here, from the glyph table, not asked
;;;; of CNA.** CNA has `cna_sprite_font_measure_utf8' and
;;;; `cna_sprite_batch_draw_string' and this binding calls neither for its answer,
;;;; for the same reason the value types do their own arithmetic: a runtime cannot
;;;; be the oracle for its own compatibility, and routing layout through CNA would
;;;; make the layout CNA's rather than XNA's, leaving nothing to cross-check. Two
;;;; concrete things follow. The algorithms below are transcribed instruction by
;;;; instruction from `SpriteFont::InternalMeasure' and `SpriteFont::InternalDraw'
;;;; in the pinned `Microsoft.Xna.Framework.Graphics.dll'. And the projected input
;;;; domain stays XNA's: CNA's two routes take **UTF-8**, which cannot encode an
;;;; unpaired surrogate, while a `System.String' can hold one and this can measure
;;;; one. `cna_sprite_font_measure_utf8' is bound anyway, and
;;;; `tests/native/sprite-font.lisp' cross-checks it against this file over the
;;;; text where both domains agree -- as a comparison, never as an authority.
;;;;
;;;; **A glyph is looked up by UTF-16 code unit.** `System.Char' is sixteen bits
;;;; with all 65536 values legal, so it projects onto an integer in [0, 65535]
;;;; rather than onto CHARACTER, and a string is converted to code units before
;;;; anything is measured. `src/internal/utf16.lisp' has the derivation.

(in-package #:microsoft.xna.framework.graphics)

(defclass sprite-font (cna-lisp.internal:native-object)
  ((%characters :initarg :characters :reader %font-characters
                :documentation
                "The supported code units, ascending. XNA's `characterMap', and
the array its binary search runs over.")
   (%glyphs :initarg :glyphs :reader %font-glyphs
            :documentation "XNA's `glyphData': one source rectangle per glyph.")
   (%cropping :initarg :cropping :reader %font-cropping
              :documentation "XNA's `croppingData': one offset rectangle per glyph.")
   (%kerning :initarg :kerning :reader %font-kerning
             :documentation
             "XNA's `kerning': one Vector3 per glyph, X left bearing, Y width,
Z right bearing.")
   (%line-spacing :initarg :line-spacing :accessor %font-line-spacing)
   (%spacing :initarg :spacing :accessor %font-spacing)
   (%default-character :initarg :default-character :accessor %font-default-character)
   (%texture :initarg :texture :reader %font-texture
             :documentation
             "The atlas this font's glyphs are cut from. Not owned: CNA retains
it for the font's lifetime and the caller still disposes it, after the font."))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.SpriteFont: a glyph atlas and the metrics
that place text on it.

Sealed, and **not** a GraphicsResource -- XNA derives it straight from
System.Object -- so it has no Name, no Tag, no GraphicsDevice and no Disposing
event, and it is not IDisposable. The native font CNA owns underneath it is
released with MICROSOFT.XNA.FRAMEWORK:DISPOSE, which is this binding's own
deterministic disposal and not an XNA member of this type.

XNA gives it no public constructor: a SpriteFont comes from
`ContentManager.Load<SpriteFont>'. That content closure is not part of this
milestone, so no public route here produces one either."))

;;; --- the glyph table -------------------------------------------------------

(defun %read-font-glyph-table (handle count operation)
  "Copy CNA's glyph rows out into four parallel Lisp vectors.

Read once, at construction, and never again: XNA's SpriteFont takes four
`List<T>'s in its constructor and no member of it can change their contents, so
crossing the ABI per glyph per frame would buy nothing and cost a call for every
character drawn.

Four vectors rather than one vector of structures, because that is what XNA has
-- `glyphData', `croppingData', `characterMap' and `kerning', indexed in
lockstep -- and because the measurement transcription indexes them exactly that
way."
  (let ((characters (make-array count :element-type '(unsigned-byte 16)))
        (glyphs (make-array count))
        (cropping (make-array count))
        (kerning (make-array count)))
    (when (plusp count)
      (cffi:with-foreign-object (rows '(:struct cna-lisp.internal.ffi::cna-sprite-font-glyph)
                                      count)
        (cffi:with-foreign-object (written :uint64)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%sprite-font-copy-glyphs handle rows count written)
           operation :object-type 'sprite-font)
          (let ((n (cffi:mem-ref written :uint64)))
            (unless (= n count)
              (error 'microsoft.xna.framework:cna-invalid-object-error
                     :operation operation :object-type 'sprite-font
                     :format-control
                     "CNA reported ~d glyph(s) and then copied ~d."
                     :format-arguments (list count n)))))
        (dotimes (i count)
          (let ((row (cffi:mem-aptr
                      rows '(:struct cna-lisp.internal.ffi::cna-sprite-font-glyph) i)))
            (macrolet ((slot (name)
                         `(cffi:foreign-slot-value
                           row '(:struct cna-lisp.internal.ffi::cna-sprite-font-glyph) ',name)))
              (setf (aref characters i) (slot cna-lisp.internal.ffi::character)
                    (aref glyphs i)
                    (%read-rectangle (cffi:foreign-slot-pointer
                                      row '(:struct cna-lisp.internal.ffi::cna-sprite-font-glyph)
                                      'cna-lisp.internal.ffi::glyph-bounds))
                    (aref cropping i)
                    (%read-rectangle (cffi:foreign-slot-pointer
                                      row '(:struct cna-lisp.internal.ffi::cna-sprite-font-glyph)
                                      'cna-lisp.internal.ffi::cropping))
                    (aref kerning i)
                    (%read-vector3 (cffi:foreign-slot-pointer
                                    row '(:struct cna-lisp.internal.ffi::cna-sprite-font-glyph)
                                    'cna-lisp.internal.ffi::kerning))))))))
    (values characters glyphs cropping kerning)))

;;; --- the private producer --------------------------------------------------

(defun %make-sprite-font-from-glyphs (texture glyphs &key (line-spacing 0) (spacing 0.0f0)
                                                          default-character)
  "Build a SpriteFont over TEXTURE from a complete glyph table. **Not exported.**

XNA has no public SpriteFont constructor, so neither has CNA-Lisp; this exists so
that measurement, the default-character fallback and DrawString can be qualified
before `ContentManager.Load<SpriteFont>' is projected. GLYPHS is a sequence of
(CODE-UNIT SOURCE-RECTANGLE CROPPING-RECTANGLE KERNING-VECTOR3) lists, which is
the row `cna_sprite_font_create' takes.

Construction is all-or-nothing. Exactly one native handle is acquired here, and
every step after acquiring it -- reading the glyph table back, reading the
character list back -- runs under a rollback that destroys it, so a failure
part-way through cannot leave the game owning a font the caller never received.
That is the Effect closure's rule with one handle instead of a graph: what is
acquired is recorded before anything that can fail, and the rollback is quiet so
it cannot mask the failure that caused it."
  (check-type texture texture-2d)
  (cna-lisp.internal:check-usable texture "make sprite-font")
  (let* ((rows (coerce glyphs 'vector))
         (count (length rows))
         (handle 0))
    (cffi:with-foreign-object (table '(:struct cna-lisp.internal.ffi::cna-sprite-font-glyph)
                                     (max 1 count))
      (cffi:foreign-funcall "memset" :pointer table :int 0
                            :size (* (max 1 count)
                                     cna-lisp.internal.ffi::+sizeof-cna-sprite-font-glyph+)
                            :void)
      (dotimes (i count)
        (destructuring-bind (unit source crop kern) (aref rows i)
          (check-type unit cna-lisp.internal:utf-16-code-unit)
          (let ((row (cffi:mem-aptr
                      table '(:struct cna-lisp.internal.ffi::cna-sprite-font-glyph) i)))
            (macrolet ((slot (name)
                         `(cffi:foreign-slot-value
                           row '(:struct cna-lisp.internal.ffi::cna-sprite-font-glyph) ',name)))
              (setf (slot cna-lisp.internal.ffi::struct-size)
                    cna-lisp.internal.ffi::+sizeof-cna-sprite-font-glyph+
                    (slot cna-lisp.internal.ffi::struct-version) 1
                    (slot cna-lisp.internal.ffi::character) unit
                    (slot cna-lisp.internal.ffi::reserved) 0))
            (%write-rectangle
             (cffi:foreign-slot-pointer
              row '(:struct cna-lisp.internal.ffi::cna-sprite-font-glyph)
              'cna-lisp.internal.ffi::glyph-bounds)
             source)
            (%write-rectangle
             (cffi:foreign-slot-pointer
              row '(:struct cna-lisp.internal.ffi::cna-sprite-font-glyph)
              'cna-lisp.internal.ffi::cropping)
             crop)
            (let ((k (cffi:foreign-slot-pointer
                      row '(:struct cna-lisp.internal.ffi::cna-sprite-font-glyph)
                      'cna-lisp.internal.ffi::kerning)))
              (setf (cffi:foreign-slot-value
                     k '(:struct cna-lisp.internal.ffi::cna-vector-3) 'cna-lisp.internal.ffi::x)
                    (microsoft.xna.framework:vector3-x kern)
                    (cffi:foreign-slot-value
                     k '(:struct cna-lisp.internal.ffi::cna-vector-3) 'cna-lisp.internal.ffi::y)
                    (microsoft.xna.framework:vector3-y kern)
                    (cffi:foreign-slot-value
                     k '(:struct cna-lisp.internal.ffi::cna-vector-3) 'cna-lisp.internal.ffi::z)
                    (microsoft.xna.framework:vector3-z kern))))))
      (cffi:with-foreign-object (info '(:struct cna-lisp.internal.ffi::cna-sprite-font-create-info))
        (cffi:foreign-funcall
         "memset" :pointer info :int 0
         :size cna-lisp.internal.ffi::+sizeof-cna-sprite-font-create-info+ :void)
        (macrolet ((slot (name)
                     `(cffi:foreign-slot-value
                       info '(:struct cna-lisp.internal.ffi::cna-sprite-font-create-info)
                       ',name)))
          (setf (slot cna-lisp.internal.ffi::struct-size)
                cna-lisp.internal.ffi::+sizeof-cna-sprite-font-create-info+
                (slot cna-lisp.internal.ffi::struct-version) 1
                (slot cna-lisp.internal.ffi::texture) (cna-lisp.internal:handle-of texture)
                (slot cna-lisp.internal.ffi::glyphs) table
                (slot cna-lisp.internal.ffi::glyph-count) count
                (slot cna-lisp.internal.ffi::line-spacing) line-spacing
                (slot cna-lisp.internal.ffi::spacing) (coerce spacing 'single-float)
                (slot cna-lisp.internal.ffi::default-character) (or default-character 0)
                (slot cna-lisp.internal.ffi::has-default-character)
                (if default-character 1 0)))
        (cffi:with-foreign-object (out :uint64)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%sprite-font-create info out)
           "make sprite-font" :object-type 'sprite-font)
          (setf handle (cffi:mem-ref out :uint64)))))
    ;; The handle exists from here on, so everything that can still fail is
    ;; inside the rollback.
    (let ((constructed nil))
      (unwind-protect
           (multiple-value-bind (characters bounds cropping kerning)
               (%read-font-glyph-table handle count "make sprite-font")
             (let ((font (make-instance 'sprite-font
                                        :handle handle
                                        :ownership :owned
                                        :owner texture
                                        :owner-thread (cna-lisp.internal:owner-thread-of texture)
                                        :characters characters
                                        :glyphs bounds
                                        :cropping cropping
                                        :kerning kerning
                                        :line-spacing line-spacing
                                        :spacing (coerce spacing 'single-float)
                                        :default-character default-character
                                        :texture texture)))
               ;; A child of the *atlas*, not of the game. CNA parents the native
               ;; font to the game, but the resource whose destruction would
               ;; invalidate this one is the texture -- CNA says the texture
               ;; "cannot be destroyed until this SpriteFont is destroyed" -- and
               ;; recording that here is what makes disposing them in the wrong
               ;; order a diagnosable refusal instead of a native failure. The
               ;; game still refuses while the texture lives, so the ordering CNA
               ;; wants holds transitively.
               (cna-lisp.internal:register-child texture font)
               (setf constructed t)
               font))
        (unless constructed
          (ignore-errors (cna-lisp.internal.ffi::%sprite-font-destroy handle)))))))

(defmethod cna-lisp.internal:destroy-native ((font sprite-font))
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%sprite-font-destroy (cna-lisp.internal:handle-of font))
   "dispose" :object-type 'sprite-font))

;;; --- LineSpacing and Spacing ------------------------------------------------
;;;
;;; Both setters in the assembly are a bare `stfld'. There is no validation of
;;; any kind: XNA accepts a negative LineSpacing, a zero one, and a Spacing that
;;; is NaN or either infinity, and stores exactly what it was given. None of that
;;; is added here, because adding it would refuse programs XNA runs.
;;;
;;; CNA is stricter -- `cna_sprite_font_set_spacing' documents "Must be finite"
;;; -- and that is precisely why these are managed fields rather than write-through
;;; to the native font. XNA's are managed fields too: `InternalMeasure' and
;;; `InternalDraw' read them from the object, and nothing native reads them here
;;; either, because both algorithms are computed in this file. So the three CNA
;;; setters are deliberately not bound at all. `docs/limitations.md' records the
;;; divergence and what it means for the native font's own view.

(defgeneric line-spacing (sprite-font)
  (:documentation
   "SpriteFont.LineSpacing: the vertical distance between baselines, in pixels."))

(defgeneric (setf line-spacing) (value sprite-font)
  (:documentation
   "SpriteFont.LineSpacing's setter, which validates nothing.

The assembly stores the value and returns. A negative or zero line spacing is
accepted, exactly as it is in XNA."))

(defmethod line-spacing ((font sprite-font))
  (cna-lisp.internal:check-live font "line-spacing")
  (%font-line-spacing font))

(defmethod (setf line-spacing) (value (font sprite-font))
  (check-type value (signed-byte 32))
  (cna-lisp.internal:check-live font "(setf line-spacing)")
  (setf (%font-line-spacing font) value))

(defgeneric spacing (sprite-font)
  (:documentation
   "SpriteFont.Spacing: extra horizontal space between characters, in pixels."))

(defgeneric (setf spacing) (value sprite-font)
  (:documentation
   "SpriteFont.Spacing's setter, which validates nothing.

NaN and both infinities are accepted and stored, because that is what the
assembly does. CNA's own setter refuses them; this is not CNA's setter."))

(defmethod spacing ((font sprite-font))
  (cna-lisp.internal:check-live font "spacing")
  (%font-spacing font))

(defmethod (setf spacing) (value (font sprite-font))
  (check-type value real)
  (cna-lisp.internal:check-live font "(setf spacing)")
  (setf (%font-spacing font)
        (cna-lisp.internal:with-binary32-semantics (coerce value 'single-float))))

;;; --- Characters --------------------------------------------------------------

(defgeneric characters (sprite-font)
  (:documentation
   "SpriteFont.Characters: every code unit this font has a glyph for, ascending.

XNA answers a `ReadOnlyCollection<char>' -- a read-only *view*, lazily made and
then cached, so the same instance comes back every time. Common Lisp has no
read-only vector, so the projection cannot have both that identity and that
immutability, and it chooses immutability: a **fresh** (UNSIGNED-BYTE 16) vector
each call, which a caller may do anything to without it meaning anything to the
font. Reference identity is the property that cannot be relied on here;
`docs/limitations.md' records the divergence.

The elements are UTF-16 code units, not characters, because that is what
`System.Char' is."))

(defmethod characters ((font sprite-font))
  (cna-lisp.internal:check-live font "characters")
  (copy-seq (%font-characters font)))

;;; --- DefaultCharacter --------------------------------------------------------

(defgeneric default-character (sprite-font)
  (:documentation
   "SpriteFont.DefaultCharacter: the fallback code unit, or NIL for none.

XNA's is a `Nullable<char>', and the binding's nullable rule makes the empty case
NIL. A code unit of 0 is a real fallback and is not NIL."))

(defgeneric (setf default-character) (value sprite-font)
  (:documentation
   "SpriteFont.DefaultCharacter's setter.

NIL clears the fallback and is always accepted, which is XNA's `HasValue' being
false. A code unit that the font has no glyph for is refused, because the
assembly refuses it: `set_DefaultCharacter' checks `characterMap.Contains' and
throws `ArgumentException' formatted with the character and its numeric value."))

(defmethod default-character ((font sprite-font))
  (cna-lisp.internal:check-live font "default-character")
  (%font-default-character font))

(defmethod (setf default-character) (value (font sprite-font))
  (check-type value (or null cna-lisp.internal:utf-16-code-unit))
  (cna-lisp.internal:check-live font "(setf default-character)")
  ;; The order is the assembly's: a null is stored without being looked up, and
  ;; only a value is checked against the character map.
  (when (and value (not (%font-glyph-index font value)))
    (error 'microsoft.xna.framework:cna-argument-error
           :operation "(setf default-character)"
           :object-type 'sprite-font
           :parameter-name "value"
           :format-control
           "the font has no glyph for code unit ~d (U+~4,'0X), so it cannot be the ~
            default character. XNA throws ArgumentException here."
           :format-arguments (list value value)))
  (setf (%font-default-character font) value))

;;; --- the glyph lookup, and the fallback --------------------------------------

(defun %font-glyph-index (font unit)
  "The index of UNIT's glyph, or NIL. XNA's binary search, without the throw.

`GetIndexForCharacter' searches `characterMap' with `lo + ((hi - lo) >> 1)' and
then either falls back or throws. The search is separated from the failure here
because `set_DefaultCharacter' needs the same search and must *not* throw for a
miss -- it raises its own ArgumentException with a different message."
  (let ((characters (%font-characters font)))
    (loop with lo of-type fixnum = 0
          with hi of-type fixnum = (1- (length characters))
          while (<= lo hi)
          do (let* ((mid (+ lo (ash (- hi lo) -1)))
                    (found (aref characters mid)))
               (cond ((= found unit) (return mid))
                     ((< found unit) (setf lo (1+ mid)))
                     (t (setf hi (1- mid))))))))

(defun %font-required-glyph-index (font unit operation)
  "XNA's `GetIndexForCharacter' entire: search, fall back once, or throw.

The fallback recurses on the default character, and the assembly's guard against
recursing forever is one comparison: a missing character that *is* the default
character throws rather than looking itself up again. That case is reachable --
the internal constructor stores `defaultCharacter' without validating it, so a
font can be built whose fallback has no glyph -- and it is why this is a single
retry rather than a loop."
  (or (%font-glyph-index font unit)
      (let ((fallback (%font-default-character font)))
        (and fallback
             (/= unit fallback)
             (%font-glyph-index font fallback)))
      (error 'microsoft.xna.framework:cna-argument-error
             :operation operation
             :object-type 'sprite-font
             :parameter-name "character"
             :format-control
             "the font has no glyph for code unit ~d (U+~4,'0X)~:[ and no default ~
              character~;, and its default character has none either~]. XNA throws ~
              ArgumentException here."
             :format-arguments (list unit unit (%font-default-character font)))))

;;; --- MeasureString -----------------------------------------------------------

(defgeneric measure-string (sprite-font text)
  (:documentation
   "SpriteFont.MeasureString: the extent this font would give TEXT.

Both of XNA's overloads. `MeasureString(String)' and
`MeasureString(StringBuilder)' are two members of the contract and one call here,
because after XNA's private `StringProxy' has wrapped either of them the two
method bodies are identical -- a StringBuilder is reached only through `Length'
and `Chars', which is what a Common Lisp string already is. The mapping rules
record the collapse and the verifier proves both members are represented.

TEXT is measured as the sequence of UTF-16 code units a `System.String' already
is, so a character above U+FFFF is measured as its surrogate pair, which is what
XNA looks up.

A carriage return is skipped; a newline ends a line; a code unit the font has no
glyph for falls back to `DefaultCharacter' and, failing that, signals."))

(defmethod measure-string ((font sprite-font) (text string))
  (cna-lisp.internal:check-live font "measure-string")
  (%measure-code-units font (cna-lisp.internal:string-code-units text) "measure-string"))

(defun %measure-code-units (font units operation)
  "SpriteFont::InternalMeasure, transcribed.

Every step below is one the assembly takes, and several of them are not what a
reimplementation from a description would produce:

* an empty string answers Vector2.Zero and never touches LineSpacing;
* the height *starts* at LineSpacing and is raised by each glyph's **cropping**
  height, not its source height;
* a carriage return is skipped entirely -- it is neither measured nor does it end
  a line, so \"A\\r\\nB\" and \"A\\nB\" measure the same;
* the first glyph on a line clamps its left bearing up to zero and pays neither
  Spacing nor the previous glyph's right bearing;
* the pending right bearing is carried across glyphs and clamped with Max(.., 0)
  once at the end of each line and once at the end of the string, so a negative
  final right bearing does not shrink the result;
* `lineBreaks * lineSpacing' is an **int32** multiplication that is converted to
  binary32 afterwards, not a float multiply."
  (cna-lisp.internal:with-binary32-semantics
    (let ((length (length units)))
      (if (zerop length)
          (microsoft.xna.framework:vector2-zero)
          (let ((width 0.0f0)
                (height (coerce (%font-line-spacing font) 'single-float))
                (widest 0.0f0)
                (line-breaks 0)
                (pending-right 0.0f0)
                (first-glyph-of-line t)
                (spacing (%font-spacing font)))
            (dotimes (i length)
              (let ((unit (aref units i)))
                (cond
                  ;; A carriage return is skipped before anything else.
                  ((= unit 13))
                  ((= unit 10)
                   (setf width (+ width (microsoft.xna.framework:math-helper-max
                                         pending-right 0.0f0))
                         pending-right 0.0f0
                         widest (microsoft.xna.framework:math-helper-max width widest)
                         width 0.0f0
                         height (coerce (%font-line-spacing font) 'single-float)
                         first-glyph-of-line t)
                   (incf line-breaks))
                  (t
                   (let* ((index (%font-required-glyph-index font unit operation))
                          (kern (aref (%font-kerning font) index))
                          (left (microsoft.xna.framework:vector3-x kern)))
                     (if first-glyph-of-line
                         (setf left (microsoft.xna.framework:math-helper-max left 0.0f0))
                         (setf width (+ width (+ spacing pending-right))))
                     (setf width (+ width (+ left (microsoft.xna.framework:vector3-y kern)))
                           pending-right (microsoft.xna.framework:vector3-z kern))
                     (let ((crop (aref (%font-cropping font) index)))
                       (setf height (microsoft.xna.framework:math-helper-max
                                     height
                                     (coerce (microsoft.xna.framework:rectangle-height crop)
                                             'single-float))))
                     (setf first-glyph-of-line nil))))))
            (setf width (+ width (microsoft.xna.framework:math-helper-max pending-right 0.0f0))
                  ;; int32 multiply, then converted -- `mul' then `conv.r4'.
                  height (+ height (coerce (* line-breaks (%font-line-spacing font))
                                           'single-float))
                  width (microsoft.xna.framework:math-helper-max width widest))
            (microsoft.xna.framework:make-vector2 width height))))))

(defmethod print-object ((font sprite-font) stream)
  (print-unreadable-object (font stream :type t)
    (format stream "~d glyph~:p, line-spacing ~d~:[~; disposed~]"
            (length (%font-characters font)) (%font-line-spacing font)
            (cna-lisp.internal:disposed-state-of font))))
