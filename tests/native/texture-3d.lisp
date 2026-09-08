;;;; texture-3d.lisp --- volume storage, and the two branches it has.
;;;;
;;;; **This type has two truthful answers and this file asserts both.**
;;;;
;;;; The renderers CNA-Lisp's ordinary qualification uses -- HEADLESS and
;;;; SOFTWARE -- have no volume storage, and `cna_texture3d_create' answers
;;;; CNA_RESULT_NOT_SUPPORTED on all three admitted ABIs. That is not a defect
;;;; and not a gap in this binding: the route documents itself as creating one
;;;; "when the selected renderer supports volume storage". The tests here that
;;;; run in the ordinary suite assert **that refusal**, so a CNA whose HEADLESS
;;;; renderer grew volume storage would fail a test rather than quietly change
;;;; what this binding claims.
;;;;
;;;; The positive branch needs a renderer that has it. `tools/qualification/
;;;; texture3d.sh' runs the claim functions at the bottom of this file against a
;;;; CNA built with the desktop-core EasyGL profile, on Mesa llvmpipe under Xvfb,
;;;; and requires each claim by name. It is a lane of its own rather than a
;;;; section of the suite, for two measured reasons that RUN-TEXTURE3D-CLAIM
;;;; deals with and the ordinary suite must not have to:
;;;;
;;;; * **EasyGL cannot create a GraphicsDevice once the last one has been
;;;;   destroyed.** Its video subsystem comes down with the last device and does
;;;;   not go back up, and `cna_graphics_device_create' segfaults across that
;;;;   gap. It is *not* limited to one device at a time -- four devices created
;;;;   and destroyed beside one that stays alive all work -- so the fix is to
;;;;   keep one alive for the whole process, which is what
;;;;   WITH-EASYGL-VIDEO-SUBSYSTEM does. HEADLESS and SOFTWARE survive the gap.
;;;; * **SBCL traps floating-point exceptions that Mesa raises.** SBCL unmasks
;;;;   invalid, overflow and divide-by-zero by default, llvmpipe raises them in
;;;;   the ordinary course of rasterising, and the trap arrives as a condition
;;;;   from inside a foreign call. Masking them is what any Lisp program driving
;;;;   a GL stack has to do; `docs/limitations.md' records that the binding does
;;;;   not do it for its callers yet.
;;;;
;;;; `docs/texture3d-audit.md' has both measurements.
;;;;
;;;; Everything asserted about CNA below was measured first through the C ABI
;;;; alone, by `tools/qualification/texture3d-matrix.sh'.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defvar *texture3d-evidence* '()
  "What the Texture3D lanes proved, one entry per claim.

A list of (KIND . DESCRIPTION), and the kinds are separate claims on purpose. A
volume that constructs says nothing about whether the voxels it is given come
back; voxels that come back say nothing about whether a sub-volume write left the
rest alone; and none of it says anything about which object
`GraphicsResource.GraphicsDevice' answers.")

(defun note-texture3d (kind description &rest arguments)
  (unless (assoc kind *texture3d-evidence*)
    (push (cons kind (apply #'format nil description arguments)) *texture3d-evidence*)))

(defun texture3d-proved-p (kind)
  (assoc kind *texture3d-evidence*))

;;; --- the pattern ---------------------------------------------------------
;;;
;;; Nonuniform on every axis, so a transposed axis, a reversed slice or a
;;; row/slice pitch mistake cannot round-trip by accident. The same arithmetic
;;; the native probe uses, so the two measurements are comparable.

(defun volume-voxel (x y z &optional (salt 0))
  (xna:make-color (mod (+ 16 (* 40 x) salt) 256)
                  (mod (+ 16 (* 40 y) salt) 256)
                  (mod (+ 16 (* 40 z) salt) 256)
                  255))

(defun volume-fill (width height depth &optional (salt 0))
  "A vector of WIDTH*HEIGHT*DEPTH voxels, row-major within a slice, front to back."
  (let ((data (make-array (* width height depth))))
    (dotimes (z depth data)
      (dotimes (y height)
        (dotimes (x width)
          (setf (aref data (+ (* (+ (* z height) y) width) x))
                (volume-voxel x y z salt)))))))

(defun colors-equal-p (a b)
  (and (= (xna:color-r a) (xna:color-r b))
       (= (xna:color-g a) (xna:color-g b))
       (= (xna:color-b a) (xna:color-b b))
       (= (xna:color-a a) (xna:color-a b))))

(defun volumes-equal-p (a b)
  (and (= (length a) (length b))
       (every #'colors-equal-p a b)))

(defun blank-volume (count)
  (let ((data (make-array count)))
    (dotimes (index count data)
      (setf (aref data index) (xna:make-color 0 0 0 0)))))

(defun volume-storage-available-p (device)
  "True when DEVICE's renderer can actually create a Texture3D.

Asked by creating one, because that is the only way to ask: the answer is a
property of the renderer the library was built with and no route reports it."
  (handler-case
      (let ((texture (make-instance 'gfx:texture-3d :graphics-device device
                                                    :width 2 :height 2 :depth 2)))
        (xna:dispose texture)
        t)
    (xna:cna-not-supported-error () nil)))

;;; --- the ordinary suite: the guards, and the refusal ---------------------
;;;
;;; Everything here works on a renderer with no volume storage, because
;;; everything here is refused **before** CNA is reached. XNA's constructor
;;; refuses in a fixed order and stops at the first refusal, so the order is
;;; itself observable and is asserted rather than the set of refusals.

(define-native-test texture-3d-constructor-guards-come-in-xna-s-order
  "Texture3D's constructor refuses in the order Texture3D::CreateTexture does.

Read from the pinned Graphics assembly: graphicsDevice, then width, height and
depth, then the profile's MaxVolumeExtent, its ValidVolumeFormats, the extents
against that maximum, and the aspect ratio. A call that is wrong in two ways has
to name the one XNA would name first, which is why each case below is wrong in
two ways."
  (with-owned-device (device :profile :hi-def)
    ;; No device at all: XNA's ArgumentNullException, before anything else --
    ;; and this call's width is also invalid, so the *name* is what is asserted
    ;; and not merely that something was refused.
    (let ((condition (handler-case
                         (make-instance 'gfx:texture-3d :graphics-device nil
                                        :width 0 :height 4 :depth 4)
                       (xna:cna-argument-error (c) c))))
      (is (equal "graphicsDevice" (xna:cna-error-parameter-name condition))))
    ;; Width before height before depth, each also wrong in the next one.
    (let ((condition (handler-case
                         (make-instance 'gfx:texture-3d :graphics-device device
                                        :width 0 :height 0 :depth 0)
                       (xna:cna-argument-out-of-range-error (c) c))))
      (is (equal "width" (xna:cna-error-parameter-name condition))))
    (let ((condition (handler-case
                         (make-instance 'gfx:texture-3d :graphics-device device
                                        :width 4 :height 0 :depth 0)
                       (xna:cna-argument-out-of-range-error (c) c))))
      (is (equal "height" (xna:cna-error-parameter-name condition))))
    (let ((condition (handler-case
                         (make-instance 'gfx:texture-3d :graphics-device device
                                        :width 4 :height 4 :depth -1)
                       (xna:cna-argument-out-of-range-error (c) c))))
      (is (equal "depth" (xna:cna-error-parameter-name condition))))
    ;; 257 is one past HiDef's MaxVolumeExtent of 256. **CNA creates this and
    ;; XNA does not**, measured on all three admitted ABIs, so the guard is the
    ;; binding's and this is the test that keeps it.
    (signals xna:cna-not-supported-error
      (make-instance 'gfx:texture-3d :graphics-device device
                                     :width 257 :height 4 :depth 4))
    ;; Dxt1 is outside HiDef's ValidVolumeFormats. XNA refuses it on the profile,
    ;; before the device sees it.
    (signals xna:cna-not-supported-error
      (make-instance 'gfx:texture-3d :graphics-device device
                                     :width 8 :height 8 :depth 8 :format :dxt1))))

(define-native-test texture-3d-is-not-a-reach-type-at-all
  "The Reach profile has no Texture3D, and CNA does not know that.

XNA's ProfileCapabilities gives Reach a MaxVolumeExtent of 0, and
`Texture3D::CreateTexture' turns that into NotSupportedException before it
touches the device -- so `Texture3D' is a HiDef-only type there. **CNA creates
one on a Reach device**, measured on all three admitted ABIs and on a renderer
that has volume storage, so the guard is the binding's or nobody's."
  (with-owned-device (device :profile :reach)
    (signals xna:cna-not-supported-error
      (make-instance 'gfx:texture-3d :graphics-device device
                                     :width 4 :height 4 :depth 4))))

(define-native-test texture-3d-refuses-cleanly-on-a-renderer-without-volume-storage
  "A renderer with no volume storage refuses, and says so as a condition.

This is the branch the ordinary qualification renderers take, and it is a
**result** rather than a skip: HEADLESS and SOFTWARE answer
CNA_RESULT_NOT_SUPPORTED on every admitted ABI, and a CNA whose HEADLESS renderer
grew volume storage would fail here rather than quietly changing what this
binding claims. The lane that proves the positive branch is
tools/qualification/texture3d.sh, against an EasyGL build."
  (with-owned-device (device :profile :hi-def)
    (if (volume-storage-available-p device)
        (note-texture3d :storage-available
                        "this renderer has volume storage; the positive claims ~
                         are the EasyGL lane's")
        (progn
          (signals xna:cna-not-supported-error
            (make-instance 'gfx:texture-3d :graphics-device device
                                           :width 4 :height 3 :depth 2))
          (note-texture3d :unsupported-renderer
                          "cna_texture3d_create answered NOT_SUPPORTED and the ~
                           binding reported it as a condition")))))

;;; --- the claims the EasyGL lane requires ---------------------------------
;;;
;;; Each is a function rather than a test, because each needs its own process:
;;; EasyGL faults on a second GraphicsDevice, so one device per process is the
;;; only shape available. `tools/qualification/texture3d.sh' calls them and
;;; requires each `texture3d : <kind>' line by name.

(define-condition texture3d-claim-failed (error)
  ((text :initarg :text :reader texture3d-claim-text))
  (:report (lambda (c s) (format s "~a" (texture3d-claim-text c)))))

(defun claim (ok control &rest arguments)
  (unless ok
    (error 'texture3d-claim-failed :text (apply #'format nil control arguments)))
  t)

(defun texture3d-claim-volume ()
  "One HiDef device: construction, metadata, ownership, transfers, disposal.

Seven claims in one process because one process is one device. Each is recorded
under its own kind, so a run that constructed a volume and transferred nothing
cannot be read as a run that did both."
  (let ((device (make-owned-device :profile :hi-def)))
    (unwind-protect
         (let ((texture (make-instance 'gfx:texture-3d :graphics-device device
                                                       :width 4 :height 3 :depth 2)))
           ;; Metadata, read back from CNA and not from what was asked for.
           (claim (= 4 (gfx:width texture)) "width is ~a" (gfx:width texture))
           (claim (= 3 (gfx:height texture)) "height is ~a" (gfx:height texture))
           (claim (= 2 (gfx:depth texture)) "depth is ~a" (gfx:depth texture))
           (claim (= 1 (gfx:level-count texture)) "level count without mipMap is ~a"
                  (gfx:level-count texture))
           (claim (eq :color (gfx:format-of texture)) "format is ~a"
                  (gfx:format-of texture))
           (note-texture3d :construction
                           "a 4x3x2 Color volume, with width, height, depth, ~
                            level count and format read back out of CNA")

           ;; Ownership: XNA's GraphicsResource.GraphicsDevice is `_parent', read
           ;; with a bare ldfld, so it answers the object the constructor was
           ;; given -- EQ, not merely a device with equal slots.
           (claim (eq device (gfx:graphics-resource-graphics-device texture))
                  "GraphicsDevice answered a different object from the one the ~
                   constructor was given")
           (note-texture3d :owned-device
                           "GraphicsResource.GraphicsDevice is EQ the caller-owned ~
                            device the constructor was given, in a process with no ~
                            game in it")

           ;; The whole of level 0, byte for byte.
           (let* ((written (volume-fill 4 3 2))
                  (read (blank-volume (length written))))
             (gfx:set-data texture written)
             (gfx:get-data texture read)
             (claim (volumes-equal-p written read)
                    "the whole level did not round-trip: wrote ~a, read ~a"
                    written read)
             (note-texture3d :whole-volume
                             "every voxel of level 0 round-tripped byte for byte, ~
                              over a pattern whose R, G and B each vary on their ~
                              own axis")

             ;; One sub-volume, and the rest of the level unmoved. Two claims,
             ;; and the second is the one a wholesale rewrite would fail.
             (let ((patch (volume-fill 2 2 1 100)))
               (gfx:set-data texture patch
                             :level 0 :left 1 :top 1 :front 1 :right 3 :bottom 3 :back 2
                             :start-index 0 :element-count (length patch))
               (let ((back (blank-volume (length patch))))
                 (gfx:get-data texture back
                               :level 0 :left 1 :top 1 :front 1 :right 3 :bottom 3 :back 2
                               :start-index 0 :element-count (length patch))
                 (claim (volumes-equal-p patch back)
                        "the sub-volume did not round-trip"))
               (let ((whole (blank-volume (length written))))
                 (gfx:get-data texture whole)
                 (dotimes (z 2)
                   (dotimes (y 3)
                     (dotimes (x 4)
                       (let* ((index (+ (* (+ (* z 3) y) 4) x))
                              (got (aref whole index))
                              (inside (and (<= 1 x 2) (<= 1 y 2) (= z 1))))
                         (claim (colors-equal-p
                                 got
                                 (if inside
                                     (volume-voxel (- x 1) (- y 1) (- z 1) 100)
                                     (aref written index)))
                                "voxel ~d,~d,~d is ~a and should not be" x y z got)))))
                 (note-texture3d :box
                                 "a sub-volume write reached exactly its own voxels: ~
                                  inside the box the patch, outside it the seed, ~
                                  unmoved"))))

           ;; The element-kind narrowing, refused by name rather than reinterpreted.
           (let ((bytes (make-array 24 :initial-element 7)))
             (claim (handler-case (progn (gfx:set-data texture bytes) nil)
                      (xna:cna-usage-error () t))
                    "a non-COLOR element sequence was accepted")
             (note-texture3d :color-only
                            "a transfer of non-COLOR elements is refused with the ~
                             reason, rather than reinterpreted as CNA_Color"))

           ;; A partial box is not an overload XNA has.
           (claim (handler-case
                      (progn (gfx:set-data texture (volume-fill 4 3 2)
                                           :level 0 :left 1
                                           :start-index 0 :element-count 24)
                             nil)
                    (xna:cna-usage-error () t))
                  "a partial box was accepted")
           (note-texture3d :box-shape
                           "naming some of the seven box coordinates is refused: ~
                            XNA's overload takes all seven or none")

           ;; Disposal. XNA's Width, Height, Depth, LevelCount and Format are bare
           ;; managed-field reads with no CheckDisposed, so they answer afterwards;
           ;; CopyData calls CheckDisposed first, so the transfers do not.
           (xna:dispose texture)
           (claim (xna:disposed-p texture) "the texture does not report itself disposed")
           (claim (= 4 (gfx:width texture)) "Width refused after disposal")
           (claim (= 3 (gfx:height texture)) "Height refused after disposal")
           (claim (= 2 (gfx:depth texture)) "Depth refused after disposal")
           (claim (= 1 (gfx:level-count texture)) "LevelCount refused after disposal")
           (claim (eq :color (gfx:format-of texture)) "Format refused after disposal")
           (claim (eq device (gfx:graphics-resource-graphics-device texture))
                  "GraphicsDevice refused after disposal")
           (claim (handler-case (progn (gfx:get-data texture (blank-volume 24)) nil)
                    (xna:cna-disposed-error () t))
                  "GetData did not refuse after disposal")
           (claim (handler-case (progn (gfx:set-data texture (volume-fill 4 3 2)) nil)
                    (xna:cna-disposed-error () t))
                  "SetData did not refuse after disposal")
           (note-texture3d :disposal
                           "after Dispose the five dimension members and ~
                            GraphicsDevice still answer, as XNA's bare field reads ~
                            do, and both transfers refuse, as CopyData's ~
                            CheckDisposed does")

           ;;; The floating-point boundary, proven on the renderer that can break it.
           ;;; HEADLESS and SOFTWARE never raise, so they cannot support this claim; this
           ;;; lane can, because Mesa raises `invalid' and `divide-by-zero' while it builds
           ;;; a GL context. Everything above ran with SBCL's ordinary traps enabled -- the
           ;;; lane no longer masks anything -- so reaching this line at all is half the
           ;;; claim, and the environment being unchanged is the other half.
           (let ((modes (sb-int:get-floating-point-modes)))
             (claim (member :invalid (getf modes :traps))
                    "the :INVALID trap was not enabled after the foreign boundary")
             (claim (member :divide-by-zero (getf modes :traps))
                    "the :DIVIDE-BY-ZERO trap was not enabled after the foreign boundary")
             (claim (equal (getf modes :traps) (getf *entry-float-modes* :traps))
                    "the trap set changed across the lane: entered ~s, left ~s"
                    (getf *entry-float-modes* :traps) (getf modes :traps))
             (claim (eq (getf modes :rounding-mode) (getf *entry-float-modes* :rounding-mode))
                    "the rounding mode changed across the lane")
             (claim (equal (getf modes :accrued-exceptions)
                           (getf *entry-float-modes* :accrued-exceptions))
                    "the renderer's accrued exception flags leaked to the caller: entered ~
                     ~s, left ~s"
                    (getf *entry-float-modes* :accrued-exceptions)
                    (getf modes :accrued-exceptions))
             ;; And the traps still fire, which is the difference between "restored" and
             ;; "looks restored".
             (claim (handler-case (progn (/ 0f0 0f0) nil)
                      (floating-point-invalid-operation () t))
                    "the caller's :INVALID trap no longer fires after the boundary")
             (note-texture3d :foreign-fp-environment
                             "the whole group ran with SBCL's ordinary float traps live, ~
                              through a renderer that raises invalid and divide-by-zero ~
                              while it builds a GL context, and the trap set, rounding mode ~
                              and accrued flags were unchanged afterwards -- and the ~
                              caller's :INVALID trap still fires")))
      (ignore-errors (xna:dispose device)))))

(defun texture3d-claim-effect-parameter (effect texture)
  "EffectParameter.SetValue(Texture3D) and GetValueTexture3D, on one object.

XNA's getters are guarded on the parameter's **declared** type and answer the
object that was set. CNA's ABI has no route from a native handle back to the
object that names it, so the binding remembers what it bound and cross-checks the
handle -- the same rule GetValueTexture2D follows, and the reason a cloned
wrapper is never manufactured.

**Two parameters, because the two claims need different declarations.** A
parameter declared TEXTURE-3D is where the getter's own guard is provable:
GetValueTexture2D on it must refuse, as XNA's IL refuses it, before touching
anything. A parameter declared TEXTURE is where the *independence* of CNA's four
texture identities is provable, because all three getters are legal on it -- on
the TEXTURE-3D one they are not, and an answer of NIL would be the guard rather
than the storage."
  (with-standalone-parameters (parameters effect
                               ("volume" "" ffi::+effect-parameter-class-object+
                                ffi::+effect-parameter-type-texture3d+)
                               ("surface" "" ffi::+effect-parameter-class-object+
                                ffi::+effect-parameter-type-texture+))
    (let ((declared (gfx:collection-item parameters 0))
          (general (gfx:collection-item parameters 1)))
      ;; The declared-TEXTURE-3D parameter: the getter, and the guard.
      (claim (null (gfx:effect-parameter-value-texture-3d declared))
             "an unset parameter answered something")
      (setf (gfx:effect-parameter-value-texture declared) texture)
      (claim (eq texture (gfx:effect-parameter-value-texture-3d declared))
             "GetValueTexture3D answered a different object from the one set")
      (claim (handler-case (progn (gfx:effect-parameter-value-texture declared) nil)
               (xna:cna-invalid-cast-error () t))
             "GetValueTexture2D was allowed on a parameter declared TEXTURE-3D")

      ;; The declared-TEXTURE parameter: all three getters are legal here, so a
      ;; NIL from the other two is CNA's storage and not a refusal.
      (setf (gfx:effect-parameter-value-texture general) texture)
      (claim (eq texture (gfx:effect-parameter-value-texture-3d general))
             "the general parameter did not answer the volume")
      (claim (null (gfx:effect-parameter-value-texture general))
             "the Texture2D identity answered something after a Texture3D was set")
      (claim (null (gfx:effect-parameter-value-texture-cube general))
             "the TextureCube identity answered something after a Texture3D was set")
      ;; Clearing clears every identity, because XNA has one texture value.
      (setf (gfx:effect-parameter-value-texture general) nil)
      (claim (null (gfx:effect-parameter-value-texture-3d general))
             "clearing left the Texture3D identity holding a handle")
      (note-texture3d :effect-parameter
                      "SetValue(Texture3D) then GetValueTexture3D answered the ~
                       same object; GetValueTexture2D refused on a parameter ~
                       declared TEXTURE-3D as XNA's IL refuses it; on a parameter ~
                       declared TEXTURE the other two identities stayed empty, ~
                       and clearing cleared all of them"))))

(defun texture3d-claim-mip ()
  "One HiDef device: a mipmapped volume, its level count and its levels.

**The level count is recorded rather than asserted against XNA**, and that is the
point of this claim. XNA passes Levels=0 to D3D9's CreateVolumeTexture, which is
a complete chain down to 1x1x1; EasyGL computes the count from width and height
only, citing FNA. They agree for 8x4x3 and differ for 2x2x8. The binding reads
whatever CNA reports and never computes one, so what is asserted here is that
every level CNA claims exists is transferable and that one past it is not."
  (let ((device (make-owned-device :profile :hi-def)))
    (unwind-protect
         (let* ((texture (make-instance 'gfx:texture-3d :graphics-device device
                                                        :width 8 :height 4 :depth 3
                                                        :mip-map t))
                (levels (gfx:level-count texture)))
           (claim (> levels 1) "a mipmapped volume reported ~d level(s)" levels)
           ;; A different prefix on purpose: `texture3d : ' lines are the lane's
           ;; claim protocol and it reads every one of them as a kind, so a
           ;; measured value announced under that prefix is a claim the registry
           ;; does not name -- which is exactly what the lane refuses, and did.
           (format t "~&measured  : level count for 8x4x3 mipMap=T is ~d~%" levels)
           (dotimes (level levels)
             (let* ((w (max 1 (ash 8 (- level))))
                    (h (max 1 (ash 4 (- level))))
                    (d (max 1 (ash 3 (- level))))
                    (written (volume-fill w h d (* 7 level)))
                    (read (blank-volume (length written))))
               (gfx:set-data texture written
                             :level level :left 0 :top 0 :front 0
                             :right w :bottom h :back d
                             :start-index 0 :element-count (length written))
               (gfx:get-data texture read
                             :level level :left 0 :top 0 :front 0
                             :right w :bottom h :back d
                             :start-index 0 :element-count (length read))
               (claim (volumes-equal-p written read)
                      "level ~d (~dx~dx~d) did not round-trip" level w h d)))
           ;; One past the last level is not a level.
           (claim (handler-case
                      (progn (gfx:set-data texture (volume-fill 1 1 1)
                                           :level levels :left 0 :top 0 :front 0
                                           :right 1 :bottom 1 :back 1
                                           :start-index 0 :element-count 1)
                             nil)
                    (xna:cna-error () t))
                  "a transfer at level ~d was accepted on a ~d-level volume"
                  levels levels)
           (note-texture3d :mip
                           "a mipmapped 8x4x3 volume reported ~d levels, every one ~
                            of them round-tripped at its own dimensions, and one ~
                            past the last was refused" levels)
           (xna:dispose texture))
      (ignore-errors (xna:dispose device)))))

(defclass volume-game (counting-game)
  ((manager :initform nil :accessor volume-game-manager)
   (volume :initform nil :accessor volume-game-volume)
   (device :initform nil :accessor volume-game-device)
   (trouble :initform nil :accessor volume-game-trouble))
  (:documentation
   "A game that makes a Texture3D on its own GraphicsDevice, and an effect to
carry it. Both live here rather than in the owned-device claim because an
EffectParameter needs an Effect and an Effect needs a device -- and EasyGL has
room for exactly one device per process."))

(defmethod initialize-instance :after ((game volume-game) &key)
  (setf (volume-game-manager game)
        (make-instance 'xna:graphics-device-manager :game game))
  (setf (xna:graphics-profile (volume-game-manager game)) :hi-def)
  (setf (xna:is-fixed-time-step game) nil))

(defmethod xna:load-content ((game volume-game))
  (call-next-method)
  (handler-case
      (let ((device (xna:graphics-device game)))
        (setf (volume-game-device game) device)
        (let ((texture (make-instance 'gfx:texture-3d :graphics-device device
                                                      :width 4 :height 3 :depth 2)))
          (setf (volume-game-volume game) texture)
          (let* ((written (volume-fill 4 3 2))
                 (read (blank-volume (length written))))
            (gfx:set-data texture written)
            (gfx:get-data texture read)
            (unless (volumes-equal-p written read)
              (setf (volume-game-trouble game)
                    "the game-device volume did not round-trip")))
          ;; The EffectParameter claim, here because this is the process with an
          ;; effect in it. The effect is made for it and disposed by
          ;; WITH-STANDALONE-PARAMETERS, which is that macro's contract.
          (texture3d-claim-effect-parameter
           (make-instance 'gfx:basic-effect :graphics-device device) texture)))
    (error (c) (setf (volume-game-trouble game) (princ-to-string c)))))

(defun texture3d-claim-game-device ()
  "A Game's own GraphicsDevice makes one too, and owns it.

The other half of the dual-device ownership model: on a game's device the native
owner is the *game*, because CNA requires every graphics resource destroyed
before `cna_game_destroy' succeeds. What the public API must still answer is the
device object -- `_parent' -- and this is the claim that it does, without
Texture3D being special-cased back to the active game."
  (let ((game (make-instance 'volume-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (claim (null (volume-game-trouble game)) "~a" (volume-game-trouble game))
           (let ((texture (volume-game-volume game)))
             (claim texture "no volume was created in load-content")
             (claim (eq (volume-game-device game)
                        (gfx:graphics-resource-graphics-device texture))
                    "GraphicsDevice answered a different object from the game's")
             (note-texture3d :game-device
                             "a Texture3D made on a Game's own GraphicsDevice ~
                              answered that device from GraphicsResource.GraphicsDevice, ~
                              transferred its voxels, and was disposed with the game")
             (claim (texture3d-proved-p :effect-parameter)
                    "the effect-parameter claim did not record its evidence")))
      (ignore-errors (xna:dispose game)))))

(defun texture3d-claim-reach ()
  "A Reach device refuses, and the refusal is the binding's own.

Its own process because it is its own device, and EasyGL has room for one."
  (let ((device (make-owned-device :profile :reach)))
    (unwind-protect
         (progn
           (claim (handler-case
                      (progn (make-instance 'gfx:texture-3d :graphics-device device
                                            :width 4 :height 4 :depth 4)
                             nil)
                    (xna:cna-not-supported-error () t))
                  "a Reach device created a Texture3D")
           (note-texture3d :reach-refused
                           "the Reach profile refused a Texture3D on a renderer ~
                            that has volume storage -- so the refusal is XNA's ~
                            ProfileCapabilities and not the renderer's"))
      (ignore-errors (xna:dispose device)))))

(defmacro with-easygl-video-subsystem (&body body)
  "Hold one native GraphicsDevice open for the dynamic extent of BODY.

**Not a workaround for a Texture3D problem, and not decoration.** EasyGL brings
its video subsystem down with the *last* GraphicsDevice and cannot bring it back
up: `cna_graphics_device_create' segfaults across a gap with no device alive in
it, measured on all three admitted ABIs by
`tools/native-abi/texture3d-volume-probe.c'. It is not a one-device-at-a-time
limit -- the probe's `overlap' stage makes and destroys four devices beside one
that stays alive and every one works -- so a process that never lets the count
reach zero uses the ordinary public API exactly as it would on any other
renderer. That is what this holds open, and it is why the claims below can use
`GraphicsAdapter.Adapters', whose transient enumeration device would otherwise
take the subsystem down before the first real device was made.

The handle is created and destroyed through the private FFI on purpose: it is
scaffolding rather than a device any claim is about, and giving it a public
GRAPHICS-DEVICE object would invite a claim to use it."
  (let ((handle (gensym "KEEPALIVE"))
        (parameters (gensym "PARAMETERS"))
        (out (gensym "OUT")))
    `(progn
       (int:ensure-abi-admitted)
       (cffi:with-foreign-objects
           ((,parameters '(:struct ffi::cna-presentation-parameters))
            (,out :uint64))
         (cffi:foreign-funcall "memset" :pointer ,parameters :int 0
                               :size ffi::+sizeof-cna-presentation-parameters+ :void)
         (int:check-result (ffi::%presentation-parameters-init ,parameters)
                           "easygl video subsystem")
         ;; A raw FFI device create, so the binding's own boundary is not in the
         ;; way of it; scaffolding gets the same scoped environment the public
         ;; constructor gets.
         (int:check-result
          (int:with-foreign-float-environment
            (ffi::%graphics-device-create 0 ffi::+graphics-profile-hi-def+
                                          ,parameters ,out))
          "easygl video subsystem")
         (let ((,handle (cffi:mem-ref ,out :uint64)))
           (unwind-protect (progn ,@body)
             (ffi::%graphics-device-destroy ,handle)))))))

(defvar *entry-float-modes* nil
  "The floating-point environment this process had before any CNA call.

The `foreign-fp-environment' claim compares against it, so it has to be read
before the video subsystem is brought up rather than after.")

(defun run-texture3d-claim (name)
  "Run one EasyGL claim group and print what it proved.

Called by `tools/qualification/texture3d.sh', one group per process.
WITH-EASYGL-VIDEO-SUBSYSTEM keeps EasyGL's subsystem up, which is a measured
property of this renderer rather than anything about Texture3D.

**The float traps are not masked here, and that is the claim.** This lane used to
wrap every group in `sb-int:with-float-traps-masked', because Mesa raises
`invalid' and `divide-by-zero' while it builds a GL context and SBCL turns an
enabled trap into a condition. That workaround is gone: the binding now
establishes the scoped environment itself, at the foreign boundary, and puts the
caller's back afterwards. So these groups run under SBCL's ordinary traps -- and
if the boundary regressed, this lane is where it would show."
  (setf *entry-float-modes* (sb-int:get-floating-point-modes))
  (with-easygl-video-subsystem
    (let ((*texture3d-evidence* '()))
      (ecase name
        (:volume (texture3d-claim-volume))
        (:mip (texture3d-claim-mip))
        (:game-device (texture3d-claim-game-device))
        (:reach (texture3d-claim-reach)))
      (dolist (entry (reverse *texture3d-evidence*))
        (format t "~&texture3d : ~(~a~) -- ~a~%" (car entry) (cdr entry)))
      (finish-output))))
