;;;; model.lisp --- the Microsoft.Xna.Framework.Graphics Model family.
;;;;
;;;; Twelve types and forty-eight members, and the closure adds nothing: every
;;;; XNA type this family reaches -- Effect, Matrix, BoundingSphere,
;;;; VertexBuffer, IndexBuffer, GraphicsDevice -- was already selected.
;;;;
;;;; **None of these types has a public constructor**, and that is the pinned
;;;; contract rather than a decision made here: `Model..ctor', `ModelBone..ctor',
;;;; `ModelMesh..ctor', `ModelMeshPart..ctor' and every collection's constructor
;;;; are `assembly' in the disassembly, so a program reaches them only through
;;;; `ContentManager.Load<Model>'. CNA does have `cna_model_create*', and this
;;;; file uses those routes to build fixtures for its own tests -- but a private
;;;; fixture producer is not public API, and none of them is projected.
;;;;
;;;; ## Object identity is the hard part, and it is why the graph is eager
;;;;
;;;; **CNA handle identity is not XNA object identity.** `CreateBoneHandle' in
;;;; CNA's own source makes a *new* registry handle on every call, so
;;;; `cna_model_bone_collection_get_at(bones, 0)' twice answers two different
;;;; handles naming one bone. XNA's `Bones[0]' twice answers the same object, and
;;;; `mesh.ParentBone' is that object rather than a copy of it.
;;;;
;;;; So the whole graph is read once, at construction, into a fixed vector per
;;;; collection, and everything that names a bone -- a parent, a child, a mesh's
;;;; parent bone, the root -- is resolved through the model's index map to the
;;;; one object for that bone. A transient handle read on the way is destroyed
;;;; immediately; only the handles the objects keep are recorded.
;;;;
;;;; Effects and buffers are resolved differently, because they may already have
;;;; a CLOS object: a hand-built model's effect is the caller's own, and
;;;; `part.Effect' must answer *that* object. So a handle is looked up among the
;;;; game's live children first, and only a handle nothing owns yet gets a
;;;; model-owned wrapper. CNA's loader publishes one handle per distinct native
;;;; object -- its `published' map is keyed on the native pointer -- so two parts
;;;; sharing one effect answer one object either way.
;;;;
;;;; ## Ownership
;;;;
;;;; The model owns every handle it took, in one ledger, released newest-first
;;;; -- which is leaf-first, because a collection view is always taken before the
;;;; elements read out of it. Bones, meshes and parts are NATIVE-OBJECTs so that
;;;; using one after its model is gone refuses rather than reaching a reissued
;;;; handle, and none of them is disposable, because none of XNA's is.
;;;;
;;;; A **content-loaded** model's effect and buffer handles are the model's, not
;;;; the caller's: `cna_content_manager_load_model' says "the handles this route
;;;; creates for them are released when the model is destroyed -- do not release
;;;; them by hand", and CNA marks such an effect `disposeAllowed = false`. The
;;;; wrappers this file makes for them are therefore `:PARENT-OWNED', which is
;;;; the ownership kind whose DISPOSE already refuses and says to dispose the
;;;; parent. Nothing here fakes ownership in either direction.

(in-package #:microsoft.xna.framework.graphics)

;;; --- shared plumbing -------------------------------------------------------

(defclass %model-view (cna-lisp.internal:native-object)
  ((%model :initarg :model :reader %view-model
           :documentation "The MODEL this view belongs to, for staleness."))
  (:documentation
   "Private base of the three non-disposable things CNA hands out as owned model
handles: a bone, a mesh and a mesh part. Each is a NATIVE-OBJECT so that using
one after its model is gone refuses rather than reaching a reissued handle."))

(defmethod microsoft.xna.framework:dispose ((view %model-view))
  ;; Here rather than in DESTROY-NATIVE, for the reason %EFFECT-VIEW records: the
  ;; base DISPOSE calls DESTROY-NATIVE inside an UNWIND-PROTECT whose cleanup
  ;; drops the handle, so refusing one level down would still zero it and the
  ;; model would then skip a handle CNA is still owed.
  (error 'microsoft.xna.framework:cna-usage-error
         :operation "dispose"
         :object-type (type-of view)
         :format-control
         "~a is not disposable. XNA has no Dispose on it, and the Model that owns ~
          it releases it. Dispose the Model -- or let ContentManager.Unload do it."
         :format-arguments (list (type-of view))))

(defun %model-view-handle (view operation)
  (cna-lisp.internal:check-usable view operation)
  (cna-lisp.internal:handle-of view))

;;; --- the collections -------------------------------------------------------
;;;
;;; All four are the same shape as the effect collections': a fixed vector of
;;; already-built objects. They keep no CNA handle at all -- a collection view is
;;; read out and released at construction -- and they keep the model, so that a
;;; collection held across a disposal refuses rather than answering stale data.

(defclass %model-collection ()
  ((%items :initarg :items :reader %collection-items :initform #())
   (%model :initarg :model :reader %collection-model :initform nil))
  (:documentation
   "Private base of the four model collections. Each is fixed at construction,
because the model it describes is."))

(defun %model-collection-live (collection operation)
  "Refuse an operation on a collection whose model is gone, and answer the items."
  (let ((model (%collection-model collection)))
    (when model (cna-lisp.internal:check-live model operation)))
  (%collection-items collection))

(defclass model-bone-collection (%model-collection) ()
  (:documentation
   "Microsoft.Xna.Framework.Graphics.ModelBoneCollection.

XNA derives it from `ReadOnlyCollection<ModelBone>' and adds three members of its
own: a name indexer, TRY-GET-VALUE and GET-ENUMERATOR. Count and the integer
indexer are the base class's, so they are not members this projection can map --
COLLECTION-COUNT and COLLECTION-ITEM answer them anyway, for the reason
GameComponentCollection's own operations are declared extensions."))

(defclass model-mesh-collection (%model-collection) ()
  (:documentation "Microsoft.Xna.Framework.Graphics.ModelMeshCollection."))

(defclass model-mesh-part-collection (%model-collection) ()
  (:documentation "Microsoft.Xna.Framework.Graphics.ModelMeshPartCollection."))

(defclass model-effect-collection (%model-collection) ()
  (:documentation
   "Microsoft.Xna.Framework.Graphics.ModelEffectCollection: the distinct effects
the parts of one mesh use.

**Not a list per part.** `ModelMeshPart.set_Effect' in the pinned assembly walks
its siblings and removes the old effect only when no other part still uses it,
and adds the new one only when no other part has it already -- so the collection
is the deduplicated set of its mesh's part effects, maintained incrementally.
CNA's `SetPartEffect' does the same walk in the same order, which is what makes
the cross-check in the tests a measurement rather than a restatement."))

(defmethod collection-count ((collection %model-collection))
  (length (%model-collection-live collection "collection-count")))

(defmethod collection-elements ((collection %model-collection))
  (coerce (%model-collection-live collection "collection-elements") 'list))

(defmethod collection-item ((collection %model-collection) (index integer))
  "`ReadOnlyCollection<T>.get_Item(int32)', which throws for an index outside the
collection rather than answering null -- unlike the effect collections', whose
own IL answers null and which this generic function also serves."
  (let ((items (%model-collection-live collection "collection-item")))
    (unless (and (>= index 0) (< index (length items)))
      (error 'microsoft.xna.framework:cna-argument-out-of-range-error
             :operation "collection-item"
             :object-type (type-of collection)
             :parameter-name "index"
             :format-control
             "~d is outside a ~a of ~d element~:p. ReadOnlyCollection<T>'s indexer ~
              throws ArgumentOutOfRangeException here; it does not answer NIL, and ~
              the effect collections that do are a different contract."
             :format-arguments (list index (type-of collection) (length items))))
    (aref items index)))

(defgeneric %collection-element-model-name (element)
  (:documentation "The name a model collection's string indexer matches on."))

(defmethod %collection-element-model-name ((element t)) nil)

(defgeneric collection-try-get-value (collection name)
  (:documentation
   "`ModelBoneCollection.TryGetValue' and `ModelMeshCollection.TryGetValue'.

Answers two values, the element and whether it was found, which is how Common
Lisp spells an `out' parameter plus a boolean. A miss answers `(values NIL NIL)',
exactly as XNA's assigns null and returns false.

**A null or empty name is an ArgumentNullException**, not a miss: the IL's first
instruction is `String.IsNullOrEmpty' and it throws on both. The comparison is
`String.Compare(a, b, StringComparison.Ordinal)' -- ordinal, so case-sensitive --
and the first match wins."))

(defmethod collection-try-get-value ((collection %model-collection) name)
  (let ((operation "collection-try-get-value"))
    (unless (and (stringp name) (plusp (length name)))
      (error 'microsoft.xna.framework:cna-argument-error
             :operation operation
             :object-type (type-of collection)
             :parameter-name (if (typep collection 'model-mesh-collection)
                                 "meshName" "boneName")
             :format-control
             "the name must be a non-empty string. XNA's TryGetValue tests ~
              String.IsNullOrEmpty first and throws ArgumentNullException for both ~
              null and the empty string."))
    (let ((items (%model-collection-live collection operation)))
      (loop for element across items
            when (equal name (%collection-element-model-name element))
              do (return (values element t))
            finally (return (values nil nil))))))

(defmethod collection-item ((collection model-bone-collection) (name string))
  "`ModelBoneCollection.get_Item(string)': TryGetValue, and
KeyNotFoundException when it answers false.

**Not NIL.** The effect collections' string indexers answer NIL for a miss and
this one does not; the IL is `call TryGetValue; brtrue; newobj KeyNotFoundException;
throw'. Section-by-section assumption is exactly what this contradicts."
  (%model-collection-item-by-name collection name))

(defmethod collection-item ((collection model-mesh-collection) (name string))
  "`ModelMeshCollection.get_Item(string)', which is ModelBoneCollection's."
  (%model-collection-item-by-name collection name))

(defun %model-collection-item-by-name (collection name)
  (multiple-value-bind (element found) (collection-try-get-value collection name)
    (unless found
      (error 'microsoft.xna.framework:cna-invalid-argument-error
             :operation "collection-item"
             :object-type (type-of collection)
             :format-control
             "no element of this ~a is named ~s. XNA's indexer throws ~
              KeyNotFoundException here rather than answering null, which is where ~
              it differs from the effect collections'."
             :format-arguments (list (type-of collection) name)))
    element))

;;; --- the enumerators -------------------------------------------------------

(defclass %model-enumerator ()
  ((%items :initarg :items :reader %enumerator-items)
   (%position :initform -1 :accessor %enumerator-position)
   (%collection :initarg :collection :reader %enumerator-collection))
  (:documentation
   "Private base of the four nested `Enumerator' types.

**A CLOS object rather than a projected value type, and that is a decision.** XNA
declares each of them a mutable `struct' whose `MoveNext' advances a field; C#
copies it into a `foreach' local and mutates the copy. A Common Lisp value type
here is an immutable structure -- MAKE-<type>, COPY-<type>, readers -- and a
value that mutates is not a value, so a cursor projects onto something with
identity or it does not work at all. A program that wants the sequence uses
COLLECTION-ELEMENTS; this exists because XNA's GetEnumerator has a return type
and the profile admits it."))

(defclass model-bone-collection-enumerator (%model-enumerator) ()
  (:documentation "Microsoft.Xna.Framework.Graphics.ModelBoneCollection+Enumerator."))
(defclass model-mesh-collection-enumerator (%model-enumerator) ()
  (:documentation "Microsoft.Xna.Framework.Graphics.ModelMeshCollection+Enumerator."))
(defclass model-mesh-part-collection-enumerator (%model-enumerator) ()
  (:documentation "Microsoft.Xna.Framework.Graphics.ModelMeshPartCollection+Enumerator."))
(defclass model-effect-collection-enumerator (%model-enumerator) ()
  (:documentation "Microsoft.Xna.Framework.Graphics.ModelEffectCollection+Enumerator."))

(defgeneric collection-enumerator (collection)
  (:documentation
   "`GetEnumerator()' on a model collection: a cursor positioned before the first
element.

The four model collections answer their own nested enumerator type, because XNA's
do and those types are in this profile. The effect collections do not: theirs is
a `List<T>.Enumerator', which is the base-class library's and is not projected,
so COLLECTION-ELEMENTS is their whole answer. Both exist here, and
COLLECTION-ELEMENTS is the one a Lisp program wants."))

(macrolet ((enumerator (collection-class enumerator-class)
             `(defmethod collection-enumerator ((collection ,collection-class))
                (make-instance ',enumerator-class
                               :collection collection
                               :items (%model-collection-live
                                       collection "collection-enumerator")))))
  (enumerator model-bone-collection model-bone-collection-enumerator)
  (enumerator model-mesh-collection model-mesh-collection-enumerator)
  (enumerator model-mesh-part-collection model-mesh-part-collection-enumerator)
  (enumerator model-effect-collection model-effect-collection-enumerator))

(defgeneric enumerator-move-next (enumerator)
  (:documentation
   "`MoveNext()': advance to the next element and answer whether there is one.

The cursor starts before the first element, so the first call positions it on it
-- which is `IEnumerator''s contract and XNA's implementation, whose `position'
field starts at -1 for the array-backed enumerators."))

(defmethod enumerator-move-next ((enumerator %model-enumerator))
  (let ((next (1+ (%enumerator-position enumerator))))
    (cond ((< next (length (%enumerator-items enumerator)))
           (setf (%enumerator-position enumerator) next)
           t)
          (t
           ;; Stay one past the end rather than running away, so repeated calls
           ;; keep answering false, as XNA's do.
           (setf (%enumerator-position enumerator)
                 (length (%enumerator-items enumerator)))
           nil))))

(defgeneric enumerator-current (enumerator)
  (:documentation
   "`Current': the element the cursor is on.

Refuses before the first ENUMERATOR-MOVE-NEXT and after the last one. XNA's
array-backed enumerator indexes its array with the current position and lets the
CLR raise IndexOutOfRangeException there; a diagnosable refusal naming the
operation is the projection of that, not a widening of it."))

(defmethod enumerator-current ((enumerator %model-enumerator))
  (let ((position (%enumerator-position enumerator))
        (items (%enumerator-items enumerator)))
    (unless (and (>= position 0) (< position (length items)))
      (error 'microsoft.xna.framework:cna-invalid-state-error
             :operation "enumerator-current"
             :object-type (type-of enumerator)
             :format-control
             "the cursor is ~:[past the last element~;before the first element~]. ~
              CURRENT is legal only between a MOVE-NEXT that answered true and the ~
              one that answers false."
             :format-arguments (list (minusp position))))
    (aref items position)))

(defmethod microsoft.xna.framework:dispose ((enumerator %model-enumerator))
  "`Enumerator.Dispose()', whose IL is one `ret'.

The array-backed enumerators hold nothing to release and neither does this; the
member exists because `IEnumerator<T>' requires it."
  (values))

;;; --- ModelBone -------------------------------------------------------------

(defclass model-bone (%model-view)
  ((%name :reader model-bone-name)
   (%index :reader model-bone-index)
   (%parent :initform nil :reader model-bone-parent)
   (%children :initform nil))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.ModelBone: one node of a model's skeleton.

Every member is a plain field read in the pinned assembly -- `Name', `Index',
`Parent' and `Children' are seven-byte `ldfld' getters with no check of any kind,
and `Transform' is an `ldfld'/`stfld' pair. `Name' and `Index' are therefore read
once, when the model's graph is built; `Transform' is live, because it is the one
of the five a program can change.

No public constructor: XNA's is `assembly', and a bone reaches a program only
through `Model.Bones', `ModelBone.Parent', `ModelBone.Children' or
`ModelMesh.ParentBone' -- all of which answer the same object for the same bone."))

(defmethod %collection-element-model-name ((element model-bone))
  (model-bone-name element))

(defgeneric model-bone-children (bone)
  (:documentation "`ModelBone.Children': this bone's child bones, in model order."))

(defmethod model-bone-children ((bone model-bone))
  (cna-lisp.internal:check-usable bone "model-bone-children")
  (slot-value bone '%children))

(defgeneric model-bone-transform (bone)
  (:documentation
   "`ModelBone.Transform': the bone's transform relative to its parent."))

(defmethod model-bone-transform ((bone model-bone))
  (let ((handle (%model-view-handle bone "model-bone-transform")))
    (cffi:with-foreign-object (out '(:struct cna-lisp.internal.ffi::cna-matrix))
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%model-bone-get-transform handle out)
       "model-bone-transform" :object-type 'model-bone)
      (%read-matrix out))))

(defgeneric (setf model-bone-transform) (matrix bone)
  (:documentation
   "`ModelBone.Transform''s setter, whose IL is one `stfld' and nothing else.

**Written through the model's bulk route rather than through the bone's own.**
`cna_model_bone_set_transform' takes a 64-byte `CNA_Matrix' by value, which the
System V AMD64 ABI classifies MEMORY and CFFI cannot pass without cffi-libffi --
the impedance mismatch the optional shim exists for. `cna_model_set_bone_transforms'
takes a *pointer* to the whole array and needs no shim, so the setter reads the
model's local transforms, replaces this bone's, and writes them all back. Nothing
else can change in between: every handle in a model is affine to one thread.

The alternative was a fifth shimmed route and a member that refuses without a C
toolchain. This is the same value written the same way, so the member is complete
rather than packaging-dependent."))

(defmethod (setf model-bone-transform) (matrix (bone model-bone))
  (cna-lisp.internal:check-usable bone "setf model-bone-transform")
  (let* ((model (%view-model bone))
         (index (model-bone-index bone)))
    (cna-lisp.internal:check-usable model "setf model-bone-transform")
    (let ((transforms (%model-local-transforms model "setf model-bone-transform")))
      (setf (aref transforms index) matrix)
      (%model-write-bone-transforms model transforms "setf model-bone-transform")))
  matrix)

;;; --- ModelMeshPart ---------------------------------------------------------

(defclass model-mesh-part (%model-view)
  ((%mesh :initarg :mesh :initform nil :reader %part-mesh)
   (%effect :initform nil)
   (%vertex-buffer :initform nil :reader model-mesh-part-vertex-buffer)
   (%index-buffer :initform nil :reader model-mesh-part-index-buffer)
   (%tag :initform nil))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.ModelMeshPart: one draw call's worth of a mesh.

Seven of its eight members are `ldfld' getters and only `Effect' and `Tag' have
setters. Its own `Draw()' is `assembly' in XNA and is not a member of this
contract; what it does -- bind the vertex buffer at the part's vertex offset,
bind the index buffer and submit one `DrawIndexedPrimitives' -- is reproduced by
DRAW-MODEL-MESH out of the public device surface, which is what lets this binding
prove the sequence rather than assert it."))

(macrolet ((scalar (name route documentation)
             `(progn
                (defgeneric ,name (part) (:documentation ,documentation))
                (defmethod ,name ((part model-mesh-part))
                  (let ((handle (%model-view-handle part ,(string-downcase (symbol-name name)))))
                    (cffi:with-foreign-object (out :int32)
                      (cna-lisp.internal:check-result
                       (,route handle out)
                       ,(string-downcase (symbol-name name)) :object-type 'model-mesh-part)
                      (cffi:mem-ref out :int32)))))))
  (scalar model-mesh-part-start-index
          cna-lisp.internal.ffi::%model-mesh-part-get-start-index
          "`ModelMeshPart.StartIndex': the first index this part draws from.")
  (scalar model-mesh-part-primitive-count
          cna-lisp.internal.ffi::%model-mesh-part-get-primitive-count
          "`ModelMeshPart.PrimitiveCount': how many primitives this part draws.")
  (scalar model-mesh-part-vertex-offset
          cna-lisp.internal.ffi::%model-mesh-part-get-vertex-offset
          "`ModelMeshPart.VertexOffset': the vertex the part's indices are relative to.")
  (scalar model-mesh-part-num-vertices
          cna-lisp.internal.ffi::%model-mesh-part-get-num-vertices
          "`ModelMeshPart.NumVertices': how many vertices the part uses."))

(defgeneric model-mesh-part-effect (part)
  (:documentation
   "`ModelMeshPart.Effect': the effect this part is drawn with, or NIL.

The same CLOS object every time, and the same object two parts sharing one effect
both answer: CNA's loader publishes one handle per distinct native effect, and
this binding maps a handle to the one object for it."))

(defmethod model-mesh-part-effect ((part model-mesh-part))
  (cna-lisp.internal:check-usable part "model-mesh-part-effect")
  (slot-value part '%effect))

(defgeneric (setf model-mesh-part-effect) (effect part)
  (:documentation
   "`ModelMeshPart.Effect''s setter, transcribed from the pinned IL.

It is not a field write. `set_Effect' walks the part's siblings first and then
maintains its mesh's `Effects' collection:

    if (value == this.effect) return;
    for each sibling part other than this one:
        if (sibling.Effect is this.effect)  someoneElseStillUsesTheOld = true
        else if (sibling.Effect is value)   someoneElseAlreadyHasTheNew = true
    if (!someoneElseStillUsesTheOld && this.effect != null) mesh.Effects.Remove(this.effect)
    if (!someoneElseAlreadyHasTheNew && value != null)      mesh.Effects.Add(value)
    this.effect = value

so `Mesh.Effects' is the deduplicated set of its parts' effects and setting a
part's effect changes it. Both sides are done here: CNA's `SetPartEffect' runs
the same walk over its own collection, and the tests assert that the two agree
rather than assuming they do.

NIL clears the effect, which is what `value == null' does. The effect must belong
to the same graphics device, which is CNA's refusal and XNA's own precondition."))

(defmethod (setf model-mesh-part-effect) (effect (part model-mesh-part))
  (let ((operation "setf model-mesh-part-effect")
        (handle (%model-view-handle part "setf model-mesh-part-effect")))
    (when effect
      (check-type effect effect)
      (cna-lisp.internal:check-usable effect operation))
    (let ((previous (slot-value part '%effect)))
      (unless (eq previous effect)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%model-mesh-part-set-effect
          handle (if effect (cna-lisp.internal:handle-of effect) 0))
         operation :object-type 'model-mesh-part)
        (setf (slot-value part '%effect) effect)
        (%mesh-effects-after-part-change (%part-mesh part) part previous effect))))
  effect)

(defun %mesh-effects-after-part-change (mesh part previous effect)
  "Maintain MESH's Effects the way `ModelMeshPart.set_Effect' does.

Runs *after* the field has been written, and decides from the siblings alone --
which is what the IL does: it inspects every other part, never this one."
  (when mesh
    (let* ((collection (slot-value mesh '%effects))
           (items (coerce (%collection-items collection) 'list))
           (siblings (remove part (coerce (%collection-items
                                           (slot-value mesh '%mesh-parts))
                                          'list)))
           (still-used (and previous
                            (some (lambda (sibling)
                                    (eq previous (slot-value sibling '%effect)))
                                  siblings)))
           (already-there (and effect
                               (some (lambda (sibling)
                                       (eq effect (slot-value sibling '%effect)))
                                     siblings))))
      (when (and previous (not still-used))
        (setf items (remove previous items)))
      (when (and effect (not already-there))
        (setf items (append items (list effect))))
      (setf (slot-value collection '%items) (coerce items 'vector)))))

(defgeneric model-mesh-part-tag (part)
  (:documentation "See TAG; this exists so the reader has a docstring of its own."))

;;; --- ModelMesh -------------------------------------------------------------

(defclass model-mesh (%model-view)
  ((%name :reader model-mesh-name)
   (%parent-bone :initform nil :reader model-mesh-parent-bone)
   (%bounding-sphere :reader model-mesh-bounding-sphere)
   (%mesh-parts :initform nil)
   (%effects :initform nil)
   (%tag :initform nil))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.ModelMesh: the meshes a model is drawn as.

`Name', `ParentBone', `BoundingSphere', `MeshParts' and `Effects' are all `ldfld'
getters over fields its `assembly' constructor sets, so the first three are read
once when the graph is built and the last two are the objects built with it.
`Tag' has a setter and is a managed slot; `Draw()' is DRAW-MODEL-MESH."))

(defmethod %collection-element-model-name ((element model-mesh))
  (model-mesh-name element))

(defgeneric model-mesh-parts (mesh)
  (:documentation "`ModelMesh.MeshParts': the parts this mesh is drawn as."))

(defmethod model-mesh-parts ((mesh model-mesh))
  (cna-lisp.internal:check-usable mesh "model-mesh-parts")
  (slot-value mesh '%mesh-parts))

(defgeneric model-mesh-effects (mesh)
  (:documentation
   "`ModelMesh.Effects': the distinct effects this mesh's parts use.

The same collection object every time, as XNA's field is, and its contents follow
`ModelMeshPart.Effect''s setter -- see that member."))

(defmethod model-mesh-effects ((mesh model-mesh))
  (cna-lisp.internal:check-usable mesh "model-mesh-effects")
  (slot-value mesh '%effects))

;;; --- Model -----------------------------------------------------------------

(defclass model (cna-lisp.internal:native-object)
  ((%bones :initform nil)
   (%bone-vector :initform #())
   (%meshes :initform nil)
   (%root :initform nil :reader model-root)
   (%tag :initform nil)
   (%native-parts :initform '() :accessor %model-native-parts
                  :documentation
                  "Every owned CNA handle this model must give back, newest
first -- which is leaf-first, because a collection view is taken before the
elements read out of it.")
   (%resource-objects :initform (make-hash-table :test #'eql)
                      :reader %model-resource-objects
                      :documentation
                      "CNA effect and buffer handle -> the one CLOS object for
it. Handle identity is a faithful key here and only here: CNA's loader publishes
one handle per distinct native effect or buffer, keyed on the native pointer, and
a part's getter answers the stored handle rather than a fresh one."))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.Model: a loaded mesh hierarchy.

    (let ((model (xna.content:load-asset (xna:content game) \"robot\" 'model)))
      (draw-model model world view projection))

**No public constructor**, because XNA has none: `Model..ctor' is `assembly' and
the only public producer is `ContentManager.Load<Model>'. CNA's
`cna_model_create*' routes exist and are bound, and this file uses them to build
deterministic fixtures for its own tests -- a private producer is not API.

**Not IDisposable either**, and the handle is still released. This is
`SpriteFont''s situation exactly: the public shape is XNA's, and the handle goes
back through MICROSOFT.XNA.FRAMEWORK:DISPOSE, which is this binding's own
deterministic disposal and a declared extension rather than an XNA member of this
type. `ContentManager.Unload' is what calls it for a loaded model."))

(defmethod initialize-instance :after ((model model) &key %adopted-handle %adopted-game
                                      &allow-other-keys)
  "A model is only ever adopted: XNA has no public constructor and neither has this.

MAKE-INSTANCE with no adopted handle answers a model with no graph rather than
refusing, because the class is also what CLOS needs to exist before
`ContentManager.Load' can name it -- but every producer in this binding supplies
one. There is no public route to a model without a handle, and the structural
verifier records that `Model' has no projected constructor at all."
  (when %adopted-handle
    (%adopt-model model %adopted-game %adopted-handle)))

(defgeneric model-bones (model)
  (:documentation "`Model.Bones': every bone, in model order, the root included."))

(defmethod model-bones ((model model))
  (cna-lisp.internal:check-usable model "model-bones")
  (slot-value model '%bones))

(defgeneric model-meshes (model)
  (:documentation "`Model.Meshes': the meshes this model draws."))

(defmethod model-meshes ((model model))
  (cna-lisp.internal:check-usable model "model-meshes")
  (slot-value model '%meshes))

(defmethod model-root :around ((model model))
  (cna-lisp.internal:check-usable model "model-root")
  (call-next-method))

;;; --- Tag, on all three types that have one ---------------------------------
;;;
;;; XNA's `Tag' is `System.Object' -- arbitrary consumer data the framework never
;;; reads. CNA's is a `uint64' token, which cannot hold a Lisp object and could
;;; only hold a pointer to one, and putting a pointer to a moving object into C is
;;; the thing this binding never does. So the tag is a Lisp slot and is not
;;; round-tripped through the C ABI, exactly as `GraphicsResource.Tag' already is
;;; -- and it therefore preserves EQ-ness of whatever a program puts in it, which
;;; a `uint64' could not. The three `cna_model_*_tag' routes are not bound at all.

(macrolet ((tagged (class operation)
             `(progn
                (defmethod tag ((object ,class))
                  (cna-lisp.internal:check-usable object ,operation)
                  (slot-value object '%tag))
                (defmethod (setf tag) (value (object ,class))
                  (cna-lisp.internal:check-usable object ,(concatenate 'string "setf " operation))
                  (setf (slot-value object '%tag) value)))))
  (tagged model "tag")
  (tagged model-mesh "tag")
  (tagged model-mesh-part "tag"))

;;; --- the three bone-transform operations -----------------------------------
;;;
;;; All three are transcribed from the pinned IL, validation order included:
;;; the null check first, then `destination.Length < bones.Count' as an
;;; ArgumentOutOfRangeException, then the loop. A destination *longer* than the
;;; bone count is accepted and only its first Count entries are touched, which is
;;; what `Model.Draw' relies on -- it reuses one static array across models.
;;;
;;; **The values come from CNA and the arithmetic does not.**
;;; `cna_model_copy_bone_transforms' answers the same local transforms XNA's
;;; `bones[i].transform' does, so the local copies use it. The *absolute* ones
;;; are computed here instead, out of the locals and the parent links, because
;;; the multiplication order is the whole content of the member: XNA's IL is
;;;
;;;     dest[i] = bone.Parent == null ? bone.transform
;;;                                   : bone.transform * dest[bone.Parent.Index]
;;;
;;; -- the *local* on the left and the parent's *already computed absolute* on
;;; the right, which reads parents before children and therefore assumes the
;;; array is in parent-first order, as a loaded model's is. Taking CNA's
;;; convenience route instead would make this binding's answer CNA's rather than
;;; XNA's; the tests assert that the two agree, which is a measurement.

(defun %model-bone-count (model operation)
  (let ((handle (cna-lisp.internal:handle-of model)))
    (cna-lisp.internal:check-usable model operation)
    (cffi:with-foreign-object (out :uint64)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%model-get-bone-transform-count handle out)
       operation :object-type 'model)
      (cffi:mem-ref out :uint64))))

(defun %model-local-transforms (model operation)
  "Every bone's local transform, in model order, as a fresh vector."
  (cna-lisp.internal:check-usable model operation)
  (let ((handle (cna-lisp.internal:handle-of model))
        (count (%model-bone-count model operation)))
    (if (zerop count)
        (vector)
        (cffi:with-foreign-object (buffer '(:struct cna-lisp.internal.ffi::cna-matrix) count)
          (cffi:with-foreign-object (out :uint64)
            (cna-lisp.internal:check-result
             (cna-lisp.internal.ffi::%model-copy-bone-transforms handle buffer count out)
             operation :object-type 'model))
          (let ((result (make-array count)))
            (dotimes (index count result)
              (setf (aref result index)
                    (%read-matrix
                     (cffi:mem-aptr buffer '(:struct cna-lisp.internal.ffi::cna-matrix) index)))))))))

(defun %model-write-bone-transforms (model transforms operation)
  "Write every bone's local transform back, in one atomic native call."
  (let ((handle (cna-lisp.internal:handle-of model))
        (count (length transforms)))
    (if (zerop count)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%model-set-bone-transforms handle (cffi:null-pointer) 0)
         operation :object-type 'model)
        (cffi:with-foreign-object (buffer '(:struct cna-lisp.internal.ffi::cna-matrix) count)
          (dotimes (index count)
            (%write-matrix
             (cffi:mem-aptr buffer '(:struct cna-lisp.internal.ffi::cna-matrix) index)
             (aref transforms index)))
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%model-set-bone-transforms handle buffer count)
           operation :object-type 'model)))))

(defun %check-transform-destination (model destination operation parameter)
  "XNA's two checks, in XNA's order, and the bone count they are made against."
  (cna-lisp.internal:check-usable model operation)
  (unless destination
    (error 'microsoft.xna.framework:cna-argument-error
           :operation operation :object-type 'model :parameter-name parameter
           :format-control "~a must not be NIL: XNA throws ArgumentNullException."
           :format-arguments (list parameter)))
  (unless (typep destination 'sequence)
    (error 'microsoft.xna.framework:cna-argument-error
           :operation operation :object-type 'model :parameter-name parameter
           :format-control "~a must be a sequence of matrices." :format-arguments (list parameter)))
  (let ((count (%model-bone-count model operation)))
    (when (< (length destination) count)
      (error 'microsoft.xna.framework:cna-argument-out-of-range-error
             :operation operation :object-type 'model :parameter-name parameter
             :format-control
             "~a holds ~d matri~:@p and this model has ~d bone~:p. XNA throws ~
              ArgumentOutOfRangeException when the destination is shorter than ~
              Bones.Count; a longer one is accepted and only its first ~d entries ~
              are written."
             :format-arguments (list parameter (length destination) count count)))
    count))

(defgeneric copy-bone-transforms-to (model destination)
  (:documentation
   "`Model.CopyBoneTransformsTo(Matrix[])': every bone's transform relative to
its parent, written into DESTINATION in bone order.

DESTINATION is any sequence of at least `Bones.Count' elements and is answered.
NIL is an ArgumentException and a short destination an ArgumentOutOfRangeException,
in that order, which is the order the IL checks them."))

(defmethod copy-bone-transforms-to ((model model) destination)
  (let* ((operation "copy-bone-transforms-to")
         (count (%check-transform-destination model destination operation
                                              "destination-bone-transforms"))
         (locals (%model-local-transforms model operation)))
    (dotimes (index count) (setf (elt destination index) (aref locals index))))
  destination)

(defgeneric copy-bone-transforms-from (model source)
  (:documentation
   "`Model.CopyBoneTransformsFrom(Matrix[])': set every bone's local transform
from SOURCE.

The same two checks in the same order, against `sourceBoneTransforms'. Only the
first `Bones.Count' elements are read."))

(defmethod copy-bone-transforms-from ((model model) source)
  (let* ((operation "copy-bone-transforms-from")
         (count (%check-transform-destination model source operation
                                              "source-bone-transforms"))
         (transforms (make-array count)))
    (dotimes (index count)
      (let ((matrix (elt source index)))
        (check-type matrix microsoft.xna.framework:matrix)
        (setf (aref transforms index) matrix)))
    (%model-write-bone-transforms model transforms operation))
  source)

(defun %model-absolute-transforms (model operation)
  "The absolute transform of every bone, computed exactly as the IL computes it."
  (let* ((locals (%model-local-transforms model operation))
         (bones (%collection-items (slot-value model '%bones)))
         (count (length locals))
         (absolute (make-array count)))
    (dotimes (index count absolute)
      (let* ((bone (aref bones index))
             (parent (model-bone-parent bone)))
        (setf (aref absolute index)
              (if (null parent)
                  (aref locals index)
                  (microsoft.xna.framework:matrix-multiply
                   (aref locals index)
                   (aref absolute (model-bone-index parent)))))))))

(defgeneric copy-absolute-bone-transforms-to (model destination)
  (:documentation
   "`Model.CopyAbsoluteBoneTransformsTo(Matrix[])': each bone's transform
composed with every ancestor's, written into DESTINATION in bone order.

    absolute[i] = bone.Parent == null ? local[i]
                                      : local[i] * absolute[bone.Parent.Index]

-- the local on the left, which is the order the IL's `op_Multiply' arguments
are pushed in, and the parent's already-computed absolute on the right. The loop
runs in bone order and reads `absolute[parentIndex]', so it is correct exactly
when a bone's parent precedes it, which is how a loaded model is built."))

(defmethod copy-absolute-bone-transforms-to ((model model) destination)
  (let* ((operation "copy-absolute-bone-transforms-to")
         (count (%check-transform-destination model destination operation
                                              "destination-bone-transforms"))
         (absolute (%model-absolute-transforms model operation)))
    (dotimes (index count) (setf (elt destination index) (aref absolute index))))
  destination)

;;; --- drawing ---------------------------------------------------------------
;;;
;;; **Both draws are transcribed rather than delegated, and that is the decision
;;; this closure turns on.** CNA has `cna_model_draw' and `cna_model_mesh_draw',
;;; and neither is bound. Three reasons, in order of weight:
;;;
;;; 1. **`Model.Draw' is observable through its effects.** Its whole body is a
;;;    walk that assigns `World', `View' and `Projection' on every effect of
;;;    every mesh, and a program can read those back afterwards. A native route
;;;    that drew the same pixels while leaving different values in those
;;;    properties would be a different member; delegating would make the
;;;    binding's answer unprovable rather than merely unproved.
;;; 2. **Two refusals are part of the contract.** A null effect and an effect
;;;    that is not `IEffectMatrices' are each an `InvalidOperationException` with
;;;    its own resource string, thrown *before* anything is drawn. Nothing says
;;;    CNA's route produces them.
;;; 3. `cna_model_draw' takes three `CNA_Matrix' by value -- three MEMORY-class
;;;    64-byte aggregates -- so binding it at all would need a fourth shimmed
;;;    route for no gain.
;;;
;;; What they are transcribed *onto* is this binding's own public surface:
;;; SET-VERTEX-BUFFER, `(setf INDICES)' and DRAW-INDEXED-PRIMITIVES are exactly
;;; the three calls `ModelMeshPart.Draw' makes, and they are already qualified.

(defun %model-has-effect-matrices-p (effect)
  "Whether EFFECT satisfies `IEffectMatrices'.

A CLR interface projects onto the generic functions its members become -- a type
satisfies it by having methods, with nothing to declare -- so the test is whether
those generic functions have one."
  (and (compute-applicable-methods #'effect-world (list effect))
       (compute-applicable-methods #'effect-view (list effect))
       (compute-applicable-methods #'effect-projection (list effect))
       t))

(defun %model-effect-refusal (operation what)
  (error 'microsoft.xna.framework:cna-invalid-state-error
         :operation operation
         :object-type 'model
         :format-control "~a" :format-arguments (list what)))

(defgeneric draw-model (model world view projection)
  (:documentation
   "`Model.Draw(Matrix world, Matrix view, Matrix projection)'.

Transcribed from the pinned IL:

    absolute = CopyAbsoluteBoneTransformsTo(a scratch array of Bones.Count)
    for each mesh:
        boneIndex = mesh.ParentBone.Index
        for each effect in mesh.Effects:
            if effect is null                 -> InvalidOperationException
            if effect is not IEffectMatrices  -> InvalidOperationException
            effect.World      = absolute[boneIndex] * world
            effect.View       = view
            effect.Projection = projection
        mesh.Draw()

Note the order: **every** effect of a mesh is configured before that mesh draws,
and the world matrix is the mesh's absolute bone transform *times* the caller's
world -- bone transform on the left.

XNA reuses one `static Matrix[] sharedDrawBoneMatrices' across every model in the
process and grows it when a model has more bones. A fresh array per call is used
here instead: the static is not observable, it is not thread-safe, and the
allocation it saves is one array per frame.

**Needs the optional private shim**, because assigning `World', `View' and
`Projection' does: `cna_effect_matrices_set_*' take `CNA_Matrix' by value. Without
`CNA_LISP_SHIM' this refuses with the same actionable condition those setters do.
DRAW-MODEL-MESH needs no shim and draws the same geometry."))

(defmethod draw-model ((model model) world view projection)
  (let ((operation "draw-model"))
    (check-type world microsoft.xna.framework:matrix)
    (check-type view microsoft.xna.framework:matrix)
    (check-type projection microsoft.xna.framework:matrix)
    (cna-lisp.internal:check-usable model operation)
    (let ((absolute (%model-absolute-transforms model operation)))
      (dolist (mesh (collection-elements (model-meshes model)))
        (let* ((parent (model-mesh-parent-bone mesh))
               (bone-index (if parent (model-bone-index parent) 0)))
          (dolist (effect (collection-elements (model-mesh-effects mesh)))
            (unless effect
              (%model-effect-refusal
               operation
               "a mesh of this model has no effect. XNA throws InvalidOperationException
                with the ModelHasNoEffect message before drawing anything."))
            (unless (%model-has-effect-matrices-p effect)
              (%model-effect-refusal
               operation
               "an effect of this model does not implement IEffectMatrices, so Draw has
                nowhere to put the world, view and projection matrices. XNA throws
                InvalidOperationException with the ModelHasNoIEffectMatrices message."))
            (setf (effect-world effect)
                  (microsoft.xna.framework:matrix-multiply (aref absolute bone-index) world)
                  (effect-view effect) view
                  (effect-projection effect) projection))
          (draw-model-mesh mesh)))))
  (values))

(defgeneric draw-model-mesh (mesh)
  (:documentation
   "`ModelMesh.Draw()'.

Transcribed from the pinned IL:

    for each part in MeshParts:
        effect = part.Effect
        if effect is null -> InvalidOperationException (ModelHasNoEffect)
        for each pass in effect.CurrentTechnique.Passes:
            pass.Apply()
            part.Draw()

**`part.Draw()' is inside the pass loop**, so a part with two passes is submitted
twice. That is XNA's, not a transcription slip, and it is what makes a multi-pass
effect draw at all.

`ModelMeshPart.Draw' itself is `assembly' in XNA and is not a member of this
contract. What it does is reproduced here out of the public device surface:

    if NumVertices <= 0: nothing
    device = VertexBuffer.GraphicsDevice
    device.SetVertexBuffer(VertexBuffer, VertexOffset)
    device.Indices = IndexBuffer
    device.DrawIndexedPrimitives(TriangleList, 0, 0, NumVertices, StartIndex, PrimitiveCount)

-- baseVertex and minVertexIndex both zero, and the primitive type a literal
`TriangleList', all three read straight off the IL.

Sets no matrices, so unlike DRAW-MODEL it needs no shim."))

(defmethod draw-model-mesh ((mesh model-mesh))
  (let ((operation "draw-model-mesh"))
    (cna-lisp.internal:check-usable mesh operation)
    (dolist (part (collection-elements (model-mesh-parts mesh)))
      (let ((effect (model-mesh-part-effect part)))
        (unless effect
          (%model-effect-refusal
           operation
           "a part of this mesh has no effect. XNA throws InvalidOperationException
            with the ModelHasNoEffect message."))
        (dolist (pass (collection-elements
                       (effect-technique-passes (effect-current-technique effect))))
          (apply-effect-pass pass)
          (%draw-model-mesh-part part operation)))))
  (values))

(defun %draw-model-mesh-part (part operation)
  "`ModelMeshPart.Draw()', which is assembly-visible in XNA and is not a member."
  (let ((vertices (model-mesh-part-num-vertices part)))
    (when (plusp vertices)
      (let* ((vertex-buffer (model-mesh-part-vertex-buffer part))
             (index-buffer (model-mesh-part-index-buffer part)))
        (unless (and vertex-buffer index-buffer)
          (error 'microsoft.xna.framework:cna-invalid-state-error
                 :operation operation :object-type 'model-mesh-part
                 :format-control
                 "this part has ~d vertices and no ~:[index~;vertex~] buffer. XNA's
                  ModelMeshPart.Draw dereferences both without checking, so a part in
                  this state is one the content pipeline cannot produce."
                 :format-arguments (list vertices (null vertex-buffer))))
        (let ((device (graphics-resource-graphics-device vertex-buffer)))
          (set-vertex-buffer device vertex-buffer (model-mesh-part-vertex-offset part))
          (setf (indices device) index-buffer)
          (draw-indexed-primitives device :triangle-list 0 0 vertices
                                   (model-mesh-part-start-index part)
                                   (model-mesh-part-primitive-count part)))))))

;;; --- the ledger ------------------------------------------------------------

(defun %model-retain (model thunk)
  "Record one thing MODEL must undo, and answer THUNK.

Newest first, which is leaf first: a collection view is always taken before the
elements read out of it, and an element before anything resolved through it. The
same shape the Effect graph uses, and for the same reason -- destruction used to
be a second copy of the construction walk, and a kind added to one and forgotten
in the other leaks a handle CNA is still owed."
  (push thunk (%model-native-parts model))
  thunk)

(defun %model-retain-handle (model handle destroyer)
  "Record a CNA handle MODEL must give back, and answer it."
  (%model-retain model (lambda () (funcall destroyer handle)))
  handle)

(defmacro %with-transient-model-handle ((variable form destroyer) &body body)
  "Hold a handle only for BODY, and give it back however BODY leaves.

Every route that answers a bone, a mesh or a collection makes a **new** registry
handle -- CNA's `CreateBoneHandle' does `GetRuntimeHandles().Create' on every
call -- so a parent read for its index alone is a handle nobody wants to keep.
Keeping it would be correct and wasteful; forgetting it would be a leak."
  `(let ((,variable ,form))
     (unwind-protect (progn ,@body)
       (ignore-errors (funcall ,destroyer ,variable)))))

;;; --- resolving an effect or a buffer to the one object for it --------------

(defun %model-existing-child (game handle class)
  "A live child of GAME of CLASS holding HANDLE, or NIL.

**This is what keeps a hand-built model's effect the caller's own object.** A
program that made a BasicEffect and put it on a part must get *that* object back
from `part.Effect', not a second wrapper over the same handle. The game's child
list is the complete set of objects a program made, so it is the right place to
look, and a handle nothing there owns is one the model owns."
  (find-if (lambda (child)
             (and (typep child class)
                  (not (cna-lisp.internal:disposed-state-of child))
                  (eql handle (cna-lisp.internal:handle-of child))))
           (cna-lisp.internal:children-of game)))

(defun %model-own-resource (model object &optional release)
  "Re-parent OBJECT to MODEL as something the model owns and the caller may not.

`:PARENT-OWNED' is the ownership kind whose DISPOSE already refuses with \"a
facade over something its parent owns ... dispose the parent instead\", which is
the exact truth for a content-loaded model's effect and buffers: CNA refuses the
destroy too, because `cna_content_manager_load_model' marks a model-owned effect
`disposeAllowed = false'."
  (setf (slot-value object 'cna-lisp.internal::owner) model
        (slot-value object 'cna-lisp.internal::ownership) :parent-owned
        (cna-lisp.internal:owner-generation-of object)
        (cna-lisp.internal:generation-of model))
  (%model-retain model (lambda ()
                         (when release (ignore-errors (funcall release object)))
                         (cna-lisp.internal:invalidate object)))
  object)

(defun %model-resolve-effect (model game handle)
  (when (plusp handle)
    (or (gethash handle (%model-resource-objects model))
        (setf (gethash handle (%model-resource-objects model))
              (let ((existing (%model-existing-child game handle 'effect)))
                (or existing
                    (%model-own-resource
                     model
                     ;; **The graph is deliberately not read.** CNA publishes a
                     ;; loaded model's effect handle with no adapter state, and
                     ;; every route that reads it dereferences null rather than
                     ;; refusing -- measured on both admitted ABIs. The class is
                     ;; still the one CNA's own type name reports, because that
                     ;; route is safe, so the object is the right type with the
                     ;; right identity and says so when asked for what it cannot
                     ;; answer. See %REFUSE-CONTENT-PUBLISHED-GRAPH.
                     (%adopt-loaded-effect game handle "model-mesh-part-effect"
                                           :content-published t)
                     ;; Its own handle is the model's and must never reach
                     ;; cna_effect_destroy; any view this binding took for it is
                     ;; not the model's and must.
                     #'%release-native-parts)))))))

(defun %model-resolve-buffer (model game handle class)
  (when (plusp handle)
    (or (gethash handle (%model-resource-objects model))
        (setf (gethash handle (%model-resource-objects model))
              (or (%model-existing-child game handle class)
                  (%model-own-resource
                   model
                   (make-instance class :%adopted-handle handle :%adopted-game game)))))))

(defun %model-optional-handle (route object out-flag out-handle operation type)
  "Call a CNA route shaped (object, CNA_Bool* has, Handle* out) and answer the handle or 0."
  (cna-lisp.internal:check-result (funcall route object out-flag out-handle)
                                  operation :object-type type)
  (if (zerop (cffi:mem-ref out-flag :uint8)) 0 (cffi:mem-ref out-handle :uint64)))

;;; --- building the graph ----------------------------------------------------

(defun %model-collection-count (handle route operation)
  (cffi:with-foreign-object (out :uint64)
    (cna-lisp.internal:check-result (funcall route handle out) operation)
    (cffi:mem-ref out :uint64)))

(defun %model-collection-element (handle index route operation)
  (cffi:with-foreign-object (out :uint64)
    (cna-lisp.internal:check-result (funcall route handle index out) operation)
    (cffi:mem-ref out :uint64)))

(defun %model-view-name (handle size-route copy-route operation)
  (cna-lisp.internal:count-then-copy-string
   (lambda (out) (funcall size-route handle out))
   (lambda (buffer capacity out) (funcall copy-route handle buffer capacity out))
   operation))

(defun %model-bone-native-index (handle operation)
  (cffi:with-foreign-object (out :int32)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%model-bone-get-index handle out) operation)
    (cffi:mem-ref out :int32)))

(defun %model-build-bones (model game)
  "Every bone, in model order, with its parent and children resolved by index."
  (declare (ignore game))
  (let* ((operation "model-bones")
         (handle (cna-lisp.internal:handle-of model))
         (collection
           (%model-retain-handle
            model
            (cffi:with-foreign-object (out :uint64)
              (cna-lisp.internal:check-result
               (cna-lisp.internal.ffi::%model-get-bones handle out) operation)
              (cffi:mem-ref out :uint64))
            #'cna-lisp.internal.ffi::%model-bone-collection-destroy))
         (count (%model-collection-count
                 collection #'cna-lisp.internal.ffi::%model-bone-collection-get-count operation))
         (bones (make-array count)))
    ;; First pass: one object per bone, keyed by the index CNA reports, which is
    ;; the index XNA's `ModelBone.Index' answers and the one every cross-reference
    ;; in the graph is expressed in.
    (dotimes (position count)
      (let ((bone-handle
              (%model-retain-handle
               model
               (%model-collection-element
                collection position
                #'cna-lisp.internal.ffi::%model-bone-collection-get-at operation)
               #'cna-lisp.internal.ffi::%model-bone-destroy)))
        (let ((bone (make-instance 'model-bone :model model :handle bone-handle
                                               :ownership :parent-owned
                                               :owner model)))
          (setf (slot-value bone 'cna-lisp.internal::owner-thread)
                (cna-lisp.internal:owner-thread-of model)
                (cna-lisp.internal:owner-generation-of bone)
                (cna-lisp.internal:generation-of model)
                (slot-value bone '%index)
                (%model-bone-native-index bone-handle "model-bone-index")
                (slot-value bone '%name)
                (%model-view-name bone-handle
                                  #'cna-lisp.internal.ffi::%model-bone-get-name-byte-count
                                  #'cna-lisp.internal.ffi::%model-bone-copy-name
                                  "model-bone-name"))
          (%model-retain model (lambda () (cna-lisp.internal:invalidate bone)))
          (setf (aref bones position) bone))))
    (setf (slot-value model '%bone-vector) bones)
    ;; Second pass: parents and children, resolved through the index map. The
    ;; handles CNA answers here are duplicates of ones already held, so each is
    ;; read for its index and given straight back.
    (flet ((bone-at (index)
             (when (and (>= index 0) (< index count)) (aref bones index))))
      (loop for bone across bones
            for bone-handle = (cna-lisp.internal:handle-of bone)
            do (cffi:with-foreign-objects ((flag :uint8) (out :uint64))
                 (let ((parent (%model-optional-handle
                                #'cna-lisp.internal.ffi::%model-bone-get-parent
                                bone-handle flag out "model-bone-parent" 'model-bone)))
                   (unless (zerop parent)
                     (%with-transient-model-handle
                         (transient parent #'cna-lisp.internal.ffi::%model-bone-destroy)
                       (setf (slot-value bone '%parent)
                             (bone-at (%model-bone-native-index
                                       transient "model-bone-parent")))))))
               (%with-transient-model-handle
                   (children (cffi:with-foreign-object (out :uint64)
                               (cna-lisp.internal:check-result
                                (cna-lisp.internal.ffi::%model-bone-get-children bone-handle out)
                                "model-bone-children")
                               (cffi:mem-ref out :uint64))
                             #'cna-lisp.internal.ffi::%model-bone-collection-destroy)
                 (let* ((child-count
                          (%model-collection-count
                           children #'cna-lisp.internal.ffi::%model-bone-collection-get-count
                           "model-bone-children"))
                        (resolved (make-array child-count)))
                   (dotimes (position child-count)
                     (%with-transient-model-handle
                         (child (%model-collection-element
                                 children position
                                 #'cna-lisp.internal.ffi::%model-bone-collection-get-at
                                 "model-bone-children")
                                #'cna-lisp.internal.ffi::%model-bone-destroy)
                       (setf (aref resolved position)
                             (bone-at (%model-bone-native-index
                                       child "model-bone-children")))))
                   (setf (slot-value bone '%children)
                         (make-instance 'model-bone-collection
                                        :items resolved :model model)))))
      (setf (slot-value model '%bones)
            (make-instance 'model-bone-collection :items bones :model model))
      ;; The root, resolved the same way.
      (cffi:with-foreign-objects ((flag :uint8) (out :uint64))
        (let ((root (%model-optional-handle
                     #'cna-lisp.internal.ffi::%model-get-root
                     handle flag out "model-root" 'model)))
          (unless (zerop root)
            (%with-transient-model-handle
                (transient root #'cna-lisp.internal.ffi::%model-bone-destroy)
              (setf (slot-value model '%root)
                    (bone-at (%model-bone-native-index transient "model-root"))))))))
    bones))

(defun %model-build-mesh-parts (model game mesh mesh-handle)
  "One object per part of MESH, with its effect and buffers resolved."
  (let* ((operation "model-mesh-parts")
         (collection
           (%model-retain-handle
            model
            (cffi:with-foreign-object (out :uint64)
              (cna-lisp.internal:check-result
               (cna-lisp.internal.ffi::%model-mesh-get-mesh-parts mesh-handle out) operation)
              (cffi:mem-ref out :uint64))
            #'cna-lisp.internal.ffi::%model-mesh-part-collection-destroy))
         (count (%model-collection-count
                 collection
                 #'cna-lisp.internal.ffi::%model-mesh-part-collection-get-count operation))
         (parts (make-array count)))
    (dotimes (position count)
      (let* ((part-handle
               (%model-retain-handle
                model
                (%model-collection-element
                 collection position
                 #'cna-lisp.internal.ffi::%model-mesh-part-collection-get-at operation)
                #'cna-lisp.internal.ffi::%model-mesh-part-destroy))
             (part (make-instance 'model-mesh-part :model model :mesh mesh
                                                   :handle part-handle
                                                   :ownership :parent-owned :owner model)))
        (setf (slot-value part 'cna-lisp.internal::owner-thread)
              (cna-lisp.internal:owner-thread-of model)
              (cna-lisp.internal:owner-generation-of part)
              (cna-lisp.internal:generation-of model))
        (%model-retain model (lambda () (cna-lisp.internal:invalidate part)))
        (cffi:with-foreign-objects ((flag :uint8) (out :uint64))
          (setf (slot-value part '%effect)
                (%model-resolve-effect
                 model game
                 (%model-optional-handle
                  #'cna-lisp.internal.ffi::%model-mesh-part-get-effect
                  part-handle flag out "model-mesh-part-effect" 'model-mesh-part))
                (slot-value part '%vertex-buffer)
                (%model-resolve-buffer
                 model game
                 (%model-optional-handle
                  #'cna-lisp.internal.ffi::%model-mesh-part-get-vertex-buffer
                  part-handle flag out "model-mesh-part-vertex-buffer" 'model-mesh-part)
                 'vertex-buffer)
                (slot-value part '%index-buffer)
                (%model-resolve-buffer
                 model game
                 (%model-optional-handle
                  #'cna-lisp.internal.ffi::%model-mesh-part-get-index-buffer
                  part-handle flag out "model-mesh-part-index-buffer" 'model-mesh-part)
                 'index-buffer)))
        (setf (aref parts position) part)))
    (make-instance 'model-mesh-part-collection :items parts :model model)))

(defun %model-build-mesh-effects (model game mesh-handle)
  "`ModelMesh.Effects', read from CNA rather than derived from the parts.

Reading it is the point: the collection is maintained by
`ModelMeshPart.set_Effect' on both sides, and taking CNA's answer at construction
and XNA's algorithm afterwards is what lets a test assert the two agree."
  (let* ((operation "model-mesh-effects")
         (collection
           (%model-retain-handle
            model
            (cffi:with-foreign-object (out :uint64)
              (cna-lisp.internal:check-result
               (cna-lisp.internal.ffi::%model-mesh-get-effects mesh-handle out) operation)
              (cffi:mem-ref out :uint64))
            #'cna-lisp.internal.ffi::%model-effect-collection-destroy))
         (count (%model-collection-count
                 collection
                 #'cna-lisp.internal.ffi::%model-effect-collection-get-count operation))
         (effects (make-array count)))
    (dotimes (position count)
      (setf (aref effects position)
            (%model-resolve-effect
             model game
             (%model-collection-element
              collection position
              #'cna-lisp.internal.ffi::%model-effect-collection-get-at operation))))
    (make-instance 'model-effect-collection :items effects :model model)))

(defun %model-build-meshes (model game)
  (let* ((operation "model-meshes")
         (handle (cna-lisp.internal:handle-of model))
         (bones (slot-value model '%bone-vector))
         (collection
           (%model-retain-handle
            model
            (cffi:with-foreign-object (out :uint64)
              (cna-lisp.internal:check-result
               (cna-lisp.internal.ffi::%model-get-meshes handle out) operation)
              (cffi:mem-ref out :uint64))
            #'cna-lisp.internal.ffi::%model-mesh-collection-destroy))
         (count (%model-collection-count
                 collection #'cna-lisp.internal.ffi::%model-mesh-collection-get-count operation))
         (meshes (make-array count)))
    (dotimes (position count)
      (let* ((mesh-handle
               (%model-retain-handle
                model
                (%model-collection-element
                 collection position
                 #'cna-lisp.internal.ffi::%model-mesh-collection-get-at operation)
                #'cna-lisp.internal.ffi::%model-mesh-destroy))
             (mesh (make-instance 'model-mesh :model model :handle mesh-handle
                                              :ownership :parent-owned :owner model)))
        (setf (slot-value mesh 'cna-lisp.internal::owner-thread)
              (cna-lisp.internal:owner-thread-of model)
              (cna-lisp.internal:owner-generation-of mesh)
              (cna-lisp.internal:generation-of model))
        (%model-retain model (lambda () (cna-lisp.internal:invalidate mesh)))
        (setf (slot-value mesh '%name)
              (%model-view-name mesh-handle
                                #'cna-lisp.internal.ffi::%model-mesh-get-name-byte-count
                                #'cna-lisp.internal.ffi::%model-mesh-copy-name
                                "model-mesh-name"))
        (cffi:with-foreign-object (sphere '(:struct cna-lisp.internal.ffi::cna-bounding-sphere))
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%model-mesh-get-bounding-sphere mesh-handle sphere)
           "model-mesh-bounding-sphere" :object-type 'model-mesh)
          (setf (slot-value mesh '%bounding-sphere)
                (microsoft.xna.framework:make-bounding-sphere
                 (%read-vector3
                  (cffi:foreign-slot-pointer
                   sphere '(:struct cna-lisp.internal.ffi::cna-bounding-sphere)
                   'cna-lisp.internal.ffi::center))
                 (cffi:foreign-slot-value
                  sphere '(:struct cna-lisp.internal.ffi::cna-bounding-sphere)
                  'cna-lisp.internal.ffi::radius))))
        (cffi:with-foreign-objects ((flag :uint8) (out :uint64))
          (let ((parent (%model-optional-handle
                         #'cna-lisp.internal.ffi::%model-mesh-get-parent-bone
                         mesh-handle flag out "model-mesh-parent-bone" 'model-mesh)))
            (unless (zerop parent)
              (%with-transient-model-handle
                  (transient parent #'cna-lisp.internal.ffi::%model-bone-destroy)
                (let ((index (%model-bone-native-index transient "model-mesh-parent-bone")))
                  (setf (slot-value mesh '%parent-bone)
                        (when (and (>= index 0) (< index (length bones)))
                          (aref bones index))))))))
        (setf (slot-value mesh '%mesh-parts)
              (%model-build-mesh-parts model game mesh mesh-handle)
              (slot-value mesh '%effects)
              (%model-build-mesh-effects model game mesh-handle)
              (aref meshes position) mesh)))
    (setf (slot-value model '%meshes)
          (make-instance 'model-mesh-collection :items meshes :model model))))

(defun %adopt-model (model game handle)
  "Take HANDLE and build the whole graph, in one transaction.

**Eager, because XNA's collections are arrays built once.** `Bones[0]' twice is
the same object there, and CNA answers a fresh handle every time, so a lazy
projection could not answer EQ without a map -- and a map that is complete by
construction is simpler than one filled in as a program wanders the graph.
Building it here also makes the whole load one failure domain: NATIVE-OBJECT's
construction ledger runs the model's own undo, which is this model's ledger, so a
route that fails half way through gives every handle back and leaves no object
behind."
  (setf (cna-lisp.internal:handle-of model) handle
        (slot-value model 'cna-lisp.internal::owner) game
        (slot-value model 'cna-lisp.internal::owner-thread)
        (cna-lisp.internal:owner-thread-of game))
  (cna-lisp.internal:register-child game model)
  (cna-lisp.internal:record-construction-undo
   model (lambda ()
           (ignore-errors (cna-lisp.internal.ffi::%model-destroy handle))
           (cna-lisp.internal:invalidate model)))
  (cna-lisp.internal:record-construction-undo
   model (lambda () (%model-release-parts model :quietly t)))
  (%model-build-bones model game)
  (%model-build-meshes model game)
  model)

;;; --- destruction -----------------------------------------------------------

(defun %model-release-parts (model &key quietly)
  "Run the ledger newest-first, and answer the first failure rather than the last.

Keeps going after one: a handle that could not be released is bad news, but
stopping would leave every handle behind it alive as well. QUIETLY is for the
construction rollback, where a failure here must not mask the one that caused it."
  (let ((first-failure nil))
    (dolist (thunk (%model-native-parts model))
      (if quietly
          (ignore-errors (funcall thunk))
          (handler-case (funcall thunk)
            (serious-condition (condition)
              (unless first-failure (setf first-failure condition))))))
    (setf (%model-native-parts model) '())
    first-failure))

(defmethod cna-lisp.internal:destroy-native ((model model))
  "Give the graph back, then the model.

Leaf-first, because CNA destroys children before parents and refuses the other
order. The model handle goes last, and it goes even when a part of the graph
could not be released: a model handle left alive is one `cna_game_destroy'
refuses to shut down over, which a consumer would see much later and nowhere near
here."
  (let ((first-failure (%model-release-parts model)))
    (unwind-protect
         (cna-lisp.internal:check-result
          (cna-lisp.internal.ffi::%model-destroy (cna-lisp.internal:handle-of model))
          "dispose" :object-type 'model)
      (when first-failure (error first-failure)))))

(defmethod print-object ((model model) stream)
  (print-unreadable-object (model stream :type t :identity t)
    (if (cna-lisp.internal:disposed-state-of model)
        (format stream "disposed")
        (format stream "~d bone~:p, ~d mesh~:[es~;~]"
                (length (%collection-items (slot-value model '%bones)))
                (length (%collection-items (slot-value model '%meshes)))
                (= 1 (length (%collection-items (slot-value model '%meshes))))))))
