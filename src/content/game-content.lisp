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

**XNA's setter is not projected.** `Game.Content = m' assigns a reference there;
CNA's `cna_game_set_content_manager_ext' *copies*, so reading the property back
would answer a different object than the one assigned. docs/limitations.md."))

(defmethod content ((game game))
  (or (%game-content game)
      (setf (%game-content game)
            (make-instance 'microsoft.xna.framework.content:content-manager
                           :ownership :parent-owned
                           :owner game
                           :owner-thread (cna-lisp.internal:owner-thread-of game)))))
