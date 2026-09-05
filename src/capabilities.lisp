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
    (microsoft.xna.framework +bounding-frustum-plane-count+
     "The number of planes a frustum has. XNA keeps its own NumPlanes constant
      private, but the six plane readers are public, so a caller iterating them
      needs the count from somewhere other than a literal 6.")
    (microsoft.xna.framework bounding-frustum-equal
     "BoundingFrustum.Equals and op_Equality as a named predicate, for the same
      reason the value types have one: Common Lisp has no operator overloading.")
    (microsoft.xna.framework rectangle-contains-coordinates
     "Rectangle.Contains(int, int). Its three arguments cannot share a congruent
      generic function with the two-argument overloads.")
    (microsoft.xna.framework
     component-count component-at components-of add-component insert-component
     remove-component remove-component-at clear-components contains-component
     component-index
     "GameComponentCollection's own operations. XNA inherits them from
      System.Collections.ObjectModel.Collection<IGameComponent>, so the contract
      records them on the BCL type rather than on the XNA one and they are not
      members this projection can map. A collection nothing can be added to would
      be useless, so they are here, named for what they hold rather than as bare
      ADD and REMOVE -- the same reason APPLY-EFFECT-PASS is not APPLY.
      COMPONENT-INDEX answers NIL where XNA's IndexOf answers -1, because a
      position is a non-negative index and -1 is a sentinel.")
    (microsoft.xna.framework
     launch-parameter launch-parameter-names
     "LaunchParameters' own operations. XNA derives the type from
      Dictionary<string, string> and adds nothing at all, so every operation on
      one belongs to the BCL dictionary. These two are the reachable half of it:
      read a value, set or remove one, and list the names.")
    (microsoft.xna.framework.content loadable-asset-types
     "Which asset types LOAD-ASSET has a native route for. XNA's Load<T> is
      generic over any type with a content reader and needs no such list; CNA's
      ABI has one loader per asset type, so the set this binding can honour is
      finite. Naming it is better than discovering it one failure at a time.")
    (microsoft.xna.framework.graphics renderer-name
     "Which renderer is behind the device. XNA has no equivalent; without it a
      headless qualification run cannot be interpreted.")
    (microsoft.xna.framework.graphics texture-2d-from-png-bytes texture-2d-from-png-file
     "The same CNA decode route TEXTURE-2D-FROM-STREAM uses, reached from a byte
      vector and from a pathname instead of from a stream. FromStream itself is
      now projected, so these are no longer standing in for it: they are the two
      shapes a Lisp caller most often already has, and neither has an XNA member
      to be confused with.")
    (microsoft.xna.framework
     cna-error cna-native-error cna-usage-error
     cna-invalid-argument-error cna-invalid-object-error cna-invalid-state-error
     cna-out-of-memory-error cna-io-error cna-not-supported-error cna-platform-error
     cna-thread-error cna-callback-error cna-overflow-error cna-encoding-error
     cna-internal-error cna-shutting-down-error cna-buffer-too-small-error
     cna-disposed-error cna-ownership-error cna-scope-error
     cna-native-library-error cna-abi-rejected-error
     cna-error-operation cna-error-native-message cna-error-object-type
     cna-abi-found-version cna-abi-admitted-versions cna-native-library-path
     cna-callback-underlying-condition
     cna-argument-error cna-argument-out-of-range-error cna-error-parameter-name
     "The condition hierarchy. XNA has exception types of its own, and they are a
      separate closure; these are the conditions a binding over a native runtime
      must have in order to report a native failure as a Lisp condition instead of
      a result code. The CNA result code behind one is deliberately not readable.")
    (microsoft.xna.framework +plane-normalize-epsilon+
     "The binary32 epsilon Plane.Normalize compares its squared length against
      before deciding to do nothing. It is a literal in the assembly rather than a
      named constant there, and naming it here is what lets a test assert the
      early exit instead of describing it.")
    (microsoft.xna.framework +ticks-per-second+ +default-target-elapsed-time-ticks+
     "The TimeSpan tick rate and XNA's default fixed step, as named constants. The
      values are part of the contract; naming them keeps them out of prose.")
    (microsoft.xna.framework color-from-packed-value
     "Constructing a Color from its packed value. XNA reaches this through the
      settable PackedValue property on a default-constructed Color; a constructor
      is the direct way to say it in Lisp.")
    (microsoft.xna.framework window-title
     "The game window's title, reached through the game in one call instead of
      two. GameWindow *is* projected now, so this is a convenience rather than the
      only route: (window-title game) and (title (window game)) read the same CNA
      title, and both read it rather than remembering it. XNA has no Game.Title,
      which is why this is declared here.")
    (microsoft.xna.framework.graphics render-target-binding-equal
     "Structural equality for RenderTargetBinding, for the reason VIEWPORT-EQUAL
      records: the XNA struct has no Equals of its own, and a projected value type
      that cannot be compared is awkward to test.")
    (microsoft.xna.framework.graphics viewport-equal
     "Structural equality for Viewport. The XNA struct has no Equals of its own,
      and a projected value type that cannot be compared is awkward to test.")
    (microsoft.xna.framework.graphics vertex-element-format-size
     "The size in bytes of one VertexElementFormat. XNA keeps the same table
      private, in VertexElementValidator.GetTypeSize, but it is what decides
      whether a VertexDeclaration is legal, so a caller laying out a vertex needs
      it from somewhere other than a literal.")
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
     :status :partial
     :reason-code "by-value-aggregate-needs-shim"
     :reason "cna_graphics_device_set_viewport takes CNA_Viewport (24 bytes) by
              value. The System V AMD64 ABI classifies it MEMORY, which CFFI
              cannot pass without cffi-libffi -- a dependency a released CNA-Lisp
              must not have. The generator proves that refusal and emits a tiny
              private shim that takes the aggregate by pointer and the real route
              by function pointer; the setter goes through it. The shim is
              optional and not shipped prebuilt, so without CNA_LISP_SHIM the
              setter refuses with an actionable condition. See docs/native-abi.md.")
    (:member "Microsoft.Xna.Framework.Graphics.SpriteBatch.DrawString"
     :status :missing
     :reason "Needs SpriteFont, which is a later closure.")
    (:member "Microsoft.Xna.Framework.Graphics.SpriteBatch.Begin(Effect overloads)"
     :status :missing
     :reason "The two Effect-bearing Begin overloads need Effect, which is a later
              closure. The parameter is nullable in XNA, so a projection could
              accept an :EFFECT that may only ever be NIL -- and that would be a
              fourth Begin shape XNA does not have, told from the five-parameter
              one by nothing a caller could act on. The three overloads whose
              arguments exist are projected; these two are measured as missing.")
    (:member "Microsoft.Xna.Framework.Game.Components" :status :missing
     :reason "Needs the game component engine.")
    (:member "Microsoft.Xna.Framework.Game.Content" :status :missing
     :reason "Needs ContentManager."))
  "Absences CNA-Lisp has decided on, rather than not reached yet. Each carries the
reason it is absent; an externally blocked entry carries the evidence too.")
