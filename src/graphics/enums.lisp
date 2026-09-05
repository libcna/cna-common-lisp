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

(microsoft.xna.framework::define-xna-enum graphics-profile
  '((:reach . 0) (:hi-def . 1))
  :documentation "Microsoft.Xna.Framework.Graphics.GraphicsProfile.")

(microsoft.xna.framework::define-xna-enum clear-options
  '((:target . 1) (:depth-buffer . 2) (:stencil . 4))
  :documentation
  "Microsoft.Xna.Framework.Graphics.ClearOptions, a flags enum.

Read from the pinned assembly and not from CNA, as every enumeration here is:
Target = 1, DepthBuffer = 2, Stencil = 4, and CNA_CLEAR_OPTION_* happens to agree.
The empty list is the legal zero -- XNA's enum has no named zero member, and
clearing nothing is what an empty mask asks for."
  :flags t)


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

;;; --- the vertex declaration enumerations ---------------------------------------

(microsoft.xna.framework::define-xna-enum vertex-element-format
  '((:single . 0) (:vector2 . 1) (:vector3 . 2) (:vector4 . 3) (:color . 4)
    (:byte4 . 5) (:short2 . 6) (:short4 . 7) (:normalized-short2 . 8)
    (:normalized-short4 . 9) (:half-vector2 . 10) (:half-vector4 . 11))
  :documentation "Microsoft.Xna.Framework.Graphics.VertexElementFormat.")

(microsoft.xna.framework::define-xna-enum vertex-element-usage
  '((:position . 0) (:color . 1) (:texture-coordinate . 2) (:normal . 3)
    (:binormal . 4) (:tangent . 5) (:blend-indices . 6) (:blend-weight . 7)
    (:depth . 8) (:fog . 9) (:point-size . 10) (:sample . 11)
    (:tessellate-factor . 12))
  :documentation "Microsoft.Xna.Framework.Graphics.VertexElementUsage.")

;;; --- the buffer and drawing enumerations ---------------------------------------

(microsoft.xna.framework::define-xna-enum buffer-usage
  '((:none . 0) (:write-only . 1))
  :documentation
  "Microsoft.Xna.Framework.Graphics.BufferUsage.

Not a flags enum, despite the None: XNA declares no FlagsAttribute on it and its
two members are 0 and 1.")

(microsoft.xna.framework::define-xna-enum index-element-size
  '((:sixteen-bits . 0) (:thirty-two-bits . 1))
  :documentation "Microsoft.Xna.Framework.Graphics.IndexElementSize.")

(microsoft.xna.framework::define-xna-enum set-data-options
  '((:none . 0) (:discard . 1) (:no-overwrite . 2))
  :documentation "Microsoft.Xna.Framework.Graphics.SetDataOptions.")

(microsoft.xna.framework::define-xna-enum primitive-type
  '((:triangle-list . 0) (:triangle-strip . 1) (:line-list . 2) (:line-strip . 3))
  :documentation
  "Microsoft.Xna.Framework.Graphics.PrimitiveType.

Four members. CNA has a fifth, CNA_PRIMITIVE_POINT_LIST_EXT, which is a CNA
extension with no XNA counterpart and is deliberately not projected.")

;;; --- the two effect-parameter enumerations ----------------------------------
;;;
;;; Values from the pinned contract. CNA agrees with XNA on both, member for
;;; member, which is worth stating because it is not true of BlendFunction just
;;; above; tests/unit/effects.lisp pins the agreement rather than assuming it
;;; will hold.

(microsoft.xna.framework::define-xna-enum effect-parameter-class
  '((:scalar . 0) (:vector . 1) (:matrix . 2) (:object . 3) (:struct . 4))
  :documentation "Microsoft.Xna.Framework.Graphics.EffectParameterClass.")

(microsoft.xna.framework::define-xna-enum effect-parameter-type
  '((:void . 0) (:bool . 1) (:int32 . 2) (:single . 3) (:string . 4)
    (:texture . 5) (:texture-1d . 6) (:texture-2d . 7) (:texture-3d . 8)
    (:texture-cube . 9))
  :documentation "Microsoft.Xna.Framework.Graphics.EffectParameterType.")
