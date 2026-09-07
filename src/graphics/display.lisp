;;;; display.lisp --- DisplayMode, PresentationParameters, and the two enums.
;;;;
;;;; The device-settings surface a program *reads*. `GraphicsDevice.DisplayMode',
;;;; `.PresentationParameters' and `.GraphicsDeviceStatus' answer these, and CNA
;;;; carries all three as versioned value structs rather than as handles -- so
;;;; neither class here is a NATIVE-OBJECT, neither owns anything, and neither is
;;;; disposed. They are ordinary CLOS objects over a snapshot.
;;;;
;;;; **Read, not remembered.** Each reader copies out of CNA at the moment it is
;;;; asked, exactly as the graphics device resolves its handle per call. A
;;;; `PresentationParameters' a program is holding is therefore a value it was
;;;; given and not a live view -- which is XNA's shape too: `Clone' exists there
;;;; precisely because the object is a settings record that gets copied around.

(in-package #:microsoft.xna.framework.graphics)

(microsoft.xna.framework::define-xna-enum present-interval
  '((:default . 0) (:one . 1) (:two . 2) (:immediate . 3))
  :documentation "Microsoft.Xna.Framework.Graphics.PresentInterval.")

(microsoft.xna.framework::define-xna-enum graphics-device-status
  '((:normal . 0) (:lost . 1) (:not-reset . 2))
  :documentation "Microsoft.Xna.Framework.Graphics.GraphicsDeviceStatus.")

;;; --- DisplayMode -------------------------------------------------------------

(defclass display-mode ()
  ((%width :initarg :width :reader display-mode-width)
   (%height :initarg :height :reader display-mode-height)
   (%format :initarg :format :reader display-mode-format)
   (%aspect-ratio :initarg :aspect-ratio :reader display-mode-aspect-ratio))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.DisplayMode: one display configuration.

A class in XNA and a class here, holding no native resource: CNA answers a
`CNA_DisplayMode' value struct, so this is a snapshot rather than a handle.
Reached through `MICROSOFT.XNA.FRAMEWORK.GRAPHICS:DISPLAY-MODE' on a device."))

(defun display-mode-title-safe-area (display-mode)
  "DisplayMode.TitleSafeArea.

`Viewport.GetTitleSafeArea(0, 0, Width, Height)' in the assembly -- the same
static method `Viewport.TitleSafeArea' calls, with the origin at zero because a
display mode has no offset."
  (%title-safe-area 0 0 (display-mode-width display-mode)
                    (display-mode-height display-mode)))


;;; **No `DISPLAY-MODE-EQUAL', and CNA having a route for one is not a reason.**
;;; `cna_display_mode_equals' compares two modes by width, height and format, and
;;; XNA's `DisplayMode' has **no equality members at all** -- not `Equals(Object)',
;;; not `op_Equality' -- so it is compared by reference there. Projecting the CNA
;;; route would invent a member XNA has not got, which is the same reason
;;; `cna_sprite_font_create' is not a public constructor.

(defmethod print-object ((mode display-mode) stream)
  (print-unreadable-object (mode stream :type t)
    (format stream "~dx~d ~a" (display-mode-width mode) (display-mode-height mode)
            (display-mode-format mode))))

(defun %read-display-mode (pointer)
  "Build a DISPLAY-MODE from a filled CNA_DisplayMode."
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-display-mode) ',name)))
    (make-instance 'display-mode
                   :width (slot cna-lisp.internal.ffi::width)
                   :height (slot cna-lisp.internal.ffi::height)
                   :aspect-ratio (slot cna-lisp.internal.ffi::aspect-ratio)
                   :format (surface-format-from-value (slot cna-lisp.internal.ffi::format)))))

;;; --- PresentationParameters ---------------------------------------------------

(defclass presentation-parameters ()
  ((%back-buffer-width :initarg :back-buffer-width :accessor back-buffer-width)
   (%back-buffer-height :initarg :back-buffer-height :accessor back-buffer-height)
   (%back-buffer-format :initarg :back-buffer-format :accessor back-buffer-format)
   (%depth-stencil-format :initarg :depth-stencil-format :accessor depth-stencil-format)
   (%multi-sample-count :initarg :multi-sample-count :accessor multi-sample-count)
   (%display-orientation :initarg :display-orientation :accessor display-orientation)
   (%presentation-interval :initarg :presentation-interval :accessor presentation-interval)
   (%render-target-usage :initarg :render-target-usage :accessor render-target-usage)
   (%is-full-screen :initarg :is-full-screen :accessor is-full-screen))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.PresentationParameters: the device settings.

    (make-instance 'presentation-parameters)          ; XNA's defaults
    (back-buffer-width (presentation-parameters device))

A settings record, not a resource: it holds no native handle and is not disposed.
`MAKE-INSTANCE' with no arguments is XNA's parameterless constructor, and the
defaults come from `cna_presentation_parameters_init' rather than being restated
here.

**`DeviceWindowHandle' is not projected.** CNA answers the question with
`CNA_RESULT_NOT_SUPPORTED` by design -- a native window handle is not something
the stable C boundary hands out -- and an `IntPtr' is not a thing this projection
has anyway."))

(defun %write-presentation-parameters (pointer parameters)
  "Fill a CNA_PresentationParameters from PARAMETERS."
  (cffi:foreign-funcall
   "memset" :pointer pointer :int 0
   :size cna-lisp.internal.ffi::+sizeof-cna-presentation-parameters+ :void)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-presentation-parameters)
                 ',name)))
    (setf (slot cna-lisp.internal.ffi::struct-size)
          cna-lisp.internal.ffi::+sizeof-cna-presentation-parameters+
          (slot cna-lisp.internal.ffi::struct-version) 1
          (slot cna-lisp.internal.ffi::back-buffer-format)
          (surface-format-value (back-buffer-format parameters))
          (slot cna-lisp.internal.ffi::back-buffer-width) (back-buffer-width parameters)
          (slot cna-lisp.internal.ffi::back-buffer-height) (back-buffer-height parameters)
          (slot cna-lisp.internal.ffi::depth-stencil-format)
          (depth-format-value (depth-stencil-format parameters))
          (slot cna-lisp.internal.ffi::multi-sample-count) (multi-sample-count parameters)
          (slot cna-lisp.internal.ffi::presentation-interval)
          (present-interval-value (presentation-interval parameters))
          (slot cna-lisp.internal.ffi::display-orientation)
          (microsoft.xna.framework:display-orientation-value
           (display-orientation parameters))
          (slot cna-lisp.internal.ffi::render-target-usage)
          (render-target-usage-value (render-target-usage parameters))
          (slot cna-lisp.internal.ffi::is-full-screen)
          (cna-lisp.internal.ffi:cna-bool-of (is-full-screen parameters))
          (slot cna-lisp.internal.ffi::headless-ext) 0))
  pointer)

(defun %read-presentation-parameters (pointer &optional (into nil))
  "Fill INTO, or a fresh object, from a filled CNA_PresentationParameters."
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-presentation-parameters)
                 ',name)))
    (let ((parameters (or into (allocate-instance
                                (find-class 'presentation-parameters)))))
      (setf (back-buffer-format parameters)
            (surface-format-from-value (slot cna-lisp.internal.ffi::back-buffer-format))
            (back-buffer-width parameters) (slot cna-lisp.internal.ffi::back-buffer-width)
            (back-buffer-height parameters) (slot cna-lisp.internal.ffi::back-buffer-height)
            (depth-stencil-format parameters)
            (depth-format-from-value (slot cna-lisp.internal.ffi::depth-stencil-format))
            (multi-sample-count parameters) (slot cna-lisp.internal.ffi::multi-sample-count)
            (presentation-interval parameters)
            (present-interval-from-value (slot cna-lisp.internal.ffi::presentation-interval))
            (display-orientation parameters)
            (microsoft.xna.framework:display-orientation-from-value
             (slot cna-lisp.internal.ffi::display-orientation))
            (render-target-usage parameters)
            (render-target-usage-from-value (slot cna-lisp.internal.ffi::render-target-usage))
            (is-full-screen parameters)
            (cna-lisp.internal.ffi:cna-true-p (slot cna-lisp.internal.ffi::is-full-screen)))
      parameters)))

(defmethod initialize-instance :after ((parameters presentation-parameters) &key)
  "XNA's parameterless constructor, whose defaults are CNA's rather than restated.

`cna_presentation_parameters_init' fills a version-one value with the canonical
defaults. Reading them from there is what keeps this from being a second copy of
a list of numbers that can drift."
  (cffi:with-foreign-object
      (native '(:struct cna-lisp.internal.ffi::cna-presentation-parameters))
    (cffi:foreign-funcall
     "memset" :pointer native :int 0
     :size cna-lisp.internal.ffi::+sizeof-cna-presentation-parameters+ :void)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%presentation-parameters-init native)
     "make-instance 'presentation-parameters" :object-type 'presentation-parameters)
    (%read-presentation-parameters native parameters)))

(defgeneric clone-presentation-parameters (parameters)
  (:documentation
   "PresentationParameters.Clone(): an independent copy.

Named for its type, as CLONE-EFFECT is, rather than putting a bare CLONE into a
package consumers use unqualified. The copy goes through
`cna_presentation_parameters_clone' rather than through SLOT-VALUE, so a field
CNA adds in a later struct version is copied by the routine that knows about
it."))

(defmethod clone-presentation-parameters ((parameters presentation-parameters))
  (cffi:with-foreign-objects
      ((source '(:struct cna-lisp.internal.ffi::cna-presentation-parameters))
       (target '(:struct cna-lisp.internal.ffi::cna-presentation-parameters)))
    (%write-presentation-parameters source parameters)
    (cffi:foreign-funcall
     "memset" :pointer target :int 0
     :size cna-lisp.internal.ffi::+sizeof-cna-presentation-parameters+ :void)
    (setf (cffi:foreign-slot-value
           target '(:struct cna-lisp.internal.ffi::cna-presentation-parameters)
           'cna-lisp.internal.ffi::struct-size)
          cna-lisp.internal.ffi::+sizeof-cna-presentation-parameters+
          (cffi:foreign-slot-value
           target '(:struct cna-lisp.internal.ffi::cna-presentation-parameters)
           'cna-lisp.internal.ffi::struct-version)
          1)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%presentation-parameters-clone source target)
     "clone-presentation-parameters" :object-type 'presentation-parameters)
    (%read-presentation-parameters target)))

(defgeneric presentation-parameters-bounds (parameters)
  (:documentation
   "PresentationParameters.Bounds: the back buffer's rectangle.

Through `cna_presentation_parameters_get_bounds' rather than composed here from
the width and the height, because the composition is the sort of thing that is
obviously right and occasionally is not."))

(defmethod presentation-parameters-bounds ((parameters presentation-parameters))
  (cffi:with-foreign-objects
      ((native '(:struct cna-lisp.internal.ffi::cna-presentation-parameters))
       (bounds '(:struct cna-lisp.internal.ffi::cna-rectangle)))
    (%write-presentation-parameters native parameters)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%presentation-parameters-get-bounds native bounds)
     "presentation-parameters-bounds" :object-type 'presentation-parameters)
    (macrolet ((slot (name)
                 `(cffi:foreign-slot-value
                   bounds '(:struct cna-lisp.internal.ffi::cna-rectangle) ',name)))
      (microsoft.xna.framework:make-rectangle
       (slot cna-lisp.internal.ffi::x) (slot cna-lisp.internal.ffi::y)
       (slot cna-lisp.internal.ffi::width) (slot cna-lisp.internal.ffi::height)))))

(defmethod print-object ((parameters presentation-parameters) stream)
  (print-unreadable-object (parameters stream :type t)
    (format stream "~dx~d ~a~:[~; full-screen~]"
            (back-buffer-width parameters) (back-buffer-height parameters)
            (back-buffer-format parameters) (is-full-screen parameters))))

;;; --- what the device answers ---------------------------------------------------
;;;
;;; Here rather than in graphics-device.lisp, and for the load order rather than
;;; by preference: these readers build the two classes above, which carry
;;; DepthFormat and RenderTargetUsage, which are declared with the render targets.
;;; So this file loads last of the three and the methods come with it.

(defgeneric display-mode (graphics-device)
  (:documentation
   "GraphicsDevice.DisplayMode: the display configuration the device is running.

A fresh snapshot per call, as every device reader here is: CNA lends the device
for a callback's duration and this reads through it at the moment it is asked."))

(defmethod display-mode ((device graphics-device))
  (let ((handle (%resolve-device-handle device "display-mode")))
    (cffi:with-foreign-object (mode '(:struct cna-lisp.internal.ffi::cna-display-mode))
      (cffi:foreign-funcall "memset" :pointer mode :int 0
                            :size cna-lisp.internal.ffi::+sizeof-cna-display-mode+ :void)
      (setf (cffi:foreign-slot-value
             mode '(:struct cna-lisp.internal.ffi::cna-display-mode)
             'cna-lisp.internal.ffi::struct-size)
            cna-lisp.internal.ffi::+sizeof-cna-display-mode+
            (cffi:foreign-slot-value
             mode '(:struct cna-lisp.internal.ffi::cna-display-mode)
             'cna-lisp.internal.ffi::struct-version)
            1)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%graphics-device-get-display-mode handle mode)
       "display-mode" :object-type 'graphics-device)
      (%read-display-mode mode))))

(defgeneric graphics-device-status (graphics-device)
  (:documentation
   "GraphicsDevice.GraphicsDeviceStatus: :NORMAL, :LOST or :NOT-RESET.

The three lifecycle states XNA names. A renderer that never loses its device
answers :NORMAL forever, which is an answer and not an absence."))

(defmethod graphics-device-status ((device graphics-device))
  (let ((handle (%resolve-device-handle device "graphics-device-status")))
    (cffi:with-foreign-object (out :uint32)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%graphics-device-get-status handle out)
       "graphics-device-status" :object-type 'graphics-device)
      (graphics-device-status-from-value (cffi:mem-ref out :uint32)))))

(defgeneric presentation-parameters (graphics-device)
  (:documentation
   "GraphicsDevice.PresentationParameters: the settings the device is running.

A snapshot, and **not** a live view: mutating what this answers changes nothing.
XNA's property answers the device's own object and mutating that changes nothing
either until a `Reset', so the difference is one a program cannot act on -- but it
is a difference, and `Reset' is not projected yet, so there is nothing here that
could act on it either."))

(defmethod presentation-parameters ((device graphics-device))
  ;; **An owned device answers `pPublicCachedParams': the same object every
  ;; time, and a clone of what the constructor was given.** So mutating the
  ;; object a program passed to the constructor changes nothing here, and
  ;; mutating what this answers changes nothing either -- which is exactly XNA,
  ;; where `get_PresentationParameters' is `ldfld pPublicCachedParams' and the
  ;; constructor cloned twice so that neither field is the caller's object.
  ;;
  ;; A game's facade has no constructor argument to have cloned, so it keeps
  ;; answering a fresh snapshot read from CNA. That is a *weaker* answer than
  ;; XNA's -- a fresh object rather than a stable one -- and the difference is
  ;; recorded in docs/limitations.md rather than papered over.
  (when (%owned-device-p device)
    (cna-lisp.internal:check-live device "presentation-parameters")
    (return-from presentation-parameters (%device-owned-presentation-parameters device)))
  (let ((handle (%resolve-device-handle device "presentation-parameters")))
    (cffi:with-foreign-object
        (native '(:struct cna-lisp.internal.ffi::cna-presentation-parameters))
      (cffi:foreign-funcall
       "memset" :pointer native :int 0
       :size cna-lisp.internal.ffi::+sizeof-cna-presentation-parameters+ :void)
      (setf (cffi:foreign-slot-value
             native '(:struct cna-lisp.internal.ffi::cna-presentation-parameters)
             'cna-lisp.internal.ffi::struct-size)
            cna-lisp.internal.ffi::+sizeof-cna-presentation-parameters+
            (cffi:foreign-slot-value
             native '(:struct cna-lisp.internal.ffi::cna-presentation-parameters)
             'cna-lisp.internal.ffi::struct-version)
            1)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%graphics-device-get-presentation-parameters handle native)
       "presentation-parameters" :object-type 'graphics-device)
      (%read-presentation-parameters native))))
