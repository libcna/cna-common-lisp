;;;; game-content.lisp --- Game.Content.
;;;;
;;;; Separate from game.lisp because CONTENT-MANAGER must exist first, and
;;;; separate from content-manager.lisp because GAME must.

(in-package #:microsoft.xna.framework)

(defgeneric content (game)
  (:documentation
   "Game.Content: the content manager this game owns.

The same object every time, as XNA's field is. It is a facade over the game's
own manager -- CNA lends that one as a borrowed handle which \"answers the same
handle every time, cannot be destroyed, and is released with its game\" -- so it
is not disposed, and disposing it is refused with a diagnosable condition rather
than a native failure.

**The setter assigns a reference**, as XNA's does: `(content game)' afterwards is
`EQ' to the manager that was assigned, later changes to that manager are visible
through the property because it is the same object, and its provider and its
cache are its own. See `(setf content)'."))

(defgeneric (setf content) (value game)
  (:documentation
   "Game.Content's setter: assign a reference, and nothing else.

    (setf (content game) (make-instance 'content-manager :graphics-device device))
    (eq (content game) that-manager)   ; => T

**The pinned IL is two instructions and a guard**, and this is exactly those:

    IL_0000:  ldarg.1
    IL_0001:  brtrue.s   IL_0009
    IL_0003:  newobj     instance void ArgumentNullException::.ctor()
    IL_0008:  throw
    IL_0009:  ldarg.0
    IL_000a:  ldarg.1
    IL_000b:  stfld      ContentManager Game::content

so NIL is refused and anything else is stored. **No native call is made**, and
that is the point rather than an omission. CNA's
`cna_game_set_content_manager_ext' *copies* -- \"the canonical setter takes a
reference and copies, so this does too\" -- which cannot express XNA's reference
semantics; but nothing needs it to, because CNA's own game never loads through
the manager it copies into. It is written by that route and by the constructor,
and read only by `cna_game_get_content_manager_ext', which is what lends this
binding the facade `CONTENT' answers before anything is assigned. Calling the
setter would therefore change a value nothing observes, at the cost of a copy.

**Ownership does not move**, because a reference store is not an adoption. A
manager built over a graphics device is already an owned child of its game and is
still released with it; the game's own facade, which owns nothing, is simply no
longer the object the property answers. XNA drops its reference the same way and
lets the collector have it. Nothing is disposed here -- XNA's setter disposes
nothing either -- so a program that wants the replaced manager gone disposes it
itself, and a program that keeps a reference to the facade can assign it back.

**This is not checked against the game**, deliberately: XNA's setter tests the
argument for null and nothing else, so a manager belonging to another game, or a
disposed one, is stored here as it would be there and fails where it is used."))

(defmethod (setf content) (value (game game))
  (unless value
    (error 'cna-argument-error
           :operation "(setf content)" :object-type 'game
           :parameter-name "value"
           :format-control
           "Game.Content refuses null: XNA's setter throws ArgumentNullException ~
            before it stores anything, so there is no way to leave a game without a ~
            content manager."))
  (check-type value microsoft.xna.framework.content:content-manager)
  ;; XNA's `stfld', and the whole of the setter. The slot is the same one CONTENT
  ;; fills in lazily, so an assignment made before the first read simply means the
  ;; facade is never built.
  (setf (%game-content game) value))

(defmethod content ((game game))
  (or (%game-content game)
      (setf (%game-content game)
            (let ((manager (make-instance 'microsoft.xna.framework.content:content-manager
                                          :ownership :parent-owned
                                          :owner game
                                          :owner-thread
                                          (cna-lisp.internal:owner-thread-of game))))
              ;; **Game.Content's provider is Game.Services**, and the pinned IL
              ;; is unambiguous about it: the `Game' constructor loads
              ;; `this.gameServices' and passes it to
              ;; `ContentManager..ctor(IServiceProvider)'. So
              ;; `(service-provider (content game))' is `EQ' to
              ;; `(services game)', and no second container exists for content.
              ;;
              ;; Set here rather than through the canonical constructor because
              ;; this manager is a *facade* over the handle CNA lends and has no
              ;; native manager to build -- the provider is the one thing the
              ;; canonical shape contributes that a facade still needs.
              (setf (slot-value manager
                                'microsoft.xna.framework.content::%service-provider)
                    (services game))
              manager))))
