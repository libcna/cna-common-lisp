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
      (microsoft.xna.framework.graphics::%adopt-loaded-texture-2d game handle record))))

(%define-asset-loader (microsoft.xna.framework.graphics:texture-cube manager asset-name)
  (let* ((operation "load-asset 'texture-cube")
         (game (%loading-game manager operation))
         (handle (%load-one-handle manager asset-name
                                   #'cna-lisp.internal.ffi::%content-manager-load-texture-cube
                                   operation)))
    (cna-lisp.internal:with-native-rollback (record)
      (funcall record (lambda () (cna-lisp.internal.ffi::%texturecube-destroy handle)))
      (microsoft.xna.framework.graphics::%adopt-loaded-texture-cube game handle record))))

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
          (microsoft.xna.framework.graphics::%adopt-loaded-sprite-font
           game font-handle atlas-handle record))))))
