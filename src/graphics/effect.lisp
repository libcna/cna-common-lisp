;;;; effect.lisp --- Effect and the object graph hanging off it.
;;;;
;;;; `Effect' is a GraphicsResource with a real CNA handle. Everything else in
;;;; this file -- techniques, passes, parameters, annotations and their four
;;;; collections -- has `System.Object' for a base type in the pinned contract,
;;;; so none of them is a GraphicsResource and none of them is disposable. They
;;;; are, on the CNA side, *owned stable view handles*, and that mismatch is what
;;;; this file is mostly about.
;;;;
;;;; **The graph is built once, at construction.** XNA's Effect builds its
;;;; technique and parameter collections in `InitializeHelpers' and hands out the
;;;; same objects forever after: `effect.Techniques[0]' is `effect.Techniques[0]'
;;;; every time, and `CurrentTechnique' compares by reference. CNA hands back a
;;;; *fresh handle* for each call -- two `cna_effect_get_current_technique' calls
;;;; on one effect answer different handle values -- so a binding that wrapped
;;;; each answer in a new Lisp object would break `eq' where XNA guarantees it.
;;;; So the graph is built eagerly, the Lisp objects are the identity, and
;;;; `cna_effect_technique_get_identity' -- a stable non-pointer token -- is what
;;;; maps a returned handle back to the object that already exists for it.
;;;;
;;;; **Nothing here is disposable, and the effect destroys all of it.** These
;;;; views are owned handles CNA expects back, and CNA refuses to destroy a game
;;;; while any child handle is alive. But XNA has no `technique.Dispose()', so
;;;; they are not registered as disposable children of the effect: DISPOSE on the
;;;; effect would then refuse, telling a consumer to dispose things XNA gives
;;;; them no way to dispose. Instead the effect owns them for staleness -- using
;;;; a technique after its effect is disposed refuses, rather than calling
;;;; through a handle CNA may have reissued -- and destroys every one of them
;;;; itself, leaves first, in DESTROY-NATIVE.
;;;;
;;;; **A collection indexer answers NIL rather than signalling.** Read from the
;;;; IL, because it is not what one would guess: `EffectTechniqueCollection'
;;;; `get_Item(int32)' branches on `index < 0' and `index >= Count' straight to
;;;; `ldnull; ret', and `get_Item(string)' walks the list and returns null when
;;;; no name matches. All four collections do the same. An out-of-range index is
;;;; not an exception in XNA and it is not a condition here.

(in-package #:microsoft.xna.framework.graphics)

;;; --- the native vocabulary -------------------------------------------------

(defparameter %effect-parameter-class-to-native
  `((:scalar . ,cna-lisp.internal.ffi::+effect-parameter-class-scalar+)
    (:vector . ,cna-lisp.internal.ffi::+effect-parameter-class-vector+)
    (:matrix . ,cna-lisp.internal.ffi::+effect-parameter-class-matrix+)
    (:object . ,cna-lisp.internal.ffi::+effect-parameter-class-object+)
    (:struct . ,cna-lisp.internal.ffi::+effect-parameter-class-struct+)))

(defparameter %effect-parameter-type-to-native
  `((:void . ,cna-lisp.internal.ffi::+effect-parameter-type-void+)
    (:bool . ,cna-lisp.internal.ffi::+effect-parameter-type-bool+)
    (:int32 . ,cna-lisp.internal.ffi::+effect-parameter-type-int32+)
    (:single . ,cna-lisp.internal.ffi::+effect-parameter-type-single+)
    (:string . ,cna-lisp.internal.ffi::+effect-parameter-type-string+)
    (:texture . ,cna-lisp.internal.ffi::+effect-parameter-type-texture+)
    (:texture-1d . ,cna-lisp.internal.ffi::+effect-parameter-type-texture1d+)
    (:texture-2d . ,cna-lisp.internal.ffi::+effect-parameter-type-texture2d+)
    (:texture-3d . ,cna-lisp.internal.ffi::+effect-parameter-type-texture3d+)
    (:texture-cube . ,cna-lisp.internal.ffi::+effect-parameter-type-texture-cube+)))

(defun %effect-parameter-class-from-native (value)
  (or (car (rassoc value %effect-parameter-class-to-native))
      (error 'microsoft.xna.framework:cna-invalid-object-error
             :operation "effect-parameter-parameter-class"
             :format-control "CNA reported effect-parameter class ~d, which XNA does not have."
             :format-arguments (list value))))

(defun %effect-parameter-type-from-native (value)
  (or (car (rassoc value %effect-parameter-type-to-native))
      (error 'microsoft.xna.framework:cna-invalid-object-error
             :operation "effect-parameter-parameter-type"
             :format-control "CNA reported effect-parameter type ~d, which XNA does not have."
             :format-arguments (list value))))

;;; --- shared plumbing -------------------------------------------------------

(defclass %effect-view (cna-lisp.internal:native-object)
  ((%effect :initarg :effect :reader %view-effect
            :documentation "The EFFECT this view belongs to, for staleness."))
  (:documentation
   "Private base of the four non-disposable things CNA hands out as owned view
handles: a technique, a pass, a parameter and an annotation. Each is a
NATIVE-OBJECT so that using one after its effect is gone refuses rather than
reaching a reissued handle, and none of them is disposable, because none of
XNA's is."))

(defun %retain-native-part (effect handle destroyer)
  "Record an owned CNA handle EFFECT must give back, and answer it.

Every handle the effect takes goes through here, newest first, and DESTROY-NATIVE
walks the same list. That is the point: destruction used to be a second copy of
the construction walk, and a view kind added to one and forgotten in the other
would leak a handle CNA is still owed -- which shows up much later as a game that
will not shut down, nowhere near the effect that leaked it.

Newest-first is also leaf-first, because a collection handle is always taken
before the elements read out of it."
  (push (cons handle destroyer) (%effect-native-parts effect))
  handle)

(defun %release-native-parts (effect &key quietly)
  "Give every recorded handle back, newest first.

Answers the first native failure rather than the last, and keeps going after it:
a handle that could not be released is bad news, but stopping would leave every
handle behind it alive as well. QUIETLY is for the construction rollback, where a
failure here must not mask the one that caused the rollback."
  (let ((first-failure nil))
    (dolist (part (%effect-native-parts effect))
      (destructuring-bind (handle . destroyer) part
        (unless (zerop handle)
          (if quietly
              (ignore-errors (funcall destroyer handle))
              (handler-case
                  (cna-lisp.internal:check-result
                   (funcall destroyer handle) "dispose" :object-type (type-of effect))
                (error (condition)
                  (unless first-failure (setf first-failure condition))))))))
    (setf (%effect-native-parts effect) '())
    first-failure))

(defun %adopt-view (view effect)
  "Give VIEW the effect's thread and generation without making it a child.

REGISTER-CHILD would put it on the effect's disposable-children list, and DISPOSE
refuses while that list is non-empty -- which would demand a consumer dispose
objects XNA gives them no way to dispose. The effect destroys these itself."
  (setf (slot-value view 'cna-lisp.internal::owner) effect
        (slot-value view 'cna-lisp.internal::owner-thread)
        (cna-lisp.internal:owner-thread-of effect))
  (setf (cna-lisp.internal:owner-generation-of view)
        (cna-lisp.internal:generation-of effect))
  view)

(defmethod microsoft.xna.framework:dispose ((view %effect-view))
  ;; The refusal has to be here rather than in DESTROY-NATIVE. The base DISPOSE
  ;; calls DESTROY-NATIVE inside an UNWIND-PROTECT whose cleanup drops the
  ;; handle, so refusing one level down would *still* zero the handle -- and the
  ;; effect would then skip a view CNA is still owed, which shows up much later
  ;; as a game that will not shut down.
  (error 'microsoft.xna.framework:cna-usage-error
         :operation "dispose"
         :object-type (type-of view)
         :format-control
         "~a is not disposable. XNA has no Dispose on it, and the Effect that owns ~
          it releases it. Dispose the Effect."
         :format-arguments (list (type-of view))))

(defun %view-handle (view operation)
  (cna-lisp.internal:check-usable view operation)
  (cna-lisp.internal:handle-of view))

(defun %view-name (handle size-route copy-route operation)
  "A view's Name, through CNA's count-then-copy idiom.

Called once, when the graph is built: XNA's technique and pass names are fields
of objects made at construction, so the projection caches them the same way
rather than crossing the ABI for a string that cannot change."
  (cna-lisp.internal:count-then-copy-string
   (lambda (out) (funcall size-route handle out))
   (lambda (buffer capacity out) (funcall copy-route handle buffer capacity out))
   operation))

;;; --- collections -----------------------------------------------------------
;;;
;;; All four are the same shape: a fixed vector of already-built objects, a
;;; count, an index accessor and a name accessor, both answering NIL for a miss.

(defclass %effect-collection ()
  ((%items :initarg :items :reader %collection-items :initform #()))
  (:documentation
   "Private base of the four effect collections. Each is fixed at construction,
because the effect it describes is."))

(defgeneric collection-count (collection)
  (:documentation
   "The number of elements in an effect collection: XNA's Count on all four of
EffectTechniqueCollection, EffectPassCollection, EffectParameterCollection and
EffectAnnotationCollection.")
  (:method ((collection %effect-collection))
    (length (%collection-items collection))))

(defgeneric collection-item (collection key)
  (:documentation
   "An effect collection's indexer, by zero-based index or by name.

**Answers NIL for a miss, and that is XNA's behaviour, not a simplification.**
The pinned IL's `get_Item(int32)' branches on a negative index and on one that is
not below Count straight to `ldnull; ret'; `get_Item(string)' walks the elements
and returns null when no name matches. Neither throws.")
  (:method ((collection %effect-collection) (index integer))
    (let ((items (%collection-items collection)))
      (when (and (>= index 0) (< index (length items)))
        (aref items index))))
  (:method ((collection %effect-collection) (name string))
    (find name (%collection-items collection)
          :key #'%collection-element-name :test #'string=)))

(defgeneric %collection-element-name (element)
  (:documentation "The name a collection's by-name indexer matches against."))

(defgeneric collection-elements (collection)
  (:documentation
   "The elements of an effect collection as a Lisp list, in order.

XNA spells this `GetEnumerator()' and returns a List<T>.Enumerator. Common Lisp
iterates over sequences, so the projection hands back a fresh list rather than a
stateful cursor object with no Lisp meaning.")
  (:method ((collection %effect-collection))
    (coerce (%collection-items collection) 'list)))

;;; --- EffectAnnotation ------------------------------------------------------

(defclass effect-annotation (%effect-view)
  ((%name :reader effect-annotation-name)
   (%semantic :reader effect-annotation-semantic)
   (%row-count :reader effect-annotation-row-count)
   (%column-count :reader effect-annotation-column-count)
   (%parameter-class :reader effect-annotation-parameter-class)
   (%parameter-type :reader effect-annotation-parameter-type))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.EffectAnnotation: one piece of metadata an
effect author attached to a technique, a pass or a parameter.

Immutable: XNA has eight GetValue* methods on it and no setter at all. Its
metadata is read once, when the effect's graph is built."))

(defclass effect-annotation-collection (%effect-collection) ()
  (:documentation "Microsoft.Xna.Framework.Graphics.EffectAnnotationCollection."))

(defmethod %collection-element-name ((element effect-annotation))
  (effect-annotation-name element))

(defun %read-annotation-info (handle annotation)
  (cffi:with-foreign-object (info '(:struct cna-lisp.internal.ffi::cna-effect-annotation-info))
    (cffi:foreign-funcall "memset" :pointer info :int 0
                          :size cna-lisp.internal.ffi::+sizeof-cna-effect-annotation-info+ :void)
    (macrolet ((slot (name)
                 `(cffi:foreign-slot-value
                   info '(:struct cna-lisp.internal.ffi::cna-effect-annotation-info) ',name)))
      (setf (slot cna-lisp.internal.ffi::struct-size)
            cna-lisp.internal.ffi::+sizeof-cna-effect-annotation-info+
            (slot cna-lisp.internal.ffi::struct-version) 1)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%effect-annotation-get-info handle info)
       "effect-annotation" :object-type 'effect-annotation)
      (setf (slot-value annotation '%row-count) (slot cna-lisp.internal.ffi::row-count)
            (slot-value annotation '%column-count) (slot cna-lisp.internal.ffi::column-count)
            (slot-value annotation '%parameter-class)
            (%effect-parameter-class-from-native (slot cna-lisp.internal.ffi::parameter-class))
            (slot-value annotation '%parameter-type)
            (%effect-parameter-type-from-native (slot cna-lisp.internal.ffi::parameter-type)))))
  annotation)

(defun %make-annotation (handle effect)
  (let ((annotation (make-instance 'effect-annotation :handle handle :effect effect)))
    (%retain-native-part effect handle #'cna-lisp.internal.ffi::%effect-annotation-destroy)
    (%adopt-view annotation effect)
    (setf (slot-value annotation '%name)
          (cna-lisp.internal:count-then-copy-string
           (lambda (out) (cna-lisp.internal.ffi::%effect-annotation-get-name-byte-count
                          handle out))
           (lambda (buffer capacity out)
             (cna-lisp.internal.ffi::%effect-annotation-copy-name handle buffer capacity out))
           "effect-annotation-name")
          (slot-value annotation '%semantic)
          (cna-lisp.internal:count-then-copy-string
           (lambda (out) (cna-lisp.internal.ffi::%effect-annotation-get-semantic-byte-count
                          handle out))
           (lambda (buffer capacity out)
             (cna-lisp.internal.ffi::%effect-annotation-copy-semantic handle buffer capacity out))
           "effect-annotation-semantic"))
    (%read-annotation-info handle annotation)))

(defun %build-annotation-collection (collection-handle effect)
  "Wrap an owned CNA annotation-collection handle, building every element."
  (let ((count (cffi:with-foreign-object (out :uint64)
                 (cna-lisp.internal:check-result
                  (cna-lisp.internal.ffi::%effect-annotation-collection-get-count
                   collection-handle out)
                  "effect annotations" :object-type 'effect-annotation-collection)
                 (cffi:mem-ref out :uint64))))
    (let ((items (make-array count)))
      (dotimes (index count)
        (cffi:with-foreign-object (out :uint64)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%effect-annotation-collection-get-at
            collection-handle index out)
           "effect annotations" :object-type 'effect-annotation-collection)
          (setf (aref items index) (%make-annotation (cffi:mem-ref out :uint64) effect))))
      (make-instance 'effect-annotation-collection :items items))))

;;; The eight readers. Each is XNA's GetValue<T>() on an annotation; CNA has one
;;; route per type, so there is nothing to dispatch on and nothing to guess.

(macrolet
    ((define-scalar-reader (name route lisp-type &optional (converter 'identity))
       `(defmethod ,name ((annotation effect-annotation))
          (cffi:with-foreign-object (out ,lisp-type)
            (cna-lisp.internal:check-result
             (,route (%view-handle annotation ,(string-downcase (symbol-name name))) out)
             ,(string-downcase (symbol-name name)) :object-type 'effect-annotation)
            (,converter (cffi:mem-ref out ,lisp-type))))))
  (define-scalar-reader effect-annotation-value-boolean
      cna-lisp.internal.ffi::%effect-annotation-get-value-boolean :uint8
      cna-lisp.internal.ffi:cna-true-p)
  (define-scalar-reader effect-annotation-value-int32
      cna-lisp.internal.ffi::%effect-annotation-get-value-int-32 :int32)
  (define-scalar-reader effect-annotation-value-single
      cna-lisp.internal.ffi::%effect-annotation-get-value-single :float))

(defmethod effect-annotation-value-vector2 ((annotation effect-annotation))
  (cffi:with-foreign-object (out '(:struct cna-lisp.internal.ffi::cna-vector-2))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%effect-annotation-get-value-vector-2
      (%view-handle annotation "effect-annotation-value-vector2") out)
     "effect-annotation-value-vector2" :object-type 'effect-annotation)
    (%read-vector2 out)))

(defmethod effect-annotation-value-vector3 ((annotation effect-annotation))
  (cffi:with-foreign-object (out '(:struct cna-lisp.internal.ffi::cna-vector-3))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%effect-annotation-get-value-vector-3
      (%view-handle annotation "effect-annotation-value-vector3") out)
     "effect-annotation-value-vector3" :object-type 'effect-annotation)
    (%read-vector3 out)))

(defmethod effect-annotation-value-vector4 ((annotation effect-annotation))
  (cffi:with-foreign-object (out '(:struct cna-lisp.internal.ffi::cna-vector-4))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%effect-annotation-get-value-vector-4
      (%view-handle annotation "effect-annotation-value-vector4") out)
     "effect-annotation-value-vector4" :object-type 'effect-annotation)
    (%read-vector4 out)))

(defmethod effect-annotation-value-matrix ((annotation effect-annotation))
  (cffi:with-foreign-object (out '(:struct cna-lisp.internal.ffi::cna-matrix))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%effect-annotation-get-value-matrix
      (%view-handle annotation "effect-annotation-value-matrix") out)
     "effect-annotation-value-matrix" :object-type 'effect-annotation)
    (%read-matrix out)))

(defmethod effect-annotation-value-string ((annotation effect-annotation))
  (let ((handle (%view-handle annotation "effect-annotation-value-string")))
    (cna-lisp.internal:count-then-copy-string
     (lambda (out)
       (cna-lisp.internal.ffi::%effect-annotation-get-value-string-byte-count handle out))
     (lambda (buffer capacity out)
       (cna-lisp.internal.ffi::%effect-annotation-copy-value-string handle buffer capacity out))
     "effect-annotation-value-string")))

;;; --- EffectPass ------------------------------------------------------------

(defclass effect-pass (%effect-view)
  ((%name :reader effect-pass-name)
   (%annotations :reader effect-pass-annotations)
   )
  (:documentation
   "Microsoft.Xna.Framework.Graphics.EffectPass.

APPLY selects this pass's shader state on the device. That is the public route to
drawing with an effect -- XNA has no `GraphicsDevice.CurrentEffect' -- and CNA
refuses a primitive draw until it has been called:

    (dolist (pass (collection-elements (effect-technique-passes
                                        (effect-current-technique effect))))
      (apply-effect-pass pass)
      (draw-user-primitives device ...))"))

(defclass effect-pass-collection (%effect-collection) ()
  (:documentation "Microsoft.Xna.Framework.Graphics.EffectPassCollection."))

(defmethod %collection-element-name ((element effect-pass))
  (effect-pass-name element))

(defgeneric apply-effect-pass (pass)
  (:documentation
   "EffectPass.Apply(): make this pass's state current on the graphics device.

Named APPLY-EFFECT-PASS rather than APPLY, because APPLY is a standard Common
Lisp function and shadowing it in a package a consumer uses unqualified would be
hostile. See docs/naming.md."))

(defmethod apply-effect-pass ((pass effect-pass))
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%effect-pass-apply (%view-handle pass "apply-effect-pass"))
   "apply-effect-pass" :object-type 'effect-pass)
  (values))

(defun %make-pass (handle effect)
  (let ((pass (make-instance 'effect-pass :handle handle :effect effect)))
    (%retain-native-part effect handle #'cna-lisp.internal.ffi::%effect-pass-destroy)
    (%adopt-view pass effect)
    (setf (slot-value pass '%name)
          (%view-name handle #'cna-lisp.internal.ffi::%effect-pass-get-name-byte-count
                      #'cna-lisp.internal.ffi::%effect-pass-copy-name "effect-pass-name"))
    (cffi:with-foreign-object (out :uint64)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%effect-pass-get-annotations handle out)
       "effect-pass-annotations" :object-type 'effect-pass)
      (let ((collection-handle
              (%retain-native-part
               effect (cffi:mem-ref out :uint64)
               #'cna-lisp.internal.ffi::%effect-annotation-collection-destroy)))
        (setf (slot-value pass '%annotations)
              (%build-annotation-collection collection-handle effect))))
    pass))

;;; --- EffectTechnique -------------------------------------------------------

(defclass effect-technique (%effect-view)
  ((%name :reader effect-technique-name)
   (%identity :reader %technique-identity)
   (%passes :reader effect-technique-passes)
   (%annotations :reader effect-technique-annotations)
   )
  (:documentation
   "Microsoft.Xna.Framework.Graphics.EffectTechnique."))

(defclass effect-technique-collection (%effect-collection) ()
  (:documentation "Microsoft.Xna.Framework.Graphics.EffectTechniqueCollection."))

(defmethod %collection-element-name ((element effect-technique))
  (effect-technique-name element))

(defun %technique-identity-of (handle)
  "CNA's stable non-pointer identity token for a technique view.

Two views of the same technique carry different handle values and the same
identity, which is what lets a handle CNA hands back be matched to the Lisp
object that already stands for it."
  (cffi:with-foreign-object (out :uint64)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%effect-technique-get-identity handle out)
     "effect technique identity" :object-type 'effect-technique)
    (cffi:mem-ref out :uint64)))

(defun %make-technique (handle effect)
  (let ((technique (make-instance 'effect-technique :handle handle :effect effect)))
    (%retain-native-part effect handle #'cna-lisp.internal.ffi::%effect-technique-destroy)
    (%adopt-view technique effect)
    (setf (slot-value technique '%name)
          (%view-name handle #'cna-lisp.internal.ffi::%effect-technique-get-name-byte-count
                      #'cna-lisp.internal.ffi::%effect-technique-copy-name
                      "effect-technique-name")
          (slot-value technique '%identity) (%technique-identity-of handle))
    (cffi:with-foreign-object (out :uint64)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%effect-technique-get-passes handle out)
       "effect-technique-passes" :object-type 'effect-technique)
      (let ((passes-handle
              (%retain-native-part
               effect (cffi:mem-ref out :uint64)
               #'cna-lisp.internal.ffi::%effect-pass-collection-destroy)))
        (let ((count (cffi:with-foreign-object (n :uint64)
                       (cna-lisp.internal:check-result
                        (cna-lisp.internal.ffi::%effect-pass-collection-get-count
                         passes-handle n)
                        "effect-technique-passes" :object-type 'effect-pass-collection)
                       (cffi:mem-ref n :uint64))))
          (let ((items (make-array count)))
            (dotimes (index count)
              (cffi:with-foreign-object (p :uint64)
                (cna-lisp.internal:check-result
                 (cna-lisp.internal.ffi::%effect-pass-collection-get-at passes-handle index p)
                 "effect-technique-passes" :object-type 'effect-pass-collection)
                (setf (aref items index) (%make-pass (cffi:mem-ref p :uint64) effect))))
            (setf (slot-value technique '%passes)
                  (make-instance 'effect-pass-collection :items items))))))
    (cffi:with-foreign-object (out :uint64)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%effect-technique-get-annotations handle out)
       "effect-technique-annotations" :object-type 'effect-technique)
      (let ((collection-handle
              (%retain-native-part
               effect (cffi:mem-ref out :uint64)
               #'cna-lisp.internal.ffi::%effect-annotation-collection-destroy)))
        (setf (slot-value technique '%annotations)
              (%build-annotation-collection collection-handle effect))))
    technique))

;;; --- Effect ----------------------------------------------------------------

(defparameter +effect-matrix-shim-reason+
  "cna_effect_matrices_set_world, _set_view and _set_projection take CNA_Matrix by value, and at
64 bytes the System V AMD64 ABI passes it in memory rather than in registers -- which CFFI cannot
express without cffi-libffi, a dependency a released CNA-Lisp must not have. The three getters take
CNA_Matrix* and need nothing."
  "Why the three matrix setters go through the optional private shim.")

(defclass effect (%native-graphics-resource)
  ((%techniques :reader effect-techniques)
   (%parameters :reader effect-parameters)
   (%current-technique :initform nil)
   (%native-parts :initform '() :accessor %effect-native-parts
                  :documentation
                  "Every owned CNA handle this effect must give back, newest
first. See %RETAIN-NATIVE-PART."))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.Effect.

Created either from compiled Direct3D 9 Effect Framework bytecode --

    (make-instance 'effect :graphics-device device :effect-code bytes)

-- which is XNA's `Effect(GraphicsDevice, byte[])', or as one of the stock
effects, of which BASIC-EFFECT is projected here.

**Compiled bytecode is a renderer capability, not an ABI one.** CNA accepts the
same `.fxb' payload XNA does, but only on a renderer built with the compiled
effect runtime; the HEADLESS and SOFTWARE renderers used for qualification here
are not among them, and refuse the bytecode rather than quietly substituting a
stock shader. The constructor reports that refusal; it does not work around it.
docs/limitations.md has the consequences, the largest of which is that no
`Effect' in this binding has ever been observed with a non-empty
`Parameters'."))

(defmethod effect-techniques ((effect effect))
  (cna-lisp.internal:check-live effect "effect-techniques")
  (slot-value effect '%techniques))

(defmethod effect-parameters ((effect effect))
  (cna-lisp.internal:check-live effect "effect-parameters")
  (slot-value effect '%parameters))

(defun %build-effect-graph (effect)
  "Read the whole technique and parameter graph out of CNA, once."
  (let ((handle (cna-lisp.internal:handle-of effect)))
    (cffi:with-foreign-object (out :uint64)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%effect-get-techniques handle out)
       "effect techniques" :object-type 'effect)
      (let ((techniques-handle
              (%retain-native-part
               effect (cffi:mem-ref out :uint64)
               #'cna-lisp.internal.ffi::%effect-technique-collection-destroy)))
        (let ((count (cffi:with-foreign-object (n :uint64)
                       (cna-lisp.internal:check-result
                        (cna-lisp.internal.ffi::%effect-technique-collection-get-count
                         techniques-handle n)
                        "effect techniques" :object-type 'effect-technique-collection)
                       (cffi:mem-ref n :uint64))))
          (let ((items (make-array count)))
            (dotimes (index count)
              (cffi:with-foreign-object (t* :uint64)
                (cna-lisp.internal:check-result
                 (cna-lisp.internal.ffi::%effect-technique-collection-get-at
                  techniques-handle index t*)
                 "effect techniques" :object-type 'effect-technique-collection)
                (setf (aref items index) (%make-technique (cffi:mem-ref t* :uint64) effect))))
            (setf (slot-value effect '%techniques)
                  (make-instance 'effect-technique-collection :items items))))))
    (cffi:with-foreign-object (out :uint64)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%effect-get-parameters handle out)
       "effect parameters" :object-type 'effect)
      (let ((parameters-handle
              (%retain-native-part
               effect (cffi:mem-ref out :uint64)
               #'cna-lisp.internal.ffi::%effect-parameter-collection-destroy)))
        (setf (slot-value effect '%parameters)
              (%build-parameter-collection parameters-handle effect 0))))
    ;; XNA's Effect sets CurrentTechnique to the first technique when it builds
    ;; its graph; CNA has already done the same, so the object is looked up
    ;; rather than assigned, and a disagreement would show as NIL here.
    (setf (slot-value effect '%current-technique) (%read-current-technique effect))
    effect))

(defun %read-current-technique (effect)
  "The Lisp EFFECT-TECHNIQUE for whatever CNA currently reports as current."
  (cffi:with-foreign-object (out :uint64)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%effect-get-current-technique
      (cna-lisp.internal:handle-of effect) out)
     "effect-current-technique" :object-type 'effect)
    (let ((handle (cffi:mem-ref out :uint64)))
      (when (zerop handle)
        (return-from %read-current-technique nil))
      (unwind-protect
           (let ((identity (%technique-identity-of handle)))
             (find identity (%collection-items (slot-value effect '%techniques))
                   :key #'%technique-identity))
        ;; The handle CNA just issued is a fresh owned view; the object that
        ;; stands for the technique already exists, so this one is given straight
        ;; back -- and the result is checked, because a view that could not be
        ;; released is a handle CNA is still owed, and every one of those turns
        ;; into a game that will not shut down.
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%effect-technique-destroy handle)
         "effect-current-technique" :object-type (type-of effect))))))

(defgeneric effect-current-technique (effect)
  (:documentation "Effect.CurrentTechnique."))

(defgeneric (setf effect-current-technique) (technique effect)
  (:documentation
   "Effect.CurrentTechnique's setter.

Three rules, in the order the pinned IL applies them: NIL is refused; setting the
technique that is already current does nothing; and a technique belonging to a
*different* effect is refused with XNA's own InvalidOperationException, which is
CNA-USAGE-ERROR here."))

(defmethod effect-current-technique ((effect effect))
  (cna-lisp.internal:check-live effect "effect-current-technique")
  (slot-value effect '%current-technique))

(defmethod (setf effect-current-technique) (technique (effect effect))
  (cna-lisp.internal:check-usable effect "(setf effect-current-technique)")
  (unless technique
    (error 'microsoft.xna.framework:cna-argument-out-of-range-error
           :operation "(setf effect-current-technique)"
           :parameter-name "value"
           :format-control
           "Effect.CurrentTechnique refuses null; XNA throws ArgumentNullException ~
            for it, before any other check."))
  (check-type technique effect-technique)
  (unless (eq technique (slot-value effect '%current-technique))
    (unless (eq (%view-effect technique) effect)
      (error 'microsoft.xna.framework:cna-usage-error
             :operation "(setf effect-current-technique)"
             :object-type 'effect
             :format-control
             "that EffectTechnique belongs to a different Effect. XNA compares the ~
              technique's parent with the effect being assigned to and throws ~
              InvalidOperationException when they differ."))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%effect-set-current-technique
      (cna-lisp.internal:handle-of effect)
      (%view-handle technique "(setf effect-current-technique)"))
     "(setf effect-current-technique)" :object-type 'effect)
    (setf (slot-value effect '%current-technique) technique))
  technique)

;;; --- construction ----------------------------------------------------------
;;;
;;; One place adopts a handle and builds the graph, whichever of the three ways
;;; the handle arrived: compiled bytecode, a stock effect's own create route, or
;;; a clone. A subclass says how its handle is made and, if it has more views to
;;; take, what else to build.

(defun %effect-adopt (effect game handle)
  (setf (cna-lisp.internal:handle-of effect) handle
        (slot-value effect 'cna-lisp.internal::owner) game
        (slot-value effect 'cna-lisp.internal::owner-thread)
        (cna-lisp.internal:owner-thread-of game))
  (cna-lisp.internal:register-child game effect)
  effect)

(defgeneric %create-effect-handle (effect device-handle effect-code)
  (:documentation
   "Make this effect's CNA handle against a borrowed device handle.

The base method is XNA's `Effect(GraphicsDevice, byte[])': compiled Direct3D 9
Effect Framework bytecode. A stock effect overrides it with its own create route
and ignores EFFECT-CODE, which its constructor has already refused.")
  (:method ((effect effect) device-handle effect-code)
    (let ((bytes (coerce effect-code '(vector (unsigned-byte 8)))))
      (cffi:with-foreign-objects ((out :uint64) (buffer :uint8 (max 1 (length bytes))))
        (dotimes (index (length bytes))
          (setf (cffi:mem-aref buffer :uint8 index) (aref bytes index)))
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%effect-create-compiled
          device-handle buffer (length bytes) out)
         "make-instance 'effect" :object-type (type-of effect))
        (cffi:mem-ref out :uint64)))))

(defgeneric %build-effect-extras (effect)
  (:documentation
   "Take any further stable views this effect kind owns, once, at construction.")
  (:method ((effect effect)) (values)))

(defgeneric %effect-takes-code-p (effect)
  (:documentation
   "True when this effect kind is built from compiled bytecode a caller supplies.
False for a stock effect, which CNA builds from its own route.")
  (:method ((effect effect)) t))

(defun %validate-effect-code (effect effect-code graphics-device)
  "XNA's Effect(GraphicsDevice, byte[]) argument checks, in the IL's order.

Read from `Effect::CreateEffectFromCode', which is where the surprises are: a
*null or empty* effectCode is an ArgumentNullException and not an
ArgumentException, a length that is not a multiple of four is the
ArgumentException, and the code is checked before the device is."
  (when (%effect-takes-code-p effect)
    (when (or (null effect-code) (zerop (length effect-code)))
      (error 'microsoft.xna.framework:cna-argument-out-of-range-error
             :operation "make-instance 'effect"
             :parameter-name "effect-code"
             :format-control
             "Effect refuses empty compiled effect code. XNA checks it before the ~
              device, and answers ArgumentNullException for an empty array as well ~
              as for a missing one."))
    (unless (zerop (mod (length effect-code) 4))
      (error 'microsoft.xna.framework:cna-argument-out-of-range-error
             :operation "make-instance 'effect"
             :parameter-name "effect-code"
             :format-control
             "compiled effect code must be a multiple of four bytes long; this is ~d."
             :format-arguments (list (length effect-code)))))
  (unless graphics-device
    (error 'microsoft.xna.framework:cna-argument-out-of-range-error
           :operation "make-instance 'effect"
           :parameter-name "graphics-device"
           :format-control "a graphics device is required to create a resource.")))

(defun %effect-device-handle (graphics-device operation)
  "The borrowed device handle an effect is created against, with its game."
  (check-type graphics-device graphics-device)
  (values (device-handle-for-child graphics-device operation)
          (cna-lisp.internal:owner-of graphics-device)))

(defmethod initialize-instance :after ((effect effect)
                                       &key graphics-device effect-code
                                            %adopted-handle %adopted-game
                                       &allow-other-keys)
  ;; Construction is all-or-nothing. Adopting the handle registers the effect as
  ;; a child of the game, and building the graph then takes a further handle for
  ;; every technique, pass, parameter, annotation and light. If any of those
  ;; routes fails, MAKE-INSTANCE signals and the caller never receives an object
  ;; -- so without a rollback the effect would stay registered, and its views
  ;; would stay alive, with nothing left that could dispose them.
  ;;
  ;; The undos go in NATIVE-OBJECT's construction ledger rather than in a local
  ;; UNWIND-PROTECT, because a local one ends where this method ends and a
  ;; subclass's own `:after' runs *after* that. A stock effect extends this
  ;; through %BUILD-EFFECT-EXTRAS and is covered either way; a consumer subclass
  ;; that writes an initializer was not.
  (if %adopted-handle
      ;; The clone path: the handle exists, and re-running a create route would
      ;; make a second effect rather than adopt the one CNA just cloned.
      (%effect-adopt effect %adopted-game %adopted-handle)
      (progn
        (%validate-effect-code effect effect-code graphics-device)
        (multiple-value-bind (device-handle game)
            (%effect-device-handle graphics-device "make-instance 'effect")
          (%effect-adopt effect game
                         (%create-effect-handle effect device-handle effect-code)))
        (setf (%resource-device effect) graphics-device)))
  ;; Recorded once the handle is adopted, and undone newest-first: the views
  ;; first, in the order CNA wants, then the effect itself. Quietly, because a
  ;; failure here must not mask the one that caused the rollback.
  (cna-lisp.internal:record-construction-undo
   effect (lambda ()
            (let ((handle (cna-lisp.internal:handle-of effect)))
              (ignore-errors (cna-lisp.internal.ffi::%effect-destroy handle))
              (cna-lisp.internal:invalidate effect))))
  (cna-lisp.internal:record-construction-undo
   effect (lambda () (%release-native-parts effect :quietly t)))
  (%build-effect-graph effect)
  (%build-effect-extras effect))

(defgeneric clone-effect (effect)
  (:documentation
   "Effect.Clone(): an independent copy, of the same concrete type.

Named CLONE-EFFECT rather than CLONE for the reason APPLY-EFFECT-PASS is not
APPLY: the projection does not put a bare, very general verb into a package
consumers use unqualified."))

(defmethod clone-effect ((effect effect))
  (cna-lisp.internal:check-usable effect "clone-effect")
  (cffi:with-foreign-object (out :uint64)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%effect-clone (cna-lisp.internal:handle-of effect) out)
     "clone-effect" :object-type (type-of effect))
    (let ((clone (make-instance (class-of effect)
                                :%adopted-handle (cffi:mem-ref out :uint64)
                                :%adopted-game (cna-lisp.internal:owner-of effect))))
      (setf (%resource-device clone) (%resource-device effect))
      clone)))

;;; --- destruction -----------------------------------------------------------

(defmethod cna-lisp.internal:destroy-native ((effect effect))
  ;; The ledger, newest first, which is leaf first. Every handle in it is one CNA
  ;; is owed, and CNA refuses to destroy the game while any of them is alive --
  ;; which is exactly the failure a consumer would otherwise see, on game
  ;; shutdown, nowhere near the effect that leaked it.
  ;;
  ;; A native failure releasing one part is *reported*, not swallowed, and the
  ;; rest are released anyway: stopping at the first would leave everything
  ;; behind it alive too, and turn one diagnosable failure into a shutdown that
  ;; fails for a different reason later.
  (let ((failure (%release-native-parts effect)))
    (handler-case
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%effect-destroy (cna-lisp.internal:handle-of effect))
         "dispose" :object-type (type-of effect))
      (error (condition) (unless failure (setf failure condition))))
    (when failure (error failure))))
