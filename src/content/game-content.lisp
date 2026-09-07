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

**XNA's setter is not projected, and the member is reported partial for that.**
The reason used to be that CNA's `cna_game_set_content_manager_ext' *copies*
where XNA assigns a reference. That is true of the route and not a reason about
the member, because the member need not use the route: XNA's `set_Content' is a
null check and a plain field store, and CNA's copied manager is read by nothing
in the engine except the route that lends the handle out. So this is local work
rather than an ABI limit, and docs/limitations.md carries the measurement and
what implementing it needs."))

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
