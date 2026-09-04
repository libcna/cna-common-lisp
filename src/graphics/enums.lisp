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


;;; --- the enumerations the graphics state objects are built from --------------
;;;
;;; Values come from the hash-pinned XNA contract, never from CNA. That matters
;;; here more than anywhere else so far, because for one of these two the two
;;; disagree: XNA's BlendFunction is Min = 3, Max = 4, and CNA's is
;;; CNA_BLEND_FUNCTION_MAX = 3, CNA_BLEND_FUNCTION_MIN = 4. The public value is
;;; XNA's; src/graphics/state-objects.lisp carries the translation table that
;;; reconciles it, and tests/unit/graphics-state.lisp pins both sides.

(microsoft.xna.framework::define-xna-enum blend
  '((:one . 0) (:zero . 1) (:source-color . 2) (:inverse-source-color . 3)
    (:source-alpha . 4) (:inverse-source-alpha . 5)
    (:destination-color . 6) (:inverse-destination-color . 7)
    (:destination-alpha . 8) (:inverse-destination-alpha . 9)
    (:blend-factor . 10) (:inverse-blend-factor . 11)
    (:source-alpha-saturation . 12))
  :documentation "Microsoft.Xna.Framework.Graphics.Blend.")

(microsoft.xna.framework::define-xna-enum blend-function
  '((:add . 0) (:subtract . 1) (:reverse-subtract . 2) (:min . 3) (:max . 4))
  :documentation
  "Microsoft.Xna.Framework.Graphics.BlendFunction.

Min is 3 and Max is 4, which is what the pinned contract says and the opposite of
CNA's own CNA_BLEND_FUNCTION_MAX and CNA_BLEND_FUNCTION_MIN. The public value is
XNA's.")

(microsoft.xna.framework::define-xna-enum color-write-channels
  '((:none . 0) (:red . 1) (:green . 2) (:blue . 4) (:alpha . 8) (:all . 15))
  :documentation
  "Microsoft.Xna.Framework.Graphics.ColorWriteChannels, a flags enum."
  :flags t)

(microsoft.xna.framework::define-xna-enum compare-function
  '((:always . 0) (:never . 1) (:less . 2) (:less-equal . 3) (:equal . 4)
    (:greater-equal . 5) (:greater . 6) (:not-equal . 7))
  :documentation "Microsoft.Xna.Framework.Graphics.CompareFunction.")

(microsoft.xna.framework::define-xna-enum stencil-operation
  '((:keep . 0) (:zero . 1) (:replace . 2) (:increment . 3) (:decrement . 4)
    (:increment-saturation . 5) (:decrement-saturation . 6) (:invert . 7))
  :documentation "Microsoft.Xna.Framework.Graphics.StencilOperation.")

(microsoft.xna.framework::define-xna-enum cull-mode
  '((:none . 0) (:cull-clockwise-face . 1) (:cull-counter-clockwise-face . 2))
  :documentation "Microsoft.Xna.Framework.Graphics.CullMode.")

(microsoft.xna.framework::define-xna-enum fill-mode
  '((:solid . 0) (:wire-frame . 1))
  :documentation "Microsoft.Xna.Framework.Graphics.FillMode.")

(microsoft.xna.framework::define-xna-enum texture-address-mode
  '((:wrap . 0) (:clamp . 1) (:mirror . 2))
  :documentation "Microsoft.Xna.Framework.Graphics.TextureAddressMode.")

(microsoft.xna.framework::define-xna-enum texture-filter
  '((:linear . 0) (:point . 1) (:anisotropic . 2) (:linear-mip-point . 3)
    (:point-mip-linear . 4) (:min-linear-mag-point-mip-linear . 5)
    (:min-linear-mag-point-mip-point . 6) (:min-point-mag-linear-mip-linear . 7)
    (:min-point-mag-linear-mip-point . 8))
  :documentation "Microsoft.Xna.Framework.Graphics.TextureFilter.")
