;;;; storage-device.lisp --- Microsoft.Xna.Framework.Storage.StorageDevice.
;;;;
;;;; **This file is where Storage's first design question is answered, and the
;;;; answer is: keep the pair, invent no concurrency.** The full argument is in
;;;; `docs/limitations.md'; the evidence is here, because it is what makes the
;;;; decision obvious rather than a preference.
;;;;
;;;; --- XNA's async is a fiction, and the IL says so in four places -----------
;;;;
;;;; `StorageDeviceAsyncResult' implements `IAsyncResult', and every member of
;;;; that interface is a constant:
;;;;
;;;;   .ctor              `new ManualResetEvent(true)' -- **already signalled**
;;;;   CompletedSynchronously  `ldc.i4.1; ret' -- a literal true
;;;;   IsCompleted        `mre.WaitOne(0, false)' on that signalled event, so
;;;;                      **always true**
;;;;   AsyncWaitHandle    the signalled event itself
;;;;
;;;; And the two halves do this:
;;;;
;;;;   BeginShowSelector  validates its arguments, makes the result object, and
;;;;                      **invokes the caller's callback before it returns**
;;;;   EndShowSelector    type-checks, refuses a second call, and **constructs
;;;;                      the device** -- which is the actual work
;;;;
;;;; So a program that calls `Begin' and then `End' has made a synchronous call
;;;; with two names, and there is nothing to wait for at any point. CNA reached
;;;; the same conclusion and says so: its selector routes "collapse the canonical
;;;; `BeginShowSelector'/`EndShowSelector' pair, which CNA completes
;;;; synchronously; no operation handle is invented for work that never pends".
;;;;
;;;; --- so the projection keeps both members and adds nothing ----------------
;;;;
;;;; Both are projected. The callback still fires inside `Begin'. `End' still does
;;;; the work and still refuses a second call. **No promise, no future, no
;;;; thread**: inventing concurrency here would be giving `StorageDevice' a
;;;; capability XNA has not got, which is the one thing this projection may never
;;;; do -- and it would be inventing it for an operation that is already finished
;;;; before the caller can look at it.
;;;;
;;;; The `IAsyncResult' becomes an opaque object of a private class, exactly as
;;;; `System.IO.Stream' becomes a Common Lisp stream: the interface is the base
;;;; class library's and is not a projected type. Its one public reader is
;;;; `ASYNC-STATE', because the state a caller passed to `Begin' is the one thing
;;;; it can observe through the interface and would otherwise have no way back to.
;;;;
;;;; **`Begin' makes no native call, and that is deliberate.** CNA's selector
;;;; route produces the device, so the work could have gone in either half.
;;;; Putting it in `End' matches XNA -- where the device really is constructed
;;;; there -- and means a program that calls `Begin' and never calls `End'
;;;; creates no handle and leaks nothing. The other arrangement would have made
;;;; an owned device nobody asked for.
;;;;
;;;; --- what the four Begin overloads actually validate -----------------------
;;;;
;;;; From the IL, in order, and the two-argument forms delegate to the
;;;; four-argument one with `sizeInBytes' 0 and `directoryCount' 1:
;;;;
;;;;   player != 0xff && (player < 0 || player > 3) -> ArgumentOutOfRangeException
;;;;   sizeInBytes < 0                              -> ArgumentOutOfRangeException
;;;;
;;;; **`directoryCount' is never validated and never read.** It is accepted,
;;;; carried nowhere, and has no effect in the original; CNA takes it and its
;;;; header does not promise anything of it either. So it is accepted here and
;;;; documented as ignored rather than quietly dropped from the signature, which
;;;; would remove an overload.

(in-package #:microsoft.xna.framework.storage)

;;; --- the opaque result ------------------------------------------------------

(defclass %async-result ()
  ((state :initarg :state
          :documentation "The object the caller passed to the Begin half.")
   (end-called :initform nil :accessor %end-called
               :documentation "XNA's `endHasBeenCalled', which makes End once-only.")
   (kind :initarg :kind :reader %async-kind
         :documentation "Which Begin made it: :SELECTOR or :CONTAINER.")
   (device :initarg :device :initform nil :reader %async-device
           :documentation "For :CONTAINER, the device Begin was called on.")
   (payload :initarg :payload :initform nil :reader %async-payload
            :documentation "The arguments End needs: a player and sizes, or a name."))
  (:documentation
   "What the `Begin' half answers and the `End' half consumes.

**`System.IAsyncResult' is the base class library's and is not a projected
type**, the same statement `System.IO.Stream' gets. This is the object that
stands in for it: opaque, with one public reader.

It is already complete when it is made, because XNA's is -- its wait handle is
constructed signalled and `CompletedSynchronously' is a literal `true' -- so
there is nothing here to wait on and nothing to poll."))

(defgeneric async-state (result)
  (:documentation
   "`IAsyncResult.AsyncState': the object the caller passed to the `Begin' half.

The one thing a program can observe through the interface that it did not already
have, so it is the one reader this projection offers. `IsCompleted',
`CompletedSynchronously' and `AsyncWaitHandle' are constants in XNA -- true, true
and an already-signalled handle -- and a reader that answered a constant would be
offering a question with one answer."))

(defmethod async-state ((result %async-result))
  (slot-value result 'state))

(defmethod print-object ((result %async-result) stream)
  (print-unreadable-object (result stream :type t)
    (format stream "~(~a~)~:[~; ended~]" (%async-kind result) (%end-called result))))

(defun %check-async-result (result kind operation)
  "The two guards `EndShowSelector' and `EndOpenContainer' share, in the IL's order.

    result is not one of ours -> ArgumentNullException(\"result\")
    endHasBeenCalled          -> InvalidOperationException(CannotEndTwice)

**A wrong-typed result is the *null* exception in XNA**, not an argument
exception: its `isinst' answers null for both and the same branch throws. So both
are one refusal here."
  (unless (and (typep result '%async-result) (eq (%async-kind result) kind))
    (error 'xna:cna-argument-error
           :operation operation :parameter-name "result"
           :object-type 'storage-device
           :format-control
           "the result must be the one the matching Begin call answered; ~s is ~
            not. XNA's End raises ArgumentNullException for a result of the ~
            wrong type as well as for a missing one, because its type test ~
            answers null for both."
           :format-arguments (list result)))
  (when (%end-called result)
    (error 'xna:cna-invalid-state-error
           :operation operation :object-type 'storage-device
           :format-control
           "this asynchronous result has already been ended. XNA raises ~
            InvalidOperationException here and so does this, because ending ~
            twice would produce a second object for one operation."))
  (setf (%end-called result) t)
  result)

;;; --- the device -------------------------------------------------------------

(defclass storage-device (cna-lisp.internal:native-object)
  ()
  (:documentation
   "Microsoft.Xna.Framework.Storage.StorageDevice: where a title's files live.

    (let ((device (storage-device-end-show-selector
                   (storage-device-begin-show-selector nil nil))))
      (unwind-protect (use device)
        (xna:dispose device)))

**You do not make one.** XNA's constructors are `assembly'-private; a device
comes from `END-SHOW-SELECTOR', which is the half of the pair that does the work.
See this file's header for why the pair is kept rather than collapsed.

It owns every container opened on it, and each container owns every stream it
opens, so disposing a device closes the whole tree in the order CNA requires.

**It needs no game.** None of `storage.h`'s routes takes a game handle -- unlike
audio, capture and media, which all do -- so a storage program can run with no
game at all. That is CNA's shape and not this binding's choice."))

(defun %adopt-storage-device (handle)
  "Build the device over a handle CNA has already given us.

A **rootless** owned object: it has no parent, because no CNA storage route takes
a game and there is nothing else for it to be a child of."
  (make-instance 'storage-device
                 :handle handle
                 :ownership :owned
                 :owner-thread (cna-lisp.internal:current-thread-token)))

(defmethod cna-lisp.internal:destroy-native ((device storage-device))
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%storage-device-destroy
    (cna-lisp.internal:handle-of device))
   "dispose" :object-type 'storage-device))

;;; --- BeginShowSelector and EndShowSelector ---------------------------------

(defconstant +all-players+ 255
  "XNA's `0xff', the player index meaning \"every player\".

`BeginShowSelector' compares against it before its range check, and
`EndShowSelector' compares against it to choose which private constructor to
call. It is not a `PlayerIndex' member -- those are 0 through 3 -- it is the
sentinel the two no-player overloads pass.")

(defparameter *show-selector-overloads*
  '((:plain)
    (:sized "size-in-bytes" "directory-count")
    (:player "player")
    (:player-sized "player" "size-in-bytes" "directory-count"))
  "XNA's four BeginShowSelector overloads, as the keyword sets that spell them.

    BeginShowSelector(AsyncCallback, Object)
    BeginShowSelector(Int32, Int32, AsyncCallback, Object)
    BeginShowSelector(PlayerIndex, AsyncCallback, Object)
    BeginShowSelector(PlayerIndex, Int32, Int32, AsyncCallback, Object)

The callback and the state are positional in all four and are therefore in no
keyword set. `:SIZE-IN-BYTES' without `:DIRECTORY-COUNT' is a shape XNA has not
got, and is refused rather than defaulted.")

(defun storage-device-begin-show-selector (callback state &rest settings
                                           &key player size-in-bytes directory-count
                                           &allow-other-keys)
  "StorageDevice.BeginShowSelector: begin choosing a storage device.

    (storage-device-begin-show-selector nil nil)
    (storage-device-begin-show-selector callback state :player :one)
    (storage-device-begin-show-selector callback state
                                        :size-in-bytes 1024 :directory-count 1)

Four overloads, told apart by their **complete keyword sets**. CALLBACK and STATE
are positional because every overload has them; either may be NIL.

**CALLBACK is invoked before this returns**, which is what XNA does -- its
`Begin' calls `AsyncCallback::Invoke' on the result and only then returns it --
and what CNA does with its own completion callback. It receives the result object,
so a handler that wants the device calls `STORAGE-DEVICE-END-SHOW-SELECTOR' on
what it is given, exactly as an XNA handler would.

**No native call happens here.** The device is created by the `End' half, which is
where XNA creates it too, so a program that begins and never ends creates no
handle.

The validation is the pinned IL's, in its order:

    player outside [0, 3] and not the all-players sentinel
        -> ArgumentOutOfRangeException(\"player\")
    sizeInBytes < 0
        -> ArgumentOutOfRangeException(\"sizeInBytes\")

**`directory-count' is accepted and ignored**, because XNA never validates or
reads it. It stays in the signature because removing it would remove two of the
four overloads."
  (let* ((operation "storage-device-begin-show-selector")
         (shape (xna::%check-overload-keywords
                 operation
                 (loop for (key nil) on settings by #'cddr
                       collect (string-downcase (symbol-name key)))
                 *show-selector-overloads* :object-type 'storage-device))
         (index (if (member shape '(:player :player-sized))
                    (xna:player-index-value player)
                    +all-players+)))
    (when (member shape '(:sized :player-sized))
      (unless (and (integerp size-in-bytes) (<= 0 size-in-bytes))
        (error 'xna:cna-argument-out-of-range-error
               :operation operation :parameter-name "size-in-bytes"
               :object-type 'storage-device
               :format-control
               "sizeInBytes must not be negative; ~s was given."
               :format-arguments (list size-in-bytes)))
      (unless (integerp directory-count)
        (error 'xna:cna-argument-error
               :operation operation :parameter-name "directory-count"
               :object-type 'storage-device
               :format-control
               "directoryCount is an Int32; ~s is not one. XNA never reads it -- ~
                it is accepted and has no effect -- but a non-integer is not a ~
                call the original can express."
               :format-arguments (list directory-count))))
    (let ((result (make-instance '%async-result
                                 :kind :selector :state state
                                 :payload (list index
                                                (if (member shape '(:sized :player-sized))
                                                    size-in-bytes 0)
                                                (if (member shape '(:sized :player-sized))
                                                    directory-count 1)))))
      ;; XNA invokes the callback here, before returning, and so does this.
      (when callback (funcall callback result))
      result)))

(defun storage-device-end-show-selector (result)
  "StorageDevice.EndShowSelector: finish choosing, and answer the device.

**This is the half that does the work**, which is XNA's arrangement: its `End'
constructs the `StorageDevice' and its `Begin' constructs nothing. Here it is the
half that calls CNA's selector route.

Two guards in the IL's order -- a result that is not the matching `Begin''s is
`ArgumentNullException(\"result\")', and a second `End' on one result is
`InvalidOperationException(CannotEndTwice)' -- and then the device.

The device is **owned by the caller**: dispose it when finished, and it closes
every container and stream opened under it."
  (let ((operation "storage-device-end-show-selector"))
    (%check-async-result result :selector operation)
    ;; **The gate every native entry point goes through, and Storage is the first
    ;; surface that has to open it itself.** Everywhere else the first native
    ;; call is reached through a `Game', whose construction loads the library and
    ;; checks the ABI is admitted. No storage route takes a game, so a storage
    ;; program may never make one -- and without this the first route would find
    ;; an unloaded library and fail as an undefined foreign symbol rather than
    ;; with the diagnostic the gate exists to give.
    (cna-lisp.internal:ensure-abi-admitted)
    (destructuring-bind (index size-in-bytes directory-count) (%async-payload result)
      (cffi:with-foreign-object (out :uint64)
        (cna-lisp.internal:check-result
         (cond
           ((and (= index +all-players+) (zerop size-in-bytes))
            (cna-lisp.internal.ffi::%storage-device-show-selector
             (cffi:null-pointer) (cffi:null-pointer) out))
           ((= index +all-players+)
            (cna-lisp.internal.ffi::%storage-device-show-selector-with-space
             size-in-bytes directory-count
             (cffi:null-pointer) (cffi:null-pointer) out))
           ((zerop size-in-bytes)
            (cna-lisp.internal.ffi::%storage-device-show-selector-for-player
             index (cffi:null-pointer) (cffi:null-pointer) out))
           (t
            (cna-lisp.internal.ffi::%storage-device-show-selector-for-player-with-space
             index size-in-bytes directory-count
             (cffi:null-pointer) (cffi:null-pointer) out)))
         operation :object-type 'storage-device)
        (%adopt-storage-device (cffi:mem-ref out :uint64))))))

;;; --- BeginOpenContainer and EndOpenContainer -------------------------------

(defgeneric begin-open-container (device display-name callback state)
  (:documentation
   "StorageDevice.BeginOpenContainer: begin opening a named container.

    (end-open-container device (begin-open-container device \"SaveGames\" nil nil))

The instance counterpart of `STORAGE-DEVICE-BEGIN-SHOW-SELECTOR', with the same
shape and for the same reasons: the callback fires before this returns, no native
call happens here, and `END-OPEN-CONTAINER' does the work."))

(defgeneric end-open-container (device result)
  (:documentation
   "StorageDevice.EndOpenContainer: finish opening, and answer the container.

Three guards, and the third is one `EndShowSelector' has not got:

    result is not the matching Begin's -> ArgumentNullException(\"result\")
    endHasBeenCalled                   -> InvalidOperationException(CannotEndTwice)
    **result came from a different device** -> ArgumentException(IAsyncNotFromBegin)

The last is a real check in the IL -- `ReferenceEquals(this, result.storageDevice)'
and a player-index comparison -- so ending one device's operation on another
device is refused rather than quietly answering a container on the wrong one."))

(defmethod begin-open-container ((device storage-device) display-name callback state)
  (let ((operation "begin-open-container"))
    (cna-lisp.internal:check-usable device operation)
    (check-type display-name string)
    (let ((result (make-instance '%async-result
                                 :kind :container :state state
                                 :device device :payload display-name)))
      (when callback (funcall callback result))
      result)))

(defmethod end-open-container ((device storage-device) result)
  (let ((operation "end-open-container"))
    ;; The shared two guards first, in the IL's order, and only then the third.
    (%check-async-result result :container operation)
    (unless (eq device (%async-device result))
      (error 'xna:cna-argument-error
             :operation operation :parameter-name "result"
             :object-type 'storage-device
             :format-control
             "this result came from a different device's BeginOpenContainer. XNA ~
              compares the two by reference and raises ArgumentException here, ~
              rather than opening a container on the device that was asked."))
    (cna-lisp.internal:check-usable device operation)
    (cna-lisp.internal:with-utf8-view (data length (%async-payload result))
      (cffi:with-foreign-object (out :uint64)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%storage-container-open
          (cna-lisp.internal:handle-of device) data length
          (cffi:null-pointer) (cffi:null-pointer) out)
         operation :object-type 'storage-device)
        (%adopt-storage-container device (cffi:mem-ref out :uint64))))))

;;; --- the ordinary members ---------------------------------------------------

(defgeneric delete-container (device title-name)
  (:documentation
   "StorageDevice.DeleteContainer: remove a container and everything in it."))

(defgeneric free-space (device)
  (:documentation "StorageDevice.FreeSpace: bytes available, as CNA reports them."))

(defgeneric total-space (device)
  (:documentation "StorageDevice.TotalSpace: bytes in total, as CNA reports them."))

(defgeneric is-connected (device)
  (:documentation
   "StorageDevice.IsConnected: whether the device is still there.

The one member of this type whose answer can change under a program, which is why
`StorageDeviceNotConnectedException' exists."))

(defmethod delete-container ((device storage-device) title-name)
  (let ((operation "delete-container"))
    (cna-lisp.internal:check-usable device operation)
    (check-type title-name string)
    (cna-lisp.internal:with-utf8-view (data length title-name)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%storage-device-delete-container
        (cna-lisp.internal:handle-of device) data length)
       operation :object-type 'storage-device))
    (values)))

(macrolet ((space-reader (name route documentation)
             `(defmethod ,name ((device storage-device))
                ,documentation
                (let ((operation ,(string-downcase (symbol-name name))))
                  (cna-lisp.internal:check-usable device operation)
                  (cffi:with-foreign-object (out :int64)
                    (cna-lisp.internal:check-result
                     (,route (cna-lisp.internal:handle-of device) out)
                     operation :object-type 'storage-device)
                    (cffi:mem-ref out :int64))))))
  (space-reader free-space cna-lisp.internal.ffi::%storage-device-get-free-space
    "Bytes available on the device.")
  (space-reader total-space cna-lisp.internal.ffi::%storage-device-get-total-space
    "Bytes the device holds in total."))

(defmethod is-connected ((device storage-device))
  (let ((operation "is-connected"))
    (cna-lisp.internal:check-usable device operation)
    (cffi:with-foreign-object (out :uint8)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%storage-device-get-is-connected
        (cna-lisp.internal:handle-of device) out)
       operation :object-type 'storage-device)
      (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref out :uint8)))))

(defmethod print-object ((device storage-device) stream)
  (print-unreadable-object (device stream :type t)
    (if (cna-lisp.internal:disposed-state-of device)
        (format stream "disposed")
        (format stream "~:[disconnected~;connected~]" (is-connected device)))))

;;; --- the static DeviceChanged event ----------------------------------------
;;;
;;; Static, like `MediaPlayer''s two, and handled the same way: a private
;;; singleton the shared machinery specialises on, and a handler that takes no
;;; arguments because XNA raises it with a null sender.

(defclass %storage-device-events ()
  ((event-handlers :initform '()
                   :accessor microsoft.xna.framework::%event-handlers))
  (:documentation "Private holder for `StorageDevice.DeviceChanged''s handlers."))

(defvar *storage-device-events* nil)

(defun %storage-device-events ()
  (or *storage-device-events*
      (setf *storage-device-events* (make-instance '%storage-device-events))))

(defparameter *storage-device-event-values*
  (list (cons :device-changed 0))
  "The one event StorageDevice raises. Static, so it has no instance.")

(defmethod xna::%event-table ((events %storage-device-events))
  *storage-device-event-values*)

(defmethod xna::%check-event-usable ((events %storage-device-events) operation)
  "Nothing to check: the subscribe route takes no handle of any kind."
  (declare (ignore events operation))
  t)

(defmethod xna::%subscribe-natively ((events %storage-device-events)
                                     value token registration)
  (declare (ignore value))
  (cna-lisp.internal.ffi::%storage-device-subscribe-device-changed
   (cna-lisp.internal.ffi:storage-event-callback-pointer)
   (cffi:make-pointer token) registration))

(defmethod xna::%unsubscribe-natively ((events %storage-device-events) registration)
  (cna-lisp.internal.ffi::%storage-device-unsubscribe-device-changed registration))

(defun %dispatch-storage-event (token)
  "Invoke the handler TOKEN names.

The container's `Disposing' passes its sender; `DeviceChanged' is static and has
none, so the two are told apart by what the registry entry holds -- a sender for
the instance event, NIL for the static one."
  (let ((entry (cna-lisp.internal:callback-target token)))
    (when entry
      (destructuring-bind (sender . function) entry
        (cna-lisp.internal:with-event-dispatch
          (if sender (funcall function sender) (funcall function)))))))

(setf cna-lisp.internal.ffi:*storage-event-dispatcher* #'%dispatch-storage-event)

(defun storage-device-add-device-changed-handler (handler)
  "StorageDevice.DeviceChanged's `+=': call HANDLER when a device is added or removed.

    (storage-device-add-device-changed-handler (lambda () (rescan-devices)))

**HANDLER takes no arguments.** The event is static, so XNA raises it with a null
sender -- the same shape `MediaPlayer''s two events have, and for the same reason.

Needs no game and no device: CNA's subscribe route takes neither."
  (cna-lisp.internal:ensure-abi-admitted)
  (xna::%subscribe-event (%storage-device-events) :device-changed handler))

(defun storage-device-remove-device-changed-handler (handler)
  "The `-=' of `STORAGE-DEVICE-ADD-DEVICE-CHANGED-HANDLER'. Answers true when it
found a handler to remove and NIL when it did not."
  (xna::%unsubscribe-event (%storage-device-events) :device-changed handler))
