;;;; capabilities.lisp --- what CNA-Lisp claims, and what it deliberately does not.
;;;;
;;;; Introspection can tell the structural verifier which symbols exist. It
;;;; cannot tell it which absences are decisions and which are unfinished work.
;;;; That is what this file records: every deliberate absence, with the reason it
;;;; is absent and the evidence behind the reason.
;;;;
;;;; Nothing here is a claim about a member being present. A member is present
;;;; only if the image says so.

(in-package #:cna-lisp.internal)

(defparameter *binding-extensions*
  '((microsoft.xna.framework dispose disposed-p with-disposal
     "Deterministic disposal. XNA spells disposal differently on each type that
      has it, and CNA-Lisp needs one question and one operation that can be
      applied to anything holding a native resource.")
    (microsoft.xna.framework clr-type-name
     "The .NET type name CNA reports for a projected object, so a structural
      claim can be checked against the runtime instead of asserted.")
    (microsoft.xna.framework total-game-time-seconds elapsed-game-time-seconds
     "Seconds derived from the exact tick counts. The ticks are the value; these
      are convenience.")
    (microsoft.xna.framework predefined-color predefined-color-names
     "Reaching XNA's predefined colours by keyword, which the generated table
      makes exhaustive without 141 exported functions.")
    (microsoft.xna.framework point-equal rectangle-equal vector2-equal color-equal
     "Value equality as functions. Common Lisp has no operator overloading, so
      the == and Equals members project to named predicates.")
    (microsoft.xna.framework rectangle-contains-coordinates
     "Rectangle.Contains(int, int). Its three arguments cannot share a congruent
      generic function with the two-argument overloads.")
    (microsoft.xna.framework.graphics renderer-name
     "Which renderer is behind the device. XNA has no equivalent; without it a
      headless qualification run cannot be interpreted.")
    (microsoft.xna.framework.graphics texture-2d-from-png-bytes texture-2d-from-png-file
     "Texture2D.FromStream over CNA's decode routes. The Stream projection this
      member's real signature needs is not part of this milestone.")
    (microsoft.xna.framework.input keyboard-get-state
     "Keyboard.GetState. Static classes project as <class>-<member> so that
      Mouse and GamePad can join the namespace without colliding."))
  "Public symbols CNA-Lisp adds that are not XNA members, with why each exists.
The structural verifier requires every extension to appear here; an exported
symbol that is neither a mapped XNA member nor a declared extension is a
diagnostic.")

(defparameter *declared-absences*
  '((:type "Microsoft.Xna.Framework.GameComponent" :status :missing
     :reason "The game component engine is not part of Foundation 1.")
    (:type "Microsoft.Xna.Framework.GameWindow" :status :missing
     :reason "Only the window title is reachable in this milestone, and it is
              projected on GAME as WINDOW-TITLE; the window type itself is not
              implemented.")
    (:type "Microsoft.Xna.Framework.Content.ContentManager" :status :missing
     :reason "Content and XNB are a later closure.")
    (:member "Microsoft.Xna.Framework.Graphics.GraphicsDevice.Viewport.set"
     :status :externally-blocked
     :reason-code "by-value-aggregate-not-expressible"
     :reason "cna_graphics_device_set_viewport takes CNA_Viewport (24 bytes) by
              value. The System V AMD64 ABI classifies it MEMORY, and CFFI cannot
              pass a MEMORY-class aggregate without cffi-libffi, which requires
              libffi headers and a C compiler at load time -- a released CNA-Lisp
              must need neither. The refusal is proved by
              tools/native-abi/generate.py rather than asserted; see
              docs/generated/native-abi-manifest.json, blocked_routes.")
    (:member "Microsoft.Xna.Framework.Graphics.SpriteBatch.DrawString"
     :status :missing
     :reason "Needs SpriteFont, which is a later closure.")
    (:member "Microsoft.Xna.Framework.Graphics.SpriteBatch.Begin(state overloads)"
     :status :missing
     :reason "Needs BlendState, SamplerState, DepthStencilState, RasterizerState
              and Effect, none of which is in this milestone.")
    (:member "Microsoft.Xna.Framework.Game.Components" :status :missing
     :reason "Needs the game component engine.")
    (:member "Microsoft.Xna.Framework.Game.Content" :status :missing
     :reason "Needs ContentManager."))
  "Absences CNA-Lisp has decided on, rather than not reached yet. Each carries the
reason it is absent; an externally blocked entry carries the evidence too.")
