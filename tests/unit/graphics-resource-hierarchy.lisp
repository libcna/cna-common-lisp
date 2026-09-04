;;;; graphics-resource-hierarchy.lisp --- the public GraphicsResource contract.
;;;;
;;;; The pinned metadata records a `baseType` for every selected type, and for
;;;; BlendState, DepthStencilState, RasterizerState, SamplerState,
;;;; VertexDeclaration, Texture and SpriteBatch it is GraphicsResource. Five of
;;;; those hold no CNA handle, and an earlier version of this binding concluded
;;;; from that that they could not be GraphicsResources.
;;;;
;;;; They can, and XNA's own base class shows how: GraphicsResource::get_Name
;;;; reads the device's cache when `_internalHandle != 0' and its own
;;;; `_localName' field otherwise. The handle-less case is in the base class by
;;;; design. These tests pin the public contract that follows from it, so that a
;;;; future refactor cannot quietly take it away again.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

(defparameter *managed-graphics-resources*
  (list (cons "BlendState" (lambda () (make-instance 'gfx:blend-state)))
        (cons "DepthStencilState" (lambda () (make-instance 'gfx:depth-stencil-state)))
        (cons "RasterizerState" (lambda () (make-instance 'gfx:rasterizer-state)))
        (cons "SamplerState" (lambda () (make-instance 'gfx:sampler-state)))
        (cons "VertexDeclaration"
              (lambda ()
                (make-instance 'gfx:vertex-declaration
                               :elements (list (gfx:make-vertex-element
                                                0 :vector3 :position 0))))))
  "The five selected types whose contract says baseType GraphicsResource and
which hold no CNA handle.")

(test every-type-whose-contract-says-graphics-resource-is-one
  ;; The relationship itself. The structural verifier checks this from the
  ;; contract's own baseType now; this checks it in the image, which is where a
  ;; consumer meets it.
  (dolist (row *managed-graphics-resources*)
    (let ((resource (funcall (cdr row))))
      (is (typep resource 'gfx:graphics-resource)
          "~a is not a GRAPHICS-RESOURCE" (car row)))))

(test a-managed-resource-carries-its-own-name
  ;; XNA's _localName: a resource with no native handle keeps its name itself,
  ;; which is exactly what get_Name falls back to when _internalHandle is zero.
  (dolist (row *managed-graphics-resources*)
    (let ((resource (funcall (cdr row))))
      (is (null (gfx:graphics-resource-name resource))
          "~a should start with no name" (car row))
      (setf (gfx:graphics-resource-name resource) "a name of my own")
      (is (equal "a name of my own" (gfx:graphics-resource-name resource))
          "~a did not keep its name" (car row)))))

(test a-managed-resource-carries-a-tag-of-any-lisp-object
  (dolist (row *managed-graphics-resources*)
    (let ((resource (funcall (cdr row)))
          (payload (list :anything #'car "and a string")))
      (is (null (gfx:tag resource)))
      (setf (gfx:tag resource) payload)
      (is (eq payload (gfx:tag resource))))))

(test an-unapplied-resource-has-no-graphics-device
  ;; XNA reads _parent, which Apply sets and which is null before then. A
  ;; projection that answered the active game's device would be claiming an
  ;; association the object does not have.
  (dolist (row *managed-graphics-resources*)
    (let ((resource (funcall (cdr row))))
      (is (null (gfx:graphics-resource-graphics-device resource))
          "~a claims a device before it was applied to one" (car row)))))

(test a-managed-resource-disposes-once-and-idempotently
  (dolist (row *managed-graphics-resources*)
    (let* ((resource (funcall (cdr row)))
           (raised 0))
      (is (null (gfx:graphics-resource-is-disposed resource)))
      (is (null (xna:disposed-p resource)))
      (gfx:add-disposing-handler resource
                                 (lambda (sender)
                                   (incf raised)
                                   (is (eq sender resource)
                                       "~a raised Disposing with the wrong sender"
                                       (car row))))
      (xna:dispose resource)
      (is (= 1 raised) "~a raised Disposing ~d time(s), not once" (car row) raised)
      (is (eq t (gfx:graphics-resource-is-disposed resource)))
      (is (eq t (xna:disposed-p resource)))
      ;; IDisposable.Dispose is idempotent, and the event is raised once.
      (xna:dispose resource)
      (is (= 1 raised) "~a raised Disposing again on a second dispose" (car row)))))

(test a-removed-disposing-handler-is-not-called
  (let* ((resource (make-instance 'gfx:blend-state))
         (called nil)
         (handler (lambda (sender) (declare (ignore sender)) (setf called t))))
    (gfx:add-disposing-handler resource handler)
    (is (gfx:remove-disposing-handler resource handler))
    (xna:dispose resource)
    (is (null called) "a removed handler was called anyway")))

(test a-managed-resource-refuses-an-event-it-does-not-raise
  (signals xna:cna-usage-error
    (xna::%subscribe-event (make-instance 'gfx:blend-state) :activated #'identity)))

(test the-predefined-instances-carry-the-names-xna-gives-them
  ;; XNA's private constructors call GraphicsResource::set_Name with these exact
  ;; strings, so they are the resource's Name and not a second private concept.
  (is (equal "BlendState.Opaque" (gfx:graphics-resource-name (gfx:blend-state-opaque))))
  (is (equal "BlendState.AlphaBlend"
             (gfx:graphics-resource-name (gfx:blend-state-alpha-blend))))
  (is (equal "DepthStencilState.None"
             (gfx:graphics-resource-name (gfx:depth-stencil-state-none))))
  (is (equal "RasterizerState.CullCounterClockwise"
             (gfx:graphics-resource-name
              (gfx:rasterizer-state-cull-counter-clockwise))))
  (is (equal "SamplerState.PointClamp"
             (gfx:graphics-resource-name (gfx:sampler-state-point-clamp))))
  (is (equal "VertexPositionColor.VertexDeclaration"
             (gfx:graphics-resource-name
              (gfx:vertex-position-color-vertex-declaration)))))

(test a-predefined-instance-is-still-read-only-for-its-state
  ;; The GraphicsResource half is not the state half: Name and Tag come from the
  ;; base and are ordinary managed fields, while the state properties are behind
  ;; ThrowIfBound. XNA's predefined instances are constructed already bound.
  (let ((opaque (gfx:blend-state-opaque)))
    (signals xna:cna-invalid-state-error
      (setf (gfx:color-source-blend opaque) :zero))
    ;; And the refusal names the instance, which it can only do because the name
    ;; is the resource's own.
    (handler-case (setf (gfx:color-source-blend opaque) :zero)
      (xna:cna-invalid-state-error (condition)
        (is (search "BlendState.Opaque" (princ-to-string condition)))))))

(test the-managed-branch-holds-no-native-anything
  ;; The point of the split: a managed-only resource is a GraphicsResource and is
  ;; not a NATIVE-OBJECT, so there is no handle for it to fabricate.
  (dolist (row *managed-graphics-resources*)
    (let ((resource (funcall (cdr row))))
      (is (not (typep resource 'int:native-object))
          "~a is a NATIVE-OBJECT; it holds no handle and must not claim to"
          (car row)))))
