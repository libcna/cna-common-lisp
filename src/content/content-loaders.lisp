;;;; content-loaders.lisp --- the asset types LOAD-ASSET has a route for.
;;;;
;;;; Separate from content-manager.lisp because these produce *graphics* objects
;;;; and so must load after the graphics layer, while the manager itself must load
;;;; before nothing in particular. Each entry is one `cna_content_manager_load_*'
;;;; route, and the table is what makes `Load<T>' a single member rather than
;;;; three differently-named functions.
;;;;
;;;; **One asset load is one transaction, and it is this file's.** Every loader
;;;; here opens exactly one rollback ledger and every native handle the load
;;;; acquires is recorded in it, once, in CNA's required destruction order. The
;;;; adoption helpers in the graphics layer take that ledger's recorder as an
;;;; argument and record only the *Lisp* state they create -- the CLOS object and
;;;; its registration as a child. The rule, which each helper repeats:
;;;;
;;;;     whoever receives a handle from CNA records its destruction.
;;;;
;;;; The shape this replaced had the loader record a handle and then call a helper
;;;; that opened its own ledger and recorded the same handle again. A failure
;;;; inside the helper destroyed the handle twice -- and for a SpriteFont it was
;;;; worse: the atlas was adopted by a ledger that had already committed, so a
;;;; later failure destroyed the atlas handle while the atlas object stayed
;;;; registered as a live child of the game. The game then refused to shut down, a
;;;; whole callback away from the load that broke it.

(in-package #:microsoft.xna.framework.content)

(defmacro %define-asset-loader ((type manager asset-name) &body body)
  "Record BODY as the loader for TYPE, replacing any earlier one."
  `(let ((entry (assoc ',type *asset-loaders*)))
     (flet ((loader (,manager ,asset-name) ,@body))
       (if entry
           (setf (cdr entry) #'loader)
           (setf *asset-loaders*
                 (append *asset-loaders* (list (cons ',type #'loader))))))
     ',type))

(defun %load-one-handle (manager asset-name route operation)
  "Call ROUTE, which answers exactly one owned handle, and give it back."
  (let ((handle (%content-manager-handle manager operation)))
    (cffi:with-foreign-object (out :uint64)
      (setf (cffi:mem-ref out :uint64) 0)
      (cna-lisp.internal:with-utf8-view (data length asset-name)
        (cna-lisp.internal:check-result
         (funcall route handle data length out)
         operation :object-type 'content-manager))
      (cffi:mem-ref out :uint64))))

(defun %loading-game (manager operation)
  "The game that will own what MANAGER loads."
  (let ((game (cna-lisp.internal:owner-of manager)))
    (unless game
      (error 'microsoft.xna.framework:cna-invalid-object-error
             :operation operation :object-type 'content-manager
             :format-control "this content manager has no game to own what it loads."
             :format-arguments '()))
    game))

;;; --- Texture2D and TextureCube ----------------------------------------------

(%define-asset-loader (microsoft.xna.framework.graphics:texture-2d manager asset-name)
  (let* ((operation "load-asset 'texture-2d")
         (game (%loading-game manager operation))
         (handle (%load-one-handle manager asset-name
                                   #'cna-lisp.internal.ffi::%content-manager-load-texture-2d
                                   operation)))
    (cna-lisp.internal:with-native-rollback (record)
      (funcall record (lambda () (cna-lisp.internal.ffi::%texture-2d-destroy handle)))
      (%commit-loaded-asset
       manager asset-name record
       (microsoft.xna.framework.graphics::%adopt-loaded-texture-2d game handle record)))))

(%define-asset-loader (microsoft.xna.framework.graphics:texture-cube manager asset-name)
  (let* ((operation "load-asset 'texture-cube")
         (game (%loading-game manager operation))
         (handle (%load-one-handle manager asset-name
                                   #'cna-lisp.internal.ffi::%content-manager-load-texture-cube
                                   operation)))
    (cna-lisp.internal:with-native-rollback (record)
      (funcall record (lambda () (cna-lisp.internal.ffi::%texturecube-destroy handle)))
      (%commit-loaded-asset
       manager asset-name record
       (microsoft.xna.framework.graphics::%adopt-loaded-texture-cube game handle record)))))

;;; --- SpriteFont -------------------------------------------------------------
;;;
;;; The one loader that answers **two** owned handles: a font is glyph metrics and
;;; the atlas it draws from, and CNA hands both back because "handing back only
;;; the font would leave the atlas alive but unnameable". The rollback has to undo
;;; both, and in CNA's order -- the font first, because the atlas "cannot be
;;; destroyed until this SpriteFont is destroyed".

(%define-asset-loader (microsoft.xna.framework.graphics:sprite-font manager asset-name)
  (let* ((operation "load-asset 'sprite-font")
         (game (%loading-game manager operation))
         (handle (%content-manager-handle manager operation)))
    (cffi:with-foreign-objects ((font-out :uint64) (atlas-out :uint64))
      (setf (cffi:mem-ref font-out :uint64) 0
            (cffi:mem-ref atlas-out :uint64) 0)
      (cna-lisp.internal:with-utf8-view (data length asset-name)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%content-manager-load-sprite-font
          handle data length font-out atlas-out)
         operation :object-type 'microsoft.xna.framework.graphics:sprite-font))
      (let ((font-handle (cffi:mem-ref font-out :uint64))
            (atlas-handle (cffi:mem-ref atlas-out :uint64)))
        (cna-lisp.internal:with-native-rollback (record)
          ;; Recorded atlas-first so the rollback runs it *last*: undo is
          ;; newest-first, and CNA refuses to destroy the atlas while the font
          ;; lives. Recording them the other way round would produce a rollback
          ;; that CNA refuses half of.
          (funcall record
                   (lambda () (cna-lisp.internal.ffi::%texture-2d-destroy atlas-handle)))
          (funcall record
                   (lambda () (cna-lisp.internal.ffi::%sprite-font-destroy font-handle)))
          (multiple-value-call #'%commit-loaded-asset
            manager asset-name record
            (microsoft.xna.framework.graphics::%adopt-loaded-sprite-font
             game font-handle atlas-handle record)))))))

;;; --- Effect -----------------------------------------------------------------
;;;
;;; `cna_content_manager_load_effect' "maps the canonical `Load<Effect>'
;;; specialization, which is the route an XNA game's `ContentManager.Load<Effect>'
;;; takes", and reads three shapes: a compiled `.xnb' Effect asset, a `.cnj'
;;; descriptor naming one of the stock effects, and a `.cnj' descriptor carrying
;;; custom shader source. **Only the compiled shape needs
;;; CNA_GRAPHICS_CAPABILITY_COMPILED_EFFECTS**, which neither qualification
;;; renderer has -- so the descriptor shapes load here, and are tested.

(%define-asset-loader (microsoft.xna.framework.graphics:effect manager asset-name)
  (let* ((operation "load-asset 'effect")
         (game (%loading-game manager operation)))
    (cna-lisp.internal:with-native-rollback (record)
      ;; The handle goes straight into the constructor, which is what receives it
      ;; and therefore what records its destruction. Recording it here as well
      ;; would destroy it twice: a construction that fails has already run its own
      ;; ledger by the time this one runs. See %ADOPT-LOADED-EFFECT.
      (let ((effect (microsoft.xna.framework.graphics::%adopt-loaded-effect
                     game
                     (%load-one-handle
                      manager asset-name
                      #'cna-lisp.internal.ffi::%content-manager-load-effect
                      operation)
                     operation)))
        ;; Construction committed and dropped its ledger, so from here the undo is
        ;; the effect's own disposal, which gives back the whole graph.
        (funcall record (lambda () (microsoft.xna.framework:dispose effect)))
        (%commit-loaded-asset manager asset-name record effect)))))

;;; --- SoundEffect --------------------------------------------------------------
;;;
;;; **CNA's route deliberately does not cache and XNA's `Load<T>' does, so the
;;; managed cache is what a program sees.** `cna_content_manager_load_sound_effect'
;;; says so in its own header -- "the canonical `Load<SoundEffect>' specialization,
;;; which deliberately does not cache: every successful call returns an
;;; independently owned sound effect" -- and XNA's `ContentManager.Load<T>' looks
;;; the cleaned name up in `loadedAssets' before reading anything, whatever T is.
;;; There is no per-type exception to that in the IL.
;;;
;;; So the two sides are reconciled the way every other loader here reconciles
;;; them: `%COMMIT-LOADED-ASSET' caches, and a second `Load<SoundEffect>' of the
;;; same name never reaches CNA at all. Two loads answer **one** object, and
;;; `Unload' disposes it once. Letting CNA's non-caching route through per call
;;; would answer two objects for one name and hand a program two things to dispose
;;; where XNA gives it one.
;;;
;;; A sound effect is one handle for one name -- unlike a SpriteFont, which is two
;;; -- so this is the simple shape: receive the handle, record its destruction,
;;; adopt, commit.

(%define-asset-loader (microsoft.xna.framework.audio:sound-effect manager asset-name)
  (let* ((operation "load-asset 'sound-effect")
         (game (%loading-game manager operation))
         (handle (%load-one-handle
                  manager asset-name
                  #'cna-lisp.internal.ffi::%content-manager-load-sound-effect
                  operation)))
    (cna-lisp.internal:with-native-rollback (record)
      (funcall record (lambda () (cna-lisp.internal.ffi::%sound-effect-destroy handle)))
      (%commit-loaded-asset
       manager asset-name record
       (microsoft.xna.framework.audio::%adopt-loaded-sound-effect game handle record)))))

;;; --- Model --------------------------------------------------------------------
;;;
;;; `cna_content_manager_load_model' "maps the canonical `Load<Model>'
;;; specialization -- the route an XNA game's `ContentManager.Load<Model>' takes".
;;; It reads a compiled `.xnb' model and CNA's own self-contained `.cnj' model
;;; document; the fixture this suite uses is the second, for the reason
;;; `docs/limitations.md' gives for the font and the effect.
;;;
;;; **The model owns what it publishes, and the loader must not record any of
;;; it.** The route's header is explicit: "A loaded part's effect and buffers are
;;; objects the model already owned, and the handles this route creates for them
;;; are released when the model is destroyed -- do not release them by hand". So
;;; there is exactly one handle for this loader to be responsible for, the
;;; model's, and %ADOPT-MODEL is what receives it and therefore what records its
;;; destruction. One asset load, one ledger, as every other loader here.
;;;
;;; **The cache is this binding's, in front of CNA's.** CNA's own route does cache
;;; -- "the asset is cached by name exactly as every other load is, so a second
;;; call re-publishes handles over the same underlying model rather than re-reading
;;; the file" -- but re-publishing answers a *new* model handle over the same
;;; native model, and XNA's `Load<T>' answers the same object. Two model handles
;;; for one name would be two objects for one name and two graphs to keep in step.
;;; So `%COMMIT-LOADED-ASSET' caches, and a second `Load<Model>' never reaches CNA.

(%define-asset-loader (microsoft.xna.framework.graphics:model manager asset-name)
  (let* ((operation "load-asset 'model")
         (game (%loading-game manager operation)))
    (cna-lisp.internal:with-native-rollback (record)
      (let ((model (make-instance 'microsoft.xna.framework.graphics::model
                                  :%adopted-handle
                                  (%load-one-handle
                                   manager asset-name
                                   #'cna-lisp.internal.ffi::%content-manager-load-model
                                   operation)
                                  :%adopted-game game)))
        ;; Construction committed and dropped its own ledger, so from here the undo
        ;; is the model's disposal, which gives the whole graph back.
        (funcall record (lambda () (microsoft.xna.framework:dispose model)))
        (%commit-loaded-asset manager asset-name record model)))))
