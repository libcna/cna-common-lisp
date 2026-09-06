;;;; storage-container.lisp --- Microsoft.Xna.Framework.Storage.StorageContainer.
;;;;
;;;; A named place inside a `STORAGE-DEVICE' where a title keeps its files. It is
;;;; an ordinary NATIVE-OBJECT and a **child of its device**, and the streams it
;;;; opens are children of it -- which is the graph CNA requires:
;;;; "the stream is a child of its container and must be closed before the
;;;; container is destroyed", and "containers opened from the device must be
;;;; destroyed first".
;;;;
;;;; So the ownership graph this closure adds is
;;;;
;;;;     StorageDevice -> StorageContainer -> StorageStream
;;;;
;;;; and it is three deep, which no previous closure has been. The existing
;;;; ownership layer handles it unchanged, **including its refusal to cascade**:
;;;; each level registers with its parent, and disposing a parent that still owns
;;;; a live child is a `CNA-OWNERSHIP-ERROR' rather than a quiet recursive close.
;;;; A program closes its streams, then its containers, then its device.
;;;;
;;;; That is deliberate on both sides. CNA's `cna_storage_container_destroy' says
;;;; "streams opened from the container must be closed first" and refuses the
;;;; other order, so a cascade would be this binding choosing a lifetime for
;;;; objects the program still holds. And the pinned IL is not asking for one:
;;;; `StorageContainer.Dispose(bool)' sets `_isDisposed', calls an **empty**
;;;; `DisposeOverride', and raises `Disposing'. It closes nothing -- XNA's
;;;; `OpenFile' answers a `FileStream' the caller owns outright. The one place
;;;; the two differ is that XNA would let a container be disposed with a stream
;;;; still open and CNA will not; `docs/limitations.md' records that.
;;;;
;;;; **Not sealed in XNA**, unusually, and left open here for the same reason
;;;; `VisualizationData' is.

(in-package #:microsoft.xna.framework.storage)

(defclass storage-container (cna-lisp.internal:native-object)
  ((event-handlers :initform '()
                   :accessor microsoft.xna.framework::%event-handlers))
  (:documentation
   "Microsoft.Xna.Framework.Storage.StorageContainer: a title's files on a device.

    (let ((container (end-open-container
                      device (begin-open-container device \"SaveGames\" nil nil))))
      (unwind-protect
           (with-open-stream (s (create-file container \"slot1.dat\"))
             (write-sequence bytes s))
        (xna:dispose container)))

**You do not make one.** XNA's constructor is `assembly'-private; a container
comes from `BEGIN-OPEN-CONTAINER' and `END-OPEN-CONTAINER', which is the pair
projected here rather than collapsed -- see `src/storage/storage-device.lisp' for
why the pair is kept.

It is a child of its device and the parent of every stream it opens, so disposing
it closes those streams first and a device refuses to go while a container is
still open. That is CNA's stated requirement and this binding's ordinary
ownership graph, not a special case.

Its `Disposing' event is an ordinary instance event and goes through the same
machinery every other one does."))

(defun %adopt-storage-container (device handle)
  "Build the container over a handle CNA has already given us."
  (let ((container (make-instance 'storage-container
                                  :handle handle
                                  :ownership :owned
                                  :owner device
                                  :owner-thread
                                  (cna-lisp.internal:owner-thread-of device))))
    (cna-lisp.internal:register-child device container)
    container))

(defmethod cna-lisp.internal:destroy-native ((container storage-container))
  "Mark it disposed, dispose the native container, then release the handle.

Three steps in that order, and the order is the pinned IL's rather than this
binding's habit. `StorageContainer.Dispose(bool)' reads

    _isDisposed = true
    DisposeOverride(disposing)      // empty
    Disposing(this, EventArgs.Empty)

so **a handler runs on a container that already reports IsDisposed**, and every
member it calls raises `ObjectDisposedException' from `VerifyNotDisposed'. Here
`cna_storage_container_dispose' is what raises `Disposing', and the ownership
layer would otherwise not set the disposed state until the whole destruction has
returned -- which would have handlers seeing a live container, one step out of
order. Setting it first costs nothing: `DISPOSE' marks the object disposed on the
way out of this method whether it succeeds or fails, so no failure is hidden by
setting it early.

Then the split `Song' has: `cna_storage_container_dispose' is the canonical
disposal, `cna_storage_container_destroy' releases the handle, and the event
reaches its handlers before the handle goes -- XNA's order there too."
  (let ((handle (cna-lisp.internal:handle-of container)))
    (setf (cna-lisp.internal:disposed-state-of container) t)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%storage-container-dispose handle)
     "dispose" :object-type 'storage-container)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%storage-container-destroy handle)
     "dispose" :object-type 'storage-container)))

;;; --- the read-only properties -----------------------------------------------

(defgeneric display-name (container)
  (:documentation
   "StorageContainer.DisplayName: the name the container was opened with."))

(defgeneric is-disposed (object)
  (:documentation
   "Whether OBJECT has been disposed.

Answers this binding's own disposed state rather than
`cna_storage_container_get_is_disposed', for the reason `Song.IsDisposed' does:
the managed state is the one every other member's refusal is decided by, and a
getter that asked CNA could disagree with the refusal standing beside it."))

(defmethod display-name ((container storage-container))
  (let ((operation "display-name"))
    (cna-lisp.internal:check-usable container operation)
    (let ((handle (cna-lisp.internal:handle-of container)))
      (cna-lisp.internal:count-then-copy-string
       (lambda (out)
         (cna-lisp.internal.ffi::%storage-container-get-display-name-size handle out))
       (lambda (buffer capacity out)
         (cna-lisp.internal.ffi::%storage-container-copy-display-name
          handle buffer capacity out))
       operation))))

(defmethod is-disposed ((container storage-container))
  (cna-lisp.internal:disposed-state-of container))

(defgeneric storage-device (container)
  (:documentation
   "StorageContainer.StorageDevice: the device this container was opened on.

**The same symbol names the class and this reader**, which Common Lisp allows and
which is what the naming rule produces: a reference type's member is the bare
member name, and the member is called `StorageDevice'. `(storage-device c)' is
the reader; `'storage-device' is the class.

It answers the ownership layer's own parent rather than asking CNA, because that
is the same fact: the container is a child of the device in this binding's graph
and in CNA's, whose route says containers must be destroyed first."))

(defmethod storage-device ((container storage-container))
  (cna-lisp.internal:check-usable container "storage-device")
  (cna-lisp.internal:owner-of container))

(defmethod xna:clr-type-name ((container storage-container))
  (cna-lisp.internal:check-usable container "clr-type-name")
  (let ((handle (cna-lisp.internal:handle-of container)))
    (cna-lisp.internal:count-then-copy-string
     (lambda (out)
       (cna-lisp.internal.ffi::%storage-container-get-type-name-size handle out))
     (lambda (buffer capacity out)
       (cna-lisp.internal.ffi::%storage-container-copy-type-name
        handle buffer capacity out))
     "clr-type-name")))

;;; --- directories and files --------------------------------------------------

(defmacro %define-container-path-operation (name route documentation &key answers-boolean)
  "Define one container member that takes a path and calls one CNA route."
  `(progn
     (defgeneric ,name (container path) (:documentation ,documentation))
     (defmethod ,name ((container storage-container) path)
       (let ((operation ,(string-downcase (symbol-name name))))
         (cna-lisp.internal:check-usable container operation)
         (unless (stringp path)
           (error 'xna:cna-argument-error
                  :operation operation :parameter-name "path"
                  :object-type 'storage-container
                  :format-control "a path is a string; ~s is not one."
                  :format-arguments (list path)))
         (let ((handle (cna-lisp.internal:handle-of container)))
           (cna-lisp.internal:with-utf8-view (data length path)
             ,(if answers-boolean
                  `(cffi:with-foreign-object (out :uint8)
                     (cna-lisp.internal:check-result
                      (,route handle data length out)
                      operation :object-type 'storage-container)
                     (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref out :uint8)))
                  `(progn
                     (cna-lisp.internal:check-result
                      (,route handle data length)
                      operation :object-type 'storage-container)
                     (values)))))))))

(%define-container-path-operation directory-exists
    cna-lisp.internal.ffi::%storage-container-directory-exists
  "StorageContainer.DirectoryExists: whether a directory is there."
  :answers-boolean t)

(%define-container-path-operation file-exists
    cna-lisp.internal.ffi::%storage-container-file-exists
  "StorageContainer.FileExists: whether a file is there."
  :answers-boolean t)

(%define-container-path-operation create-directory
    cna-lisp.internal.ffi::%storage-container-create-directory
  "StorageContainer.CreateDirectory: make a directory inside the container.")

(%define-container-path-operation delete-directory
    cna-lisp.internal.ffi::%storage-container-delete-directory
  "StorageContainer.DeleteDirectory: remove a directory from the container.")

(%define-container-path-operation delete-file
    cna-lisp.internal.ffi::%storage-container-delete-file
  "StorageContainer.DeleteFile: remove a file from the container.")

(defgeneric create-file (container file)
  (:documentation
   "StorageContainer.CreateFile: make a file and open it, answering a stream.

    (with-open-stream (s (create-file container \"slot1.dat\"))
      (write-sequence bytes s))

**The stream is an ordinary Common Lisp stream**, which is what
`System.IO.Stream' projects onto throughout this binding -- see
`src/storage/storage-stream.lisp'. It is an owned child of CONTAINER and must be
closed before the container is disposed: `CLOSE' does that, and disposing the
container does **not** -- it refuses while a stream is still open, because
ownership here does not cascade."))

(defgeneric open-file (container file &key mode access share)
  (:documentation
   "StorageContainer.OpenFile: open a file, answering a stream.

Three overloads, told apart by their **complete keyword sets**:

    (open-file c \"f\" :mode :open)                          OpenFile(String, FileMode)
    (open-file c \"f\" :mode :open :access :read)            + FileAccess
    (open-file c \"f\" :mode :open :access :read :share :read)   + FileShare

`:MODE' is required in all three, because every XNA overload takes one. `:ACCESS'
alone without `:MODE', or `:SHARE' without `:ACCESS', name no overload and are
refused rather than defaulted -- the rule `%CHECK-OVERLOAD-KEYWORDS' enforces
everywhere in this binding.

`:SHARE' takes a `FILE-SHARE' member or a **list** of them, because
`System.IO.FileShare' carries `[Flags]' and CNA's route documents its parameter
as zero or more bits. `(:read :delete)' is a call the original can express and is
accepted here.

**The sharing has no effect on any admitted ABI.** CNA says so itself: the
canonical implementation currently ignores the file_share parameter, so that
route differs from `cna_storage_container_open_file_access' only in which
selection the caller states explicitly. The third overload is real, reachable
and accepted; what it states is not enforced. `docs/limitations.md' records it. Nothing here pretends
otherwise, and nothing here refuses the overload for it: a program that would
have written `FileShare.None' in XNA still writes it, and gets the same stream
XNA would have given it on a platform with no mandatory locking.

The stream is an ordinary Common Lisp stream and an owned child of CONTAINER; see
`CREATE-FILE'."))

(defmethod create-file ((container storage-container) file)
  (let ((operation "create-file"))
    (cna-lisp.internal:check-usable container operation)
    (check-type file string)
    (let ((handle (cna-lisp.internal:handle-of container)))
      (cna-lisp.internal:with-utf8-view (data length file)
        (cffi:with-foreign-object (out :uint64)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%storage-container-create-file
            handle data length out)
           operation :object-type 'storage-container)
          (%adopt-storage-stream container (cffi:mem-ref out :uint64) operation))))))

(defparameter *open-file-overloads*
  '((:mode "mode")
    (:mode-access "mode" "access")
    (:mode-access-share "mode" "access" "share"))
  "XNA's three OpenFile overloads, as the keyword sets that spell them.

    OpenFile(String, FileMode)
    OpenFile(String, FileMode, FileAccess)
    OpenFile(String, FileMode, FileAccess, FileShare)

The file is positional in all three and is therefore in no keyword set. There is
nothing between them: `:SHARE' without `:ACCESS' is a call XNA cannot express.")

(defmethod open-file ((container storage-container) file
                      &rest settings &key mode access share &allow-other-keys)
  (let* ((operation "open-file")
         (shape (xna::%check-overload-keywords
                 operation
                 (loop for (key nil) on settings by #'cddr
                       collect (string-downcase (symbol-name key)))
                 *open-file-overloads* :object-type 'storage-container)))
    (cna-lisp.internal:check-usable container operation)
    (check-type file string)
    (let ((handle (cna-lisp.internal:handle-of container)))
      (cna-lisp.internal:with-utf8-view (data length file)
        (cffi:with-foreign-object (out :uint64)
          (cna-lisp.internal:check-result
           (ecase shape
             (:mode (cna-lisp.internal.ffi::%storage-container-open-file
                     handle data length (file-mode-value mode) out))
             (:mode-access (cna-lisp.internal.ffi::%storage-container-open-file-access
                            handle data length (file-mode-value mode)
                            (file-access-value access) out))
             (:mode-access-share
              (cna-lisp.internal.ffi::%storage-container-open-file-share
               handle data length (file-mode-value mode)
               (file-access-value access) (file-share-value share) out)))
           operation :object-type 'storage-container)
          (%adopt-storage-stream container (cffi:mem-ref out :uint64) operation))))))

;;; --- listing ----------------------------------------------------------------

(defun %copy-indexed-name (copy operation)
  "Read one name through the two-call idiom the *listing* routes use.

**Not `COUNT-THEN-COPY-STRING', and the difference is the routes'.** Every other
string in this ABI has a matching `get_..._size' route that answers the byte
count and succeeds; the two listing routes have no per-name size route -- their
`get_..._count' answers how many *names* there are, not how long one is -- so the
size is learned by calling the copy route with a capacity of zero.

That call answers `CNA_RESULT_BUFFER_TOO_SMALL` and **still fills `out_bytes`**,
which the header promises in as many words: the parameter \"receives the required
byte count\" and the failure is documented as coming \"with no partial write\". So
the too-small result is the expected answer of the sizing call and is not an
error here; any *other* failure still is."
  (cffi:with-foreign-object (needed :uint64)
    (let ((probe (funcall copy (cffi:null-pointer) 0 needed)))
      (unless (or (= probe cna-lisp.internal.ffi::+result-success+)
                  (= probe cna-lisp.internal.ffi::+result-buffer-too-small+))
        (cna-lisp.internal:check-result probe operation
                                        :object-type 'storage-container)))
    (let ((n (cffi:mem-ref needed :uint64)))
      (if (zerop n)
          ""
          (cffi:with-foreign-object (buffer :uint8 n)
            (cffi:with-foreign-object (written :uint64)
              (cna-lisp.internal:check-result (funcall copy buffer n written)
                                              operation :object-type 'storage-container)
              (let ((count (cffi:mem-ref written :uint64)))
                (cna-lisp.internal:utf8-octets-to-string
                 (let ((v (make-array count :element-type '(unsigned-byte 8))))
                   (dotimes (i count v)
                     (setf (aref v i) (cffi:mem-aref buffer :uint8 i))))))))))))

(defmacro %define-container-listing (name count-route copy-route documentation)
  "Define one of the two listing members, both of whose overloads take a pattern.

XNA has two overloads each -- with and without a search pattern -- and CNA has
one route that takes the pattern. The no-pattern overload is `\"*\"', which is
what XNA's own no-argument body passes, so the two collapse onto an optional."
  `(progn
     (defgeneric ,name (container &optional search-pattern)
       (:documentation ,documentation))
     (defmethod ,name ((container storage-container) &optional (search-pattern "*"))
       (let ((operation ,(string-downcase (symbol-name name))))
         (cna-lisp.internal:check-usable container operation)
         (check-type search-pattern string)
         (let ((handle (cna-lisp.internal:handle-of container)))
           (cna-lisp.internal:with-utf8-view (pattern-data pattern-length search-pattern)
             (cffi:with-foreign-object (out :uint64)
               (cna-lisp.internal:check-result
                (,count-route handle pattern-data pattern-length out)
                operation :object-type 'storage-container)
               (let* ((count (cffi:mem-ref out :uint64))
                      (result (make-array count)))
                 (dotimes (i count result)
                   (setf (aref result i)
                         (%copy-indexed-name
                          (lambda (buffer capacity bytes)
                            (,copy-route handle pattern-data pattern-length i
                                         buffer capacity bytes))
                          operation)))))))))))

(%define-container-listing get-directory-names
    cna-lisp.internal.ffi::%storage-container-get-directory-name-count
    cna-lisp.internal.ffi::%storage-container-copy-directory-name
  "StorageContainer.GetDirectoryNames: every directory name, as a fresh vector.

Two overloads collapsed onto an optional: XNA's no-argument body passes `\"*\"',
so the pattern defaults to that and neither overload is lost.

`System.String[]' projects onto a **vector** rather than a list, because that is
what a CLR array is -- indexable and of known length -- and the two listing
members are the only places in this binding that answer one.")

(%define-container-listing get-file-names
    cna-lisp.internal.ffi::%storage-container-get-file-name-count
    cna-lisp.internal.ffi::%storage-container-copy-file-name
  "StorageContainer.GetFileNames: every file name, as a fresh vector.

See `GET-DIRECTORY-NAMES'.")

;;; --- the Disposing event ----------------------------------------------------

(xna::%define-event-pair add-disposing-handler remove-disposing-handler
  "StorageContainer.Disposing's `+=': call HANDLER when the container is disposed.

    (add-disposing-handler container (lambda (container) (forget-it container)))

HANDLER takes the sender and nothing else, because XNA passes `EventArgs.Empty'.

An ordinary instance event, through the machinery every other one here uses. It
is raised by `cna_storage_container_dispose', which is the first half of this
type's disposal -- so a handler runs while the handle is still live, which is
XNA's order too.")

(defparameter *storage-container-event-values*
  (list (cons :disposing 0))
  "The one event a StorageContainer raises. The value is unused, for the reason
`DynamicSoundEffectInstance''s is: CNA names the event by route.")

(defmethod xna::%event-table ((container storage-container))
  *storage-container-event-values*)

(defmethod xna::%subscribe-natively ((container storage-container)
                                     value token registration)
  (declare (ignore value))
  (cna-lisp.internal.ffi::%storage-container-subscribe-disposing
   (cna-lisp.internal:handle-of container)
   (cna-lisp.internal.ffi:storage-event-callback-pointer)
   (cffi:make-pointer token)
   registration))

(defmethod xna::%unsubscribe-natively ((container storage-container) registration)
  "Storage registrations are released by storage's own routes."
  (cna-lisp.internal.ffi::%storage-container-unsubscribe-disposing registration))

(xna::%define-event-methods storage-container :disposing
                            add-disposing-handler remove-disposing-handler)

(defmethod cna-lisp.internal:destroy-native :around ((container storage-container))
  "Release the container's event subscriptions after its native destruction.

**After, not before**, and the reason is the same one `GRAPHICS-RESOURCE' has:
`Disposing' is raised *inside* the destruction -- by
`cna_storage_container_dispose', the first of the two routes below -- so a
subscription released first would swallow the last thing the container ever says.

Without this the rooted callback token outlives the object it belonged to, and
the leak is not theoretical: it is what `TWENTY-GRAPHICS-CYCLES-LEAVE-NOTHING-BEHIND'
and the rest of `tests/native/stress.lisp' exist to catch, and it is what they
caught here."
  (unwind-protect (call-next-method)
    (xna::%release-event-handlers container)))

(defmethod print-object ((container storage-container) stream)
  (print-unreadable-object (container stream :type t)
    (if (cna-lisp.internal:disposed-state-of container)
        (format stream "disposed")
        (format stream "~s" (display-name container)))))
