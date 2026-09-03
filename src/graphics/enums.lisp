;;;; enums.lisp --- how CNA-Lisp represents XNA enumerations.
;;;;
;;;; One representation, used everywhere: **an enum member is a keyword**, and
;;;; each enum gets a Common Lisp type of that name plus two conversion
;;;; functions. Keywords read naturally, cannot be confused with an unrelated
;;;; enum's member of the same numeric value, and let CHECK-TYPE do the checking.
;;;; The exact numeric values the ABI defines are preserved -- privately, in the
;;;; generated tables -- and are reachable through the conversion functions for
;;;; the cases where the number is itself part of the contract.
;;;;
;;;; A flags enum is a *list* of keywords. The empty list is the named zero
;;;; member where the enum has one.
;;;;
;;;; DEFINE-XNA-ENUM is the single place this shape is defined -- it lives in
;;;; src/framework/enums.lisp, private to the framework package, and is used from
;;;; here as well so that no enum can drift into representing itself differently.

(in-package #:microsoft.xna.framework.graphics)

(microsoft.xna.framework::define-xna-enum sprite-sort-mode
  '((:deferred . 0) (:immediate . 1) (:texture . 2)
    (:back-to-front . 3) (:front-to-back . 4))
  :documentation "Microsoft.Xna.Framework.Graphics.SpriteSortMode.")

(microsoft.xna.framework::define-xna-enum sprite-effects
  '((:none . 0) (:flip-horizontally . 1) (:flip-vertically . 2))
  :documentation "Microsoft.Xna.Framework.Graphics.SpriteEffects, a flags enum."
  :flags t)

(microsoft.xna.framework::define-xna-enum surface-format
  (copy-alist cna-lisp.internal.ffi:*surface-format-table*)
  :documentation "Microsoft.Xna.Framework.Graphics.SurfaceFormat.")

