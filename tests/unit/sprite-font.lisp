;;;; sprite-font.lisp --- SpriteFont's measurement, fallback and Char projection.
;;;;
;;;; These need no CNA. XNA's `InternalMeasure' and `GetIndexForCharacter' read
;;;; the four parallel glyph vectors, LineSpacing, Spacing and DefaultCharacter
;;;; and nothing else, so the algorithm is a pure function of a font's table and
;;;; is tested here as one, against a fixture whose numbers were chosen to make
;;;; each clause of the assembly's code path fail if it were written the obvious
;;;; way instead of the way it is written.
;;;;
;;;; `tests/native/sprite-font.lisp' then builds the *same* table through
;;;; `cna_sprite_font_create' and re-measures it, so the table this file invents
;;;; and the table CNA hands back are proved to be the same table.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

;;; --- the fixture -------------------------------------------------------------
;;;
;;; Six glyphs, ascending by code unit as XNA's characterMap is, and every one of
;;; them earns its place:
;;;
;;;   '.'  a **negative right bearing**, so the final Max(pending, 0) matters
;;;   '?'  the fallback glyph
;;;   'A'  an ordinary glyph
;;;   'B'  an ordinary glyph with a zero left bearing
;;;   'J'  a **negative left bearing**, so the first-glyph-of-line clamp matters
;;;   'T'  a cropping height **larger than its glyph height and than LineSpacing**,
;;;        so which rectangle the height comes from matters

(defparameter *sprite-font-fixture-glyphs*
  ;; code unit, glyph bounds in the atlas, cropping, kerning (left, width, right)
  (list (list 46 '(19 0 3 4)   '(0 8 3 4)    '(0.0 3.0 -1.0))   ; .
        (list 63 '(22 0 7 10)  '(0 2 7 10)   '(1.0 7.0 1.0))    ; ?
        (list 65 '(0 0 8 10)   '(0 2 8 10)   '(1.0 8.0 2.0))    ; A
        (list 66 '(8 0 6 10)   '(1 3 6 10)   '(0.0 6.0 1.0))    ; B
        (list 74 '(14 0 5 12)  '(-2 1 5 12)  '(-3.0 5.0 0.0))   ; J
        (list 84 '(29 0 6 10)  '(0 0 6 26)   '(0.0 6.0 0.0)))   ; T
  "The fixture glyph table, as (CODE-UNIT BOUNDS CROPPING KERNING) lists.")

(defun sprite-font-fixture-rows ()
  "The fixture as the row list %MAKE-SPRITE-FONT-FROM-GLYPHS takes."
  (mapcar (lambda (row)
            (destructuring-bind (unit bounds cropping kerning) row
              (list unit
                    (apply #'xna:make-rectangle bounds)
                    (apply #'xna:make-rectangle cropping)
                    (apply #'xna:make-vector3 kerning))))
          *sprite-font-fixture-glyphs*))

(defun make-fixture-sprite-font (&key (line-spacing 20) (spacing 1.0f0) default-character)
  "A SpriteFont with the fixture table and **no native handle**.

Legitimate because the algorithms under test read only the table: XNA's
SpriteFont holds four `List<T>'s and three scalars, and neither `InternalMeasure'
nor `GetIndexForCharacter' touches anything else. It also reaches a state the
public API cannot -- a DefaultCharacter with no glyph -- which XNA reaches through
its own internal constructor, and which is what makes the recursion guard
testable."
  (let ((rows (sprite-font-fixture-rows)))
    (make-instance 'gfx::sprite-font
                   :handle 0 :ownership :parent-owned
                   :characters (map '(vector (unsigned-byte 16)) #'first rows)
                   :glyphs (map 'vector #'second rows)
                   :cropping (map 'vector #'third rows)
                   :kerning (map 'vector #'fourth rows)
                   :line-spacing line-spacing
                   :spacing (coerce spacing 'single-float)
                   :default-character default-character
                   :texture nil)))

(defun measured (font text)
  "MEASURE-STRING as two numbers, for readable assertions."
  (let ((v (gfx:measure-string font text)))
    (list (xna:vector2-x v) (xna:vector2-y v))))

;;; --- System.Char is a UTF-16 code unit ----------------------------------------

(test a-string-projects-onto-utf-16-code-units
  "A CLR string is a sequence of code units, so this conversion is what makes the
projected text the same text XNA measures."
  (is (equalp #(65) (int:string-code-units "A")))
  (is (equalp #(72 105) (int:string-code-units "Hi")))
  (is (equalp #() (int:string-code-units "")))
  ;; A non-ASCII BMP code unit is one unit, not its UTF-8 bytes.
  (is (equalp #(233) (int:string-code-units (string (code-char #xE9)))))
  (is (equalp #(#x4E2D) (int:string-code-units (string (code-char #x4E2D)))))
  ;; Both ends of the code-unit range.
  (is (equalp #(0) (int:string-code-units (string (code-char 0)))))
  (is (equalp #(#xFFFF) (int:string-code-units (string (code-char #xFFFF))))))

(test a-character-above-the-bmp-becomes-a-surrogate-pair
  "U+1F600 is one Common Lisp character and two System.Chars. XNA looks each of
the two up in the glyph table separately, so the projection must produce both."
  (let ((units (int:string-code-units (string (code-char #x1F600)))))
    (is (= 2 (length units)))
    (is (= #xD83D (aref units 0)))
    (is (= #xDE00 (aref units 1)))
    (is (int:high-surrogate-p (aref units 0)))
    (is (int:low-surrogate-p (aref units 1)))))

(test an-unpaired-surrogate-survives-as-a-code-unit
  "0xD800 on its own is a legal System.Char and a legal element of a
System.String. It is not a Unicode scalar value and cannot be encoded as UTF-8,
which is exactly why the projection is an integer and not a byte sequence."
  (let ((units (int:string-code-units (string (code-char #xD800)))))
    (is (equalp #(#xD800) units))
    (is (int:high-surrogate-p (aref units 0)))
    ;; And it comes back, rather than being dropped or replaced.
    (is (= #xD800 (char-code (char (int:code-units-to-string units) 0))))))

(test code-units-round-trip-through-a-string
  (dolist (text (list "" "A" "Hello, world" (string (code-char #x4E2D))
                      (string (code-char #x1F600))
                      (coerce (list (code-char 65) (code-char #x1F600) (code-char 66))
                              'string)))
    (is (string= text (int:code-units-to-string (int:string-code-units text))))))

(test a-code-unit-outside-zero-to-65535-is-not-a-system-char
  "DefaultCharacter is a Nullable<Char>, so its projection accepts NIL and
[0, 65535] and refuses everything else -- including -1, which would be the
obvious wrong spelling of \"none\"."
  (let ((font (make-fixture-sprite-font)))
    (signals type-error (setf (gfx:default-character font) -1))
    (signals type-error (setf (gfx:default-character font) 65536))
    (signals type-error (setf (gfx:default-character font) #\A))))

;;; --- MeasureString, clause by clause -------------------------------------------

(test measuring-an-empty-string-answers-vector2-zero
  "The assembly returns Vector2.Zero before it ever reads LineSpacing, so an
empty string does not measure one line high."
  (let ((font (make-fixture-sprite-font)))
    (is (equal '(0.0 0.0) (measured font "")))))

(test measuring-one-glyph-pays-its-bearings-and-one-line-of-height
  "'A' is left bearing 1 + width 8 + right bearing 2 = 11 wide, and the height
starts at LineSpacing."
  (let ((font (make-fixture-sprite-font)))
    (is (equal '(11.0 20.0) (measured font "A")))))

(test measuring-two-glyphs-pays-spacing-and-the-pending-right-bearing-once
  "'AB' is 'A' without its final clamp (9), then Spacing (1) and A's right
bearing (2), then B (0 + 6), then B's right bearing (1): 19."
  (let ((font (make-fixture-sprite-font)))
    (is (equal '(19.0 20.0) (measured font "AB")))))

(test the-first-glyph-of-a-line-clamps-its-left-bearing-and-a-later-one-does-not
  "'J' has a left bearing of -3. Alone it is clamped to zero and 'J' measures 5.
In 'AJ' it is not clamped and is paid in full, so 'AJ' is 14 and not 17. A
projection that clamped everywhere, or nowhere, gets one of these wrong."
  (let ((font (make-fixture-sprite-font)))
    (is (equal '(5.0 20.0) (measured font "J")))
    (is (equal '(14.0 20.0) (measured font "AJ")))))

(test a-negative-final-right-bearing-is-clamped-and-does-not-shrink-the-result
  "'.' has a right bearing of -1. The assembly adds Max(pending, 0) at the end,
so '.' is 3 wide and not 2."
  (let ((font (make-fixture-sprite-font)))
    (is (equal '(3.0 20.0) (measured font ".")))
    (is (equal '(15.0 20.0) (measured font "A.")))))

(test the-height-comes-from-the-cropping-rectangle-not-the-glyph-rectangle
  "'T' has a glyph height of 10 and a cropping height of 26. The measured height
is 26, so the height is Max(LineSpacing, cropping.Height) and the glyph
rectangle does not enter into it."
  (let ((font (make-fixture-sprite-font)))
    (is (equal '(6.0 26.0) (measured font "T")))))

(test a-carriage-return-is-skipped-entirely
  "\\r is neither measured nor treated as a line break: the assembly's first
comparison jumps straight to the increment. So 'A\\rB' measures as 'AB', and
'A\\r\\nB' measures as 'A\\nB'."
  (let ((font (make-fixture-sprite-font)))
    (is (equal (measured font "AB") (measured font (format nil "A~cB" #\Return))))
    (is (equal (measured font (format nil "A~cB" #\Newline))
               (measured font (format nil "A~c~cB" #\Return #\Newline))))))

(test a-newline-ends-a-line-and-adds-one-line-of-height
  "'A\\nB' is the wider of the two lines -- A's 11 -- and two lines high."
  (let ((font (make-fixture-sprite-font)))
    (is (equal '(11.0 40.0) (measured font (format nil "A~cB" #\Newline))))))

(test the-widest-line-wins-and-the-last-line-does-not
  "'AB\\nA' is 19 wide because the first line is, even though the last line is 11.
A projection that returned the final line's width would answer 11."
  (let ((font (make-fixture-sprite-font)))
    (is (equal '(19.0 40.0) (measured font (format nil "AB~cA" #\Newline))))))

(test line-breaks-multiply-line-spacing-as-integers
  "The assembly multiplies lineBreaks by lineSpacing as int32 and converts the
product to binary32 afterwards. Three breaks and a line spacing of 20 is 60 on
top of the last line's 20."
  (let ((font (make-fixture-sprite-font)))
    (is (equal '(11.0 80.0)
               (measured font (format nil "A~c~c~cA" #\Newline #\Newline #\Newline))))))

;;; --- the fallback, and its ordering ---------------------------------------------

(test a-glyph-the-font-does-not-have-signals-when-there-is-no-default
  "XNA throws ArgumentException naming the character. It does not substitute a
question mark, a space or a zero-width nothing."
  (let ((font (make-fixture-sprite-font)))
    (signals xna:cna-argument-error (gfx:measure-string font "Z"))
    ;; And it is an ArgumentException, so catching the .NET base class catches it.
    (signals xna:cna-usage-error (gfx:measure-string font "Z"))))

(test an-unknown-glyph-uses-the-default-character
  "With DefaultCharacter set to '?', every character of \"Hello\" resolves to the
'?' glyph, five times, and measures as five '?'s would."
  (let ((font (make-fixture-sprite-font :default-character 63)))
    (is (equal '(49.0 20.0) (measured font "Hello")))
    (is (equal (measured font "Hello") (measured font "?????")))))

(test a-known-glyph-is-not-replaced-by-the-default
  "The fallback is reached only after the binary search fails."
  (let ((font (make-fixture-sprite-font :default-character 63)))
    (is (equal '(11.0 20.0) (measured font "A")))))

(test a-default-character-the-font-lacks-signals-rather-than-recursing
  "The assembly guards its one recursion with a single comparison: a missing
character that *is* the default character throws instead of looking itself up
again. The state is reachable because the internal constructor stores
DefaultCharacter without validating it."
  (let ((font (make-fixture-sprite-font :default-character 90)))  ; 'Z', not in the font
    (signals xna:cna-argument-error (gfx:measure-string font "Q"))
    ;; and the guard is what makes that terminate at all
    (signals xna:cna-argument-error (gfx:measure-string font "Z"))))

(test setting-a-default-character-the-font-lacks-is-refused
  "set_DefaultCharacter checks characterMap.Contains and throws ArgumentException.
This is XNA's own validation, not CNA's."
  (let ((font (make-fixture-sprite-font)))
    (signals xna:cna-argument-error (setf (gfx:default-character font) 90))
    (is (null (gfx:default-character font)))))

(test clearing-the-default-character-to-nil-is-always-accepted
  "A null Nullable<char> is stored without being looked up: the assembly's
HasValue test comes first."
  (let ((font (make-fixture-sprite-font :default-character 63)))
    (is (= 63 (gfx:default-character font)))
    (setf (gfx:default-character font) nil)
    (is (null (gfx:default-character font)))
    (signals xna:cna-argument-error (gfx:measure-string font "Z"))))

(test a-default-character-in-the-font-is-accepted-and-used
  (let ((font (make-fixture-sprite-font)))
    (setf (gfx:default-character font) 65)
    (is (= 65 (gfx:default-character font)))
    (is (equal (measured font "A") (measured font "Z")))))

;;; --- the properties XNA does not validate -----------------------------------------

(test line-spacing-and-spacing-store-what-they-are-given
  "Both setters in the assembly are a bare stfld. A negative line spacing, a zero
one and a negative spacing are all accepted, and no managed validation is added
here to match CNA's stricter native setter."
  (let ((font (make-fixture-sprite-font)))
    (setf (gfx:line-spacing font) -5)
    (is (= -5 (gfx:line-spacing font)))
    (setf (gfx:line-spacing font) 0)
    (is (= 0 (gfx:line-spacing font)))
    (setf (gfx:spacing font) -2.5)
    (is (= -2.5f0 (gfx:spacing font)))))

(test spacing-accepts-the-values-cna-refuses
  "CNA's cna_sprite_font_set_spacing documents \"Must be finite\". XNA's setter
stores a NaN or an infinity without looking at it, and so does this: adding
validation to match the runtime would refuse programs XNA runs.
docs/limitations.md records the divergence."
  (let ((font (make-fixture-sprite-font)))
    (int:with-binary32-semantics
      (let ((infinity (/ 1.0f0 0.0f0)))
        (setf (gfx:spacing font) infinity)
        (is (int:infinity-p (gfx:spacing font)))
        (setf (gfx:spacing font) (- infinity))
        (is (int:infinity-p (gfx:spacing font)))
        (setf (gfx:spacing font) (/ 0.0f0 0.0f0))
        (is (int:nan-p (gfx:spacing font)))))))

(test a-line-spacing-outside-int32-is-not-a-line-spacing
  "LineSpacing is an Int32 in the contract; a value that is not one is not a
value the member can hold."
  (let ((font (make-fixture-sprite-font)))
    (signals type-error (setf (gfx:line-spacing font) (expt 2 31)))
    (signals type-error (setf (gfx:line-spacing font) 1.5))))

;;; --- Characters -----------------------------------------------------------------

(test characters-answers-the-code-units-in-ascending-order
  "The collection is the characterMap, which XNA's binary search requires to be
sorted, and its elements are code units rather than characters."
  (let ((font (make-fixture-sprite-font)))
    (is (equalp #(46 63 65 66 74 84) (gfx:characters font)))
    (is (equal '(unsigned-byte 16) (array-element-type (gfx:characters font))))))

(test characters-answers-a-fresh-vector-that-cannot-modify-the-font
  "XNA answers a cached ReadOnlyCollection, so the same instance every time and
no way to modify it. Common Lisp has no read-only vector, so the projection keeps
the immutability and gives up the identity: mutating what comes back means
nothing to the font. docs/limitations.md records it."
  (let* ((font (make-fixture-sprite-font))
         (first (gfx:characters font)))
    (setf (aref first 0) 999)
    (is (equalp #(46 63 65 66 74 84) (gfx:characters font)))
    (is (equal '(11.0 20.0) (measured font "A")))))
