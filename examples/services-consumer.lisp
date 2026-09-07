;;;; services-consumer.lisp --- the whole service and device-selection flow,
;;;; using only CNA-Lisp's public API.
;;;;
;;;; **What this is for.** The services tests reach the internal package twice:
;;;; once for `INT:CALLBACK-REGISTRY-COUNT', to say a registration was released,
;;;; and once for `INT:CHILDREN-OF', to say a rollback left no live child. Both
;;;; are legitimate for a test and neither is available to a program. This file
;;;; is the independent evidence that none of it is *needed*: it runs the whole
;;;; flow -- inspect `Game.Services', put a service of its own in it, construct a
;;;; `GraphicsDeviceManager', retrieve that manager through **both** interface
;;;; keys and drive it through the interface protocol, build a `ContentManager'
;;;; through the service provider, attach a `PreparingDeviceSettings' handler and
;;;; watch it change the device -- through nothing but the two exported packages,
;;;; and prints machine-readable lines a script can check.
;;;;
;;;; **The interface calls are the point.** `IGraphicsDeviceManager' is retrieved
;;;; from the container and then called through `CREATE-DEVICE',
;;;; `BEGIN-DRAW-DEVICE' and `END-DRAW-DEVICE' without ever naming the concrete
;;;; class -- which is the actual `IServiceProvider' use case and the thing a
;;;; two-slot container could not support.
;;;;
;;;; **The audit this file has to pass** is in the script that runs it, and it is
;;;; mechanical: no `CNA-LISP.INTERNAL', no `CFFI', no handle, no result code and
;;;; no private `%'-symbol.
;;;;
;;;; It needs no display, no GPU and no content: everything it does is lifecycle
;;;; and configuration, which is why this closure qualifies under HEADLESS.

(defpackage #:cna-lisp-services-consumer
  (:use #:cl)
  (:local-nicknames (#:xna #:microsoft.xna.framework)
                    (#:gfx #:microsoft.xna.framework.graphics)
                    (#:content #:microsoft.xna.framework.content))
  (:export #:main))

(in-package #:cna-lisp-services-consumer)

(defclass score-keeper ()
  ((score :initform 0 :accessor score))
  (:documentation
   "A service of the program's own, under a type CNA has no identity for.

The whole argument for projecting `GameServiceContainer' as an arbitrary
dictionary rather than as CNA's two slots is that a program can do this."))

(defclass consumer-game (xna:game)
  ((manager :initform nil :accessor manager)
   (settings-calls :initform 0 :accessor settings-calls)
   (reported :initform nil :accessor reported))
  (:documentation "A game that exercises the service surface and then exits."))

(defmethod initialize-instance :after ((game consumer-game) &key)
  ;; XNA constructs its manager in the game's constructor, and so does this.
  (setf (manager game) (make-instance 'xna:graphics-device-manager :game game)))

(defun report (label format &rest arguments)
  "One machine-readable line the qualification script greps for."
  (format t "~&SERVICES-CONSUMER ~a ~?~%" label format arguments)
  (finish-output))

(defmethod xna:load-content ((game consumer-game))
  (let ((services (xna:services game)))

    ;; 1. The container is the game's own, and the same object every read.
    (report "container" "~a" (if (eq services (xna:services game))
                                 "same-object" "DIFFERENT"))

    ;; 2. A service of the program's own, under a type CNA cannot name.
    (let ((keeper (make-instance 'score-keeper)))
      (setf (score keeper) 4200)
      (xna:add-service services 'score-keeper keeper)
      (report "custom" "~a score=~d"
              (if (eq keeper (xna:get-service services 'score-keeper))
                  "round-tripped" "LOST")
              (score (xna:get-service services 'score-keeper))))

    ;; 3. The manager under both canonical interface keys, and it is one object.
    (let ((as-manager (xna:get-service services 'xna:igraphics-device-manager))
          (as-service (xna:get-service services 'xna:igraphics-device-service)))
      (report "both-keys" "~a"
              (if (and (eq as-manager (manager game)) (eq as-manager as-service))
                  "one-object" "NOT-ONE-OBJECT"))

      ;; 4. **Driven through the interface**, never through the concrete class.
      ;;    A PreparingDeviceSettings handler is attached first, so that the
      ;;    CREATE-DEVICE below runs device preparation with it installed.
      (xna:add-preparing-device-settings-handler
       as-manager
       (lambda (sender args)
         (declare (ignore sender))
         (incf (settings-calls game))
         (let ((parameters (xna:presentation-parameters-of
                            (xna:graphics-device-information args))))
           (setf (gfx:back-buffer-width parameters) 1280
                 (gfx:back-buffer-height parameters) 720))))
      (xna:create-device as-manager)
      (let ((may-draw (xna:begin-draw-device as-manager)))
        (when may-draw (xna:end-draw-device as-manager))
        (report "interface" "create=ok begin-draw=~a end-draw=~a"
                (if may-draw "true" "false") (if may-draw "ok" "skipped")))

      ;; 5. The handler changed the device the manager made. Read back through
      ;;    the graphics device the *service* interface answers, not the game's.
      (let ((parameters (gfx:presentation-parameters (xna:graphics-device as-service))))
        (report "settings" "calls=~d back-buffer=~dx~d"
                (settings-calls game)
                (gfx:back-buffer-width parameters)
                (gfx:back-buffer-height parameters)))

      ;; 6. A ContentManager built through the service provider, and its provider
      ;;    is the exact container it was given.
      (let ((assets (make-instance 'content:content-manager
                                   :service-provider services
                                   :root-directory "Content")))
        (unwind-protect
             (report "content" "provider=~a root=~s"
                     (if (eq services (content:service-provider assets))
                         "same-object" "DIFFERENT")
                     (content:root-directory assets))
          (xna:dispose assets)))

      ;; 7. Game.Content's provider is Game.Services too, so there is one
      ;;    container and not two.
      (report "game-content" "~a"
              (if (eq services (content:service-provider (xna:content game)))
                  "same-object" "DIFFERENT"))

      ;; 8. Removing a canonical key, and the custom one surviving it.
      (xna:remove-service services 'xna:igraphics-device-service)
      (report "removed" "service=~a manager=~a custom=~a"
              (if (xna:get-service services 'xna:igraphics-device-service)
                  "STILL-THERE" "gone")
              (if (xna:get-service services 'xna:igraphics-device-manager)
                  "kept" "GONE")
              (if (xna:get-service services 'score-keeper) "kept" "GONE"))))
  (setf (reported game) t)
  (xna:exit game))

(defun main ()
  "Run one session and answer a process exit code."
  (let ((game (make-instance 'consumer-game)))
    (unwind-protect
         (progn
           (xna:run game)
           (unless (reported game)
             (report "error" "load-content never ran")
             (return-from main 1))
           (report "done" "the session completed through the public API alone")
           0)
      (progn (ignore-errors (xna:dispose (manager game)))
             (ignore-errors (xna:dispose game))))))
