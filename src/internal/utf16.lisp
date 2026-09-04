;;;; utf16.lisp --- System.Char, and the code units a CLR string is made of.
;;;;
;;;; A CLR `char' is a **UTF-16 code unit**: sixteen bits, all 65536 of them
;;;; legal. It is not a Unicode scalar value, not a code point, and not a Common
;;;; Lisp character. `(char)0xD800' is an unpaired high surrogate; it is a
;;;; perfectly ordinary `System.Char', it can sit in a `System.String', and
;;;; `SpriteFont.Characters' can contain it.
;;;;
;;;; So `System.Char' projects onto **an integer in [0, 65535]**, and not onto
;;;; CHARACTER. Two measured facts decided that, and neither is about which is
;;;; prettier:
;;;;
;;;; 1. **A Common Lisp string is a sequence of code points, and a CLR string is
;;;;    a sequence of code units.** They agree for the whole BMP and disagree
;;;;    above it: U+1F600 is *one* CHARACTER here and *two* chars there. XNA's
;;;;    SpriteFont looks each of those two up in its glyph table separately, and
;;;;    a projection that measured one CHARACTER instead would answer a width
;;;;    XNA never answers. STRING-CODE-UNITS is therefore not an optimisation; it
;;;;    is what makes the projected text the same text.
;;;;
;;;; 2. **Whether a lone surrogate is even representable as a character is
;;;;    implementation-defined.** SBCL admits `(code-char #xD800)'; ANSI does not
;;;;    require it and other implementations refuse it. An integer in [0, 65535]
;;;;    is exact on every conforming implementation, which is the property a
;;;;    projection of a 16-bit value needs.
;;;;
;;;; `Nullable<Char>' follows the binding's existing nullable rule -- NIL for the
;;;; empty case, the projected value otherwise -- so it is NIL or a code unit.
;;;; NIL is unambiguous here precisely because a code unit is an integer: 0 is a
;;;; real code unit and is not NIL, which is exactly the distinction
;;;; `SpriteFont.DefaultCharacter' needs between "no fallback" and "fall back to
;;;; U+0000".

(in-package #:cna-lisp.internal)

(deftype utf-16-code-unit ()
  "A CLR `System.Char': one UTF-16 code unit, every value of which is legal."
  '(integer 0 65535))

(declaim (inline high-surrogate-p low-surrogate-p))

(defun high-surrogate-p (unit)
  (<= #xD800 unit #xDBFF))

(defun low-surrogate-p (unit)
  (<= #xDC00 unit #xDFFF))

(defun string-code-units (string)
  "The UTF-16 code units of STRING, as a fresh (UNSIGNED-BYTE 16) vector.

This is the conversion from a Common Lisp string -- a sequence of code points --
to what a `System.String' already is. A character below U+10000 contributes one
unit, an unpaired surrogate included; a character at or above U+10000
contributes the surrogate pair the CLR would already be holding."
  (declare (type string string))
  ;; Counted first, then filled: the length is a property of the string, so
  ;; there is no reason to guess it and grow.
  (let* ((count (loop for character across string
                      sum (if (< (char-code character) #x10000) 1 2)))
         (units (make-array count :element-type '(unsigned-byte 16)))
         (out 0))
    (declare (type fixnum out))
    (loop for character across string
          for point of-type (integer 0) = (char-code character)
          do (cond ((< point #x10000)
                    (setf (aref units out) point)
                    (incf out))
                   (t
                    ;; One character, two code units, exactly as the CLR holds
                    ;; it. The pair is what XNA's glyph lookup sees.
                    (let ((offset (- point #x10000)))
                      (setf (aref units out) (logior #xD800 (ash offset -10))
                            (aref units (1+ out)) (logior #xDC00 (logand offset #x3FF)))
                      (incf out 2)))))
    units))

(defun code-units-to-string (units)
  "The Common Lisp string UNITS spells, pairing surrogates as the CLR does.

An unpaired surrogate is kept as the character of that code point, because
dropping it or replacing it would lose a code unit the CLR can hold. On an
implementation where such a character does not exist this signals, which is
honest: the string cannot represent what the code units say."
  (with-output-to-string (out)
    (let ((i 0) (n (length units)))
      (loop while (< i n)
            do (let ((unit (elt units i)))
                 (cond ((and (high-surrogate-p unit)
                             (< (1+ i) n)
                             (low-surrogate-p (elt units (1+ i))))
                        (write-char (code-char (+ #x10000
                                                  (ash (- unit #xD800) 10)
                                                  (- (elt units (1+ i)) #xDC00)))
                                    out)
                        (incf i 2))
                       (t
                        (write-char (code-char unit) out)
                        (incf i))))))))
