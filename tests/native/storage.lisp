;;;; storage.lisp --- the Storage closure against a real CNA C ABI library.
;;;;
;;;; **The first closure that needs no game at all.** Every other native test
;;;; here reaches CNA through a `GAME': the game loads the library, opens the
;;;; ABI gate and owns the graphics device that the resources hang off. No
;;;; storage route takes a game, so a storage program may never make one -- which
;;;; is why `STORAGE-DEVICE-END-SHOW-SELECTOR', `SET-STORAGE-APPLICATION-NAME'
;;;; and `STORAGE-ROOT' open the gate themselves, and why the tests below make no
;;;; game and assert that they did not have to.
;;;;
;;;; **These tests write to the filesystem, and they say where.** The first thing
;;;; they do is name their own storage root, so nothing lands in the directory an
;;;; unnamed process would get -- and every container they open is deleted again,
;;;; so a run leaves no save data behind. `%WITH-TEST-CONTAINER' is that promise.
;;;;
;;;; **Two branches and both assert**, the rule the audio, capture, playback and
;;;; rasterizer lanes already follow. Storage's branch is not the environment's to
;;;; choose, which makes it stronger rather than weaker:
;;;;
;;;;   a usable application name    a root, a connected device, containers,
;;;;                                files, directories and streams
;;;;   an unusable one              **NO-ROOT**: the setter refuses on every
;;;;                                admitted ABI, the previous root survives, and
;;;;                                -- in a process that never had one --
;;;;                                `STORAGE-ROOT' refuses, `IsConnected' answers
;;;;                                false and every container open is refused
;;;;
;;;; The first-call half of that second branch needs a process whose application
;;;; name has never been accepted, so it lives in `tools/qualification/storage.sh'
;;;; rather than here, for the reason the SDL lanes live in their own processes.
;;;; The recoverable half is asserted below, restore and all.
;;;;
;;;; **No claim here is about durability.** A file written, closed, reopened and
;;;; read back is evidence about the stream protocol and CNA's routes. It is not
;;;; evidence that the bytes survive a power cut, a full disk or a filesystem that
;;;; lies about `fsync', and nothing below implies it.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

;;; --- what the storage lanes prove, kept apart -------------------------------

(defvar *storage-evidence* '()
  "What the storage tests actually proved, newest first: (LEVEL . DESCRIPTION).

  :no-root      an unusable application name was refused on this ABI and the
                root that was working survived the refusal
  :root         a named application produced a storage root, and it was read
                back from CNA rather than from anything remembered here
  :device       a device was selected without a game, and its members answered
  :container    a container opened, listed, and its files and directories
                behaved; CNA's own parent route agreed with the ownership graph
  :stream       bytes made a round trip through the ordinary CL stream protocol
                -- write, close, reopen, read -- and a read-only stream refused
                a write
  :overloads    every overload shape XNA has was accepted and every shape it has
                not was refused, for both `OpenFile' and `BeginShowSelector'
  :ownership    the three-deep graph closed in the order CNA requires, and
                refused the other one: a container with an open stream, and a
                device with a live container, each refused disposal
  :events       the container's Disposing event reached a handler and stopped
                when the handler was removed

Kept apart for the reason the audio and capture kinds are: a container that opens
says nothing about whether a stream round-trips, and a stream that round-trips
says nothing about whether the graph closes in the right order. **None is a claim
about durability**: see the file header.")

(defun note-storage (level description &rest arguments)
  "Record LEVEL once."
  (unless (assoc level *storage-evidence*)
    (push (cons level (apply #'format nil description arguments)) *storage-evidence*)))

(defun storage-proved-p (level)
  (assoc level *storage-evidence*))

;;; --- the sandbox ------------------------------------------------------------

(defparameter *storage-test-application* "CnaLispTests"
  "The application name every storage test runs under.

Fixed rather than per-process, so that a run which dies before its cleanup leaves
a directory the next run can recognise and reuse rather than a growing pile of
them. Nothing outside these tests uses it.")

(defvar *storage-sandbox-ready* nil
  "True once this image has named its storage root, so the naming happens once
however the tests are ordered.")

(defun ensure-storage-sandbox ()
  "Name this image's storage root, and answer it.

The name is set **before any storage access**, which is what CNA asks for, and
before the first test rather than in a fixture, because FiveAM does not promise
an order and any of these tests may be the first to run."
  (unless *storage-sandbox-ready*
    (storage:set-storage-application-name *storage-test-application*)
    (setf *storage-sandbox-ready* t))
  (storage:storage-root))

(defmacro %with-test-device ((device) &body body)
  "Select a device, run BODY, and dispose it."
  `(progn
     (ensure-storage-sandbox)
     (let ((,device (storage:storage-device-end-show-selector
                     (storage:storage-device-begin-show-selector nil nil))))
       (unwind-protect (progn ,@body)
         (xna:dispose ,device)))))

(defmacro %with-test-container ((container name &key (device (gensym "DEVICE")))
                                &body body)
  "Open a container called NAME, run BODY, then dispose it **and delete it**.

The delete is the point: these tests write real files into a real directory, and
a suite that left them there would grow one every run and would make the next
run's `GET-FILE-NAMES' depend on the last one's."
  `(%with-test-device (,device)
     (let ((,container (storage:end-open-container
                        ,device
                        (storage:begin-open-container ,device ,name nil nil))))
       (unwind-protect (progn ,@body)
         (ignore-errors (xna:dispose ,container))
         (ignore-errors (storage:delete-container ,device ,name))))))

(defun %storage-octets (string)
  "STRING as the byte vector a binary stream takes."
  (map '(vector (unsigned-byte 8)) #'char-code string))

(defun %storage-text (octets &optional (end (length octets)))
  "The first END bytes of OCTETS as a string."
  (map 'string #'code-char (subseq octets 0 end)))

;;; --- the root, and the branch that has none --------------------------------

(define-native-test storage-root-is-named-and-read-back
  (let ((root (ensure-storage-sandbox)))
    (is (stringp root) "STORAGE-ROOT answers a string")
    (is (plusp (length root)) "the root is not empty: ~s" root)
    (is (search *storage-test-application* root)
        "the root ~s is built from the application name ~s"
        root *storage-test-application*)
    ;; Read twice: the second read goes to CNA again rather than to anything
    ;; cached here, which is what the docstring promises.
    (is (string= root (storage:storage-root))
        "two reads of the root agree")
    (note-storage :root "the application name ~s produced the root ~s, read ~
                         back from CNA"
                  *storage-test-application* root)))

(define-native-test storage-unusable-application-name-is-refused-and-restores
  ;; The recoverable half of the NO-ROOT branch: this image has already accepted
  ;; a name, so the refusal must put that name back. The unrecoverable half --
  ;; the very first name in a process being refused -- needs a process of its
  ;; own and is in tools/qualification/storage.sh.
  (let ((before (ensure-storage-sandbox)))
    (dolist (bad '("/proc/cna-lisp-cannot-be-created"
                   "../../../proc/cna-lisp-cannot-be-created"))
      (signals xna:cna-invalid-state-error
        (storage:set-storage-application-name bad))
      (is (string= before (storage:storage-root))
          "the root survived a refused application name ~s" bad))
    ;; And the device still works, which is the part that would have been broken
    ;; had the refusal been passed through as CNA leaves it on 0.22.0 and 0.23.0.
    (%with-test-device (device)
      (is (storage:is-connected device)
          "the device is still connected after a refused application name"))
    (note-storage :no-root "an unusable application name was refused and the ~
                            root ~s survived, on this ABI" before)))

(define-native-test storage-application-name-must-be-a-string
  (ensure-storage-sandbox)
  (signals error (storage:set-storage-application-name 42))
  (signals error (storage:set-storage-application-name nil)))

;;; --- the device -------------------------------------------------------------

(define-native-test storage-device-needs-no-game
  ;; Nothing in this test makes a GAME, and the point is that it does not have
  ;; to: the gate is opened by END-SHOW-SELECTOR itself.
  (%with-test-device (device)
    (is (typep device 'storage:storage-device))
    (is (storage:is-connected device) "the selected device is connected")
    (let ((free (storage:free-space device))
          (total (storage:total-space device)))
      (is (integerp free) "FreeSpace is an integer: ~s" free)
      (is (integerp total) "TotalSpace is an integer: ~s" total)
      (is (<= 0 free) "FreeSpace is not negative: ~d" free)
      (is (<= free total) "free ~d <= total ~d" free total))
    (is (search "connected" (princ-to-string device))
        "the printed device says whether it is connected: ~a" device)
    (note-storage :device "a device was selected with no game in the image, and ~
                           IsConnected, FreeSpace and TotalSpace answered")))

(define-native-test storage-device-members-refuse-after-disposal
  (let ((device (progn (ensure-storage-sandbox)
                       (storage:storage-device-end-show-selector
                        (storage:storage-device-begin-show-selector nil nil)))))
    (xna:dispose device)
    (signals xna:cna-disposed-error (storage:is-connected device))
    (signals xna:cna-disposed-error (storage:free-space device))
    (signals xna:cna-disposed-error (storage:total-space device))
    (signals xna:cna-disposed-error
      (storage:delete-container device "anything"))
    (is (search "disposed" (princ-to-string device))
        "a disposed device says so when printed: ~a" device)))

(define-native-test storage-device-double-disposal-is-idempotent
  (let ((device (progn (ensure-storage-sandbox)
                       (storage:storage-device-end-show-selector
                        (storage:storage-device-begin-show-selector nil nil)))))
    (xna:dispose device)
    (finishes (xna:dispose device))))

;;; --- the asynchronous halves -----------------------------------------------

(define-native-test storage-begin-show-selector-calls-back-before-returning
  (ensure-storage-sandbox)
  (let* ((seen nil)
         (calls 0)
         (result (storage:storage-device-begin-show-selector
                  (lambda (r) (incf calls) (setf seen r))
                  :the-state)))
    (is (= 1 calls) "the callback ran exactly once, inside Begin")
    (is (eq seen result) "the callback received the result Begin answered")
    (is (eq :the-state (storage:async-state result))
        "AsyncState answers what was passed in")
    (let ((device (storage:storage-device-end-show-selector result)))
      (unwind-protect
           (is (typep device 'storage:storage-device))
        (xna:dispose device)))))

(define-native-test storage-begin-show-selector-creates-no-handle
  ;; XNA's Begin constructs nothing; the device is the End half's. A Begin that
  ;; is never ended must therefore leak nothing, and the only way to say that
  ;; here is that it needs no disposal and no native call.
  (ensure-storage-sandbox)
  (let ((result (storage:storage-device-begin-show-selector nil nil)))
    (is (not (typep result 'storage:storage-device))
        "Begin does not answer a device")
    (is (null (storage:async-state result))
        "a null state reads back as NIL")
    (finishes (storage:storage-device-end-show-selector result))))

(define-native-test storage-end-show-selector-guards
  (ensure-storage-sandbox)
  ;; A result that is not a Begin's at all.
  (signals xna:cna-argument-error (storage:storage-device-end-show-selector 42))
  (signals xna:cna-argument-error (storage:storage-device-end-show-selector nil))
  ;; A second End on one result.
  (let* ((result (storage:storage-device-begin-show-selector nil nil))
         (device (storage:storage-device-end-show-selector result)))
    (unwind-protect
         (signals xna:cna-invalid-state-error
           (storage:storage-device-end-show-selector result))
      (xna:dispose device)))
  ;; And a container result is not a selector result, even though both are
  ;; opaque async results.
  (%with-test-device (device)
    (let ((container-result (storage:begin-open-container device "X" nil nil)))
      (signals xna:cna-argument-error
        (storage:storage-device-end-show-selector container-result)))))

(define-native-test storage-end-open-container-refuses-another-devices-result
  ;; The third guard, which EndShowSelector has not got: XNA compares the result's
  ;; device to this one by reference.
  ;;
  ;; **And the guards are ordered, which has a consequence worth pinning.** The IL
  ;; is explicit: the not-from-Begin check, then endHasBeenCalled, then
  ;; `endHasBeenCalled = true' at IL_0028 -- and only *then* the ReferenceEquals
  ;; against the device. So a result ended on the wrong device is spent: the right
  ;; device afterwards raises CannotEndTwice, not a container. That is XNA's
  ;; behaviour rather than a nicety, and it is asserted here because the tempting
  ;; "fix" -- checking the device first and leaving the result usable -- would be
  ;; this binding quietly improving on the original.
  (ensure-storage-sandbox)
  (let ((first (storage:storage-device-end-show-selector
                (storage:storage-device-begin-show-selector nil nil)))
        (second (storage:storage-device-end-show-selector
                 (storage:storage-device-begin-show-selector nil nil))))
    (unwind-protect
         (progn
           (let ((result (storage:begin-open-container first "Foreign" nil nil)))
             (signals xna:cna-argument-error
               (storage:end-open-container second result))
             (signals xna:cna-invalid-state-error
               (storage:end-open-container first result)))
           ;; A fresh result on the right device still works, so nothing about the
           ;; device was spoiled -- only that one result was.
           (let ((container (storage:end-open-container
                             first
                             (storage:begin-open-container first "Foreign" nil nil))))
             (unwind-protect (is (typep container 'storage:storage-container))
               (xna:dispose container)
               (storage:delete-container first "Foreign"))))
      (xna:dispose first)
      (xna:dispose second))))

(define-native-test storage-begin-show-selector-overload-shapes
  (ensure-storage-sandbox)
  ;; The four shapes XNA has. Each is ended so that nothing is left half-open.
  (dolist (settings '(()
                      (:player :one)
                      (:size-in-bytes 1024 :directory-count 1)
                      (:player :one :size-in-bytes 1024 :directory-count 1)))
    (let ((device (storage:storage-device-end-show-selector
                   (apply #'storage:storage-device-begin-show-selector
                          nil nil settings))))
      (unwind-protect
           (is (typep device 'storage:storage-device)
               "the shape ~s answered a device" settings)
        (xna:dispose device))))
  ;; And the shapes it has not.
  (dolist (settings '((:size-in-bytes 1024)
                      (:directory-count 1)
                      (:player :one :size-in-bytes 1024)
                      (:player :one :directory-count 1)))
    (signals xna:cna-usage-error
      (apply #'storage:storage-device-begin-show-selector nil nil settings)))
  ;; The IL's own validation, in its order.
  (signals xna:cna-argument-out-of-range-error
    (storage:storage-device-begin-show-selector
     nil nil :size-in-bytes -1 :directory-count 1))
  (signals error
    (storage:storage-device-begin-show-selector
     nil nil :player :not-a-player))
  (note-storage :overloads "BeginShowSelector accepted its four keyword sets and ~
                            refused four that name no overload"))

;;; --- the container ----------------------------------------------------------

(define-native-test storage-container-identity-and-parent
  (%with-test-container (container "Identity" :device device)
    (is (string= "Identity" (storage:display-name container)))
    (is (string= "Microsoft.Xna.Framework.Storage.StorageContainer"
                 (xna:clr-type-name container)))
    (is (not (storage:is-disposed container)))
    ;; The ownership graph's answer...
    (is (eq device (storage:storage-device container))
        "StorageDevice answers the device the container was opened on")
    ;; ...and CNA's own, which is the cross-check this reader exists to avoid
    ;; needing. Reaching the internal package is the point of the assertion.
    (cffi:with-foreign-object (out :uint64)
      (int:check-result
       (ffi::%storage-container-get-storage-device (int:handle-of container) out)
       "cross-check")
      (is (= (cffi:mem-ref out :uint64) (int:handle-of device))
          "CNA's own parent route names the same handle as the ownership graph"))
    (note-storage :container "a container opened, named itself, and CNA's parent ~
                              route agreed with the ownership graph")))

(define-native-test storage-container-files-and-directories
  (%with-test-container (container "Files")
    (is (not (storage:file-exists container "a.dat")))
    (is (not (storage:directory-exists container "sub")))
    (let ((stream (storage:create-file container "a.dat")))
      (write-sequence (%storage-octets "one") stream)
      (close stream))
    (is (storage:file-exists container "a.dat"))
    (storage:create-directory container "sub")
    (is (storage:directory-exists container "sub"))
    ;; The listings, with and without a pattern -- two XNA overloads on one
    ;; optional, and a CLR String[] answered as a vector.
    (let ((files (storage:get-file-names container))
          (dirs (storage:get-directory-names container)))
      (is (vectorp files) "GetFileNames answers a vector: ~s" files)
      (is (vectorp dirs) "GetDirectoryNames answers a vector: ~s" dirs)
      (is (find "a.dat" files :test #'string=) "the file is listed: ~s" files)
      (is (find "sub" dirs :test #'string=) "the directory is listed: ~s" dirs))
    (is (= 1 (length (storage:get-file-names container "*.dat")))
        "the pattern overload filters")
    (is (zerop (length (storage:get-file-names container "*.png")))
        "a pattern that matches nothing answers an empty vector")
    (storage:delete-file container "a.dat")
    (is (not (storage:file-exists container "a.dat")))
    (storage:delete-directory container "sub")
    (is (not (storage:directory-exists container "sub")))))

(define-native-test storage-container-path-operations-refuse-a-non-string
  (%with-test-container (container "Paths")
    (dolist (thunk (list (lambda () (storage:file-exists container 42))
                         (lambda () (storage:directory-exists container 42))
                         (lambda () (storage:create-directory container 42))
                         (lambda () (storage:delete-directory container 42))
                         (lambda () (storage:delete-file container 42))))
      (signals xna:cna-argument-error (funcall thunk)))))

(define-native-test storage-container-members-refuse-after-disposal
  (%with-test-device (device)
    (let ((container (storage:end-open-container
                      device (storage:begin-open-container device "Gone" nil nil))))
      (xna:dispose container)
      (is (storage:is-disposed container) "IsDisposed is true after disposal")
      (signals xna:cna-disposed-error (storage:display-name container))
      (signals xna:cna-disposed-error (storage:file-exists container "a"))
      (signals xna:cna-disposed-error (storage:create-file container "a"))
      (signals xna:cna-disposed-error (storage:get-file-names container))
      (signals xna:cna-disposed-error (storage:storage-device container))
      (is (search "disposed" (princ-to-string container))
          "a disposed container says so when printed: ~a" container)
      (storage:delete-container device "Gone"))))

(define-native-test storage-delete-container-removes-the-directory
  ;; The one place these tests look at the filesystem directly, and the reason is
  ;; that DeleteContainer's whole effect is on it.
  (let ((root (ensure-storage-sandbox)))
    (%with-test-device (device)
      (let ((container (storage:end-open-container
                        device
                        (storage:begin-open-container device "Removed" nil nil))))
        (let ((stream (storage:create-file container "x.dat")))
          (write-sequence (%storage-octets "x") stream)
          (close stream))
        (xna:dispose container))
      (let ((path (merge-pathnames "Removed/" (uiop:ensure-directory-pathname root))))
        (is (uiop:directory-exists-p path)
            "the container is a directory under the root: ~a" path)
        (storage:delete-container device "Removed")
        (is (not (uiop:directory-exists-p path))
            "DeleteContainer removed it: ~a" path)))))

;;; --- the stream -------------------------------------------------------------

(define-native-test storage-stream-round-trips-bytes
  (%with-test-container (container "Stream")
    (let ((written (%storage-octets "hello CNA")))
      (let ((stream (storage:create-file container "round.dat")))
        (is (typep stream 'storage:storage-stream))
        (is (streamp stream) "it is a CL stream")
        (is (open-stream-p stream))
        (is (input-stream-p stream) "CanRead says so")
        (is (output-stream-p stream) "CanWrite says so")
        (is (equal '(unsigned-byte 8) (stream-element-type stream)))
        (write-sequence written stream)
        (force-output stream)
        (is (= (length written) (file-position stream))
            "the position is the byte count after writing")
        (is (= (length written) (file-position stream :end))
            "seeking to the end gives the length")
        (close stream)
        (is (not (open-stream-p stream)) "CLOSE closed it"))
      ;; Reopen it, read it back, and check the end of file.
      (let ((stream (storage:open-file container "round.dat"
                                       :mode :open :access :read)))
        (unwind-protect
             (let ((buffer (make-array 32 :element-type '(unsigned-byte 8))))
               (let ((end (read-sequence buffer stream)))
                 (is (= (length written) end) "a short read reports how short")
                 (is (string= "hello CNA" (%storage-text buffer end))
                     "the bytes came back"))
               (is (zerop (read-sequence buffer stream))
                   "a read at the end of the file answers zero")
               (file-position stream 0)
               (is (= (char-code #\h) (read-byte stream))
                   "READ-BYTE reads one byte from the position that was set")
               (file-position stream (length written))
               (is (eq :eof (read-byte stream nil :eof))
                   "READ-BYTE at the end answers the EOF value it was given")
               (signals error (read-byte stream))
               ;; Opened for reading, so writing is refused -- by CNA's own
               ;; CanWrite rather than by the FileAccess that was asked for.
               (signals xna:cna-invalid-state-error (write-byte 65 stream)))
          (close stream)))
      (note-storage :stream "bytes written through WRITE-SEQUENCE came back ~
                             through READ-SEQUENCE after a close and a reopen, ~
                             and a read-only stream refused a write"))))

(define-native-test storage-stream-works-with-with-open-stream
  ;; The ordinary CL idiom, which is the whole claim of projecting Stream onto a
  ;; Gray stream rather than onto a class of its own.
  (%with-test-container (container "Idiom")
    (with-open-stream (stream (storage:create-file container "idiom.dat"))
      (write-byte 7 stream)
      (write-byte 8 stream))
    (with-open-stream (stream (storage:open-file container "idiom.dat"
                                                 :mode :open :access :read))
      (is (= 7 (read-byte stream)))
      (is (= 8 (read-byte stream)))
      (is (eq :eof (read-byte stream nil :eof))))))

(define-native-test storage-stream-positions
  (%with-test-container (container "Seek")
    (with-open-stream (stream (storage:create-file container "seek.dat"))
      (write-sequence (%storage-octets "0123456789") stream)
      (force-output stream)
      (is (= 10 (file-position stream)))
      (is (= 0 (file-position stream 0)) "seeking to the start answers it")
      (is (= 4 (file-position stream 4)))
      (is (= 4 (file-position stream)) "the seek stuck")
      (is (= 10 (file-position stream :end)))
      (is (= 0 (file-position stream :start))))))

(define-native-test storage-stream-refuses-after-close
  (%with-test-container (container "Closed")
    (let ((stream (storage:create-file container "closed.dat")))
      (close stream)
      (is (not (open-stream-p stream)))
      (signals xna:cna-disposed-error (write-byte 1 stream))
      (signals xna:cna-disposed-error (read-byte stream nil nil))
      (signals xna:cna-disposed-error (file-position stream))
      (finishes (close stream)))))

(define-native-test storage-open-file-overload-shapes
  (%with-test-container (container "Overloads")
    (close (storage:create-file container "o.dat"))
    ;; The three shapes XNA has, the third of them twice: once with a single
    ;; FileShare member and once with a list, because the BCL's enumeration
    ;; carries [Flags] and CNA's route takes bits.
    (dolist (settings '((:mode :open)
                        (:mode :open :access :read)
                        (:mode :open :access :read :share :read)
                        (:mode :open :access :read :share :read-write)
                        (:mode :open :access :read :share (:read :write))
                        (:mode :open :access :read :share (:read :delete))
                        (:mode :open :access :read :share :none)))
      (let ((stream (apply #'storage:open-file container "o.dat" settings)))
        (is (typep stream 'storage:storage-stream)
            "the shape ~s answered a stream" settings)
        (close stream)))
    ;; And every shape it has not: a subset, a superset, and a mixture.
    (dolist (settings '((:access :read)
                        (:share :read)
                        (:mode :open :share :read)
                        (:access :read :share :read)))
      (signals xna:cna-usage-error
        (apply #'storage:open-file container "o.dat" settings)))
    (signals error (storage:open-file container 42 :mode :open))
    (note-storage :overloads "OpenFile accepted its three keyword sets and ~
                              refused four that name no overload")))

(define-native-test storage-file-modes-behave
  (%with-test-container (container "Modes")
    ;; Open something that is not there.
    (signals error (storage:open-file container "missing.dat" :mode :open))
    ;; Create it, then refuse to create it again.
    (with-open-stream (stream (storage:open-file container "m.dat"
                                                 :mode :create-new))
      (write-sequence (%storage-octets "abcd") stream))
    (signals error (storage:open-file container "m.dat" :mode :create-new))
    ;; Truncate it.
    (with-open-stream (stream (storage:open-file container "m.dat"
                                                 :mode :truncate
                                                 :access :write))
      (is (zerop (file-position stream :end)) "Truncate emptied the file"))
    ;; Open-or-create makes one that is not there.
    (with-open-stream (stream (storage:open-file container "n.dat"
                                                 :mode :open-or-create))
      (write-sequence (%storage-octets "xy") stream))
    (is (storage:file-exists container "n.dat"))
    ;; Append starts at the end.
    (with-open-stream (stream (storage:open-file container "n.dat"
                                                 :mode :append
                                                 :access :write))
      (write-sequence (%storage-octets "z") stream))
    (with-open-stream (stream (storage:open-file container "n.dat"
                                                 :mode :open :access :read))
      (let ((buffer (make-array 8 :element-type '(unsigned-byte 8))))
        (is (string= "xyz" (%storage-text buffer (read-sequence buffer stream)))
            "Append wrote past what was there")))))

(define-native-test storage-file-enum-values-agree-with-cna
  ;; The three BCL enumerations are keyword tables here, and their values are
  ;; CNA's constants rather than this binding's guesses.
  (is (= ffi::+file-mode-create-new+ (storage:file-mode-value :create-new)))
  (is (= ffi::+file-mode-create+ (storage:file-mode-value :create)))
  (is (= ffi::+file-mode-open+ (storage:file-mode-value :open)))
  (is (= ffi::+file-mode-open-or-create+ (storage:file-mode-value :open-or-create)))
  (is (= ffi::+file-mode-truncate+ (storage:file-mode-value :truncate)))
  (is (= ffi::+file-mode-append+ (storage:file-mode-value :append)))
  (is (= ffi::+file-access-read+ (storage:file-access-value :read)))
  (is (= ffi::+file-access-write+ (storage:file-access-value :write)))
  (is (= ffi::+file-access-read-write+ (storage:file-access-value :read-write)))
  (is (= ffi::+file-share-none+ (storage:file-share-value :none)))
  (is (= ffi::+file-share-read+ (storage:file-share-value :read)))
  (is (= ffi::+file-share-write+ (storage:file-share-value :write)))
  (is (= ffi::+file-share-read-write+ (storage:file-share-value :read-write)))
  (is (= ffi::+file-share-delete+ (storage:file-share-value :delete)))
  (is (= ffi::+file-share-inheritable+ (storage:file-share-value :inheritable)))
  ;; Round trips for the two that are single identities.
  (dolist (mode (storage:all-file-mode))
    (is (eq mode (storage:file-mode-from-value (storage:file-mode-value mode)))))
  (dolist (access (storage:all-file-access))
    (is (eq access (storage:file-access-from-value
                    (storage:file-access-value access)))))
  ;; FileShare is a flags enumeration, so a list combines and a value decodes to
  ;; every member whose bits are all present -- composites included, which is
  ;; what makes 3 answer three names.
  (is (= 3 (storage:file-share-value '(:read :write))))
  (is (= 3 (storage:file-share-value :read-write)))
  (is (= 5 (storage:file-share-value '(:read :delete))))
  (is (= 0 (storage:file-share-value :none)))
  ;; Zero or more bits includes zero, and NIL is the empty list -- so `:share nil'
  ;; is FileShare.None and not a missing argument. Asserted because that is the
  ;; reading a caller could be surprised by.
  (is (= 0 (storage:file-share-value '())))
  (is (= 0 (storage:file-share-value nil)))
  (is (equal '(:none) (storage:file-share-from-value 0)))
  (is (equal '(:read :write :read-write) (storage:file-share-from-value 3)))
  (is (equal '(:read :delete) (storage:file-share-from-value 5)))
  (dolist (share (storage:all-file-share))
    (is (member share (storage:file-share-from-value
                       (storage:file-share-value share)))
        "~s survives a round trip through its own value" share))
  (signals error (storage:file-mode-value :not-a-mode))
  (signals error (storage:file-access-value :not-an-access))
  (signals error (storage:file-share-value :not-a-share))
  (signals error (storage:file-share-value '(:read :not-a-share))))

;;; --- the ownership graph, three deep ---------------------------------------

(define-native-test storage-ownership-does-not-cascade
  ;; StorageDevice -> StorageContainer -> StorageStream, a level deeper than
  ;; anything else in this binding, and the rule at every level is the same one
  ;; the rest of the binding follows: **children first, and no cascade**.
  ;;
  ;; Both sides ask for it. CNA's `cna_storage_container_destroy' says "streams
  ;; opened from the container must be closed first" and refuses the other order.
  ;; And the pinned IL is not asking for a cascade either: StorageContainer's
  ;; Dispose(bool) sets _isDisposed, calls an empty DisposeOverride and raises
  ;; Disposing -- it closes nothing, because XNA's OpenFile answers a FileStream
  ;; the caller owns outright.
  (ensure-storage-sandbox)
  (let* ((device (storage:storage-device-end-show-selector
                  (storage:storage-device-begin-show-selector nil nil)))
         (container (storage:end-open-container
                     device
                     (storage:begin-open-container device "Owned" nil nil)))
         (stream (storage:create-file container "owned.dat")))
    (unwind-protect
         (progn
           ;; A container with a live stream refuses.
           (signals xna:cna-ownership-error (xna:dispose container))
           (is (open-stream-p stream) "the refusal left the stream open")
           (is (not (storage:is-disposed container))
               "the refusal left the container usable")
           (is (storage:file-exists container "owned.dat")
               "and it still answers its members")
           ;; A device with a live container refuses too.
           (signals xna:cna-ownership-error (xna:dispose device))
           (is (storage:is-connected device) "the refusal left the device usable")
           ;; Children first, and every level closes.
           (close stream)
           (is (not (open-stream-p stream)))
           (xna:dispose container)
           (is (storage:is-disposed container))
           (storage:delete-container device "Owned")
           (xna:dispose device)
           (signals xna:cna-disposed-error (storage:is-connected device))
           (note-storage :ownership "a container with an open stream and a device ~
                                     with a live container each refused disposal, ~
                                     and closing children first closed all three"))
      (ignore-errors (close stream))
      (ignore-errors (xna:dispose container))
      (ignore-errors (storage:delete-container device "Owned"))
      (ignore-errors (xna:dispose device)))))

(define-native-test storage-ownership-error-names-what-is-still-live
  ;; The refusal is a diagnostic, not just a failure: it says how many children
  ;; are live and what they are, because "dispose them first" is only actionable
  ;; if the program can tell which.
  (%with-test-device (device)
    (let* ((container (storage:end-open-container
                       device
                       (storage:begin-open-container device "Children" nil nil)))
           (one (storage:create-file container "one.dat"))
           (two (storage:create-file container "two.dat")))
      (handler-case (progn (xna:dispose container) (fail "disposal was accepted"))
        (xna:cna-ownership-error (condition)
          (let ((text (princ-to-string condition)))
            (is (search "2 live native children" text)
                "the refusal counts them: ~a" text)
            (is (search "storage-stream" text)
                "the refusal names their type: ~a" text))))
      (close one)
      (close two)
      (xna:dispose container)
      (storage:delete-container device "Children"))))

;;; --- the events -------------------------------------------------------------

(define-native-test storage-container-disposing-event
  (%with-test-device (device)
    (let* ((calls 0)
           (senders '())
           (handler (lambda (sender) (incf calls) (push sender senders)))
           (container (storage:end-open-container
                       device
                       (storage:begin-open-container device "Event" nil nil))))
      (storage:add-disposing-handler container handler)
      (is (zerop calls) "nothing fired on subscription")
      (xna:dispose container)
      (is (= 1 calls) "Disposing reached the handler exactly once")
      (is (eq container (first senders))
          "the handler received the container as the sender")
      (storage:delete-container device "Event"))
    ;; The IL's order: Dispose(bool) sets _isDisposed, calls DisposeOverride, and
    ;; only then raises Disposing -- so a handler sees a container that already
    ;; says it is disposed. This asserts the same order here rather than assuming
    ;; that CNA's dispose route happens to raise at the same point.
    (let* ((seen :never-ran)
           (handler (lambda (sender) (setf seen (storage:is-disposed sender))))
           (container (storage:end-open-container
                       device
                       (storage:begin-open-container device "Order" nil nil))))
      (storage:add-disposing-handler container handler)
      (xna:dispose container)
      (is (eq t seen)
          "the container already reported IsDisposed when its handler ran, ~
           which is the IL's order; this run saw ~s" seen)
      (storage:delete-container device "Order"))
    ;; And a removed handler stops.
    (let* ((calls 0)
           (handler (lambda (sender) (declare (ignore sender)) (incf calls)))
           (container (storage:end-open-container
                       device
                       (storage:begin-open-container device "Event2" nil nil))))
      (storage:add-disposing-handler container handler)
      (storage:remove-disposing-handler container handler)
      (xna:dispose container)
      (is (zerop calls) "a removed handler did not run")
      (storage:delete-container device "Event2"))
    (note-storage :events "the container's Disposing event reached a handler ~
                           taking the sender alone, and stopped when the handler ~
                           was removed")))

(define-native-test storage-subscriptions-do-not-outlive-their-container
  ;; A regression, and it was a real one: the container had no :AROUND on
  ;; DESTROY-NATIVE releasing its event subscriptions, so every subscribed
  ;; container left a rooted callback token behind after it was disposed. The
  ;; stress lanes caught it -- "graphics cycle 0 left 2 registry entries" --
  ;; which is a long way from where it was caused, so it is asserted here too.
  (%with-test-device (device)
    (let ((before (int:callback-registry-count)))
      (dotimes (i 3)
        (let ((container (storage:end-open-container
                          device
                          (storage:begin-open-container
                           device (format nil "Leak~d" i) nil nil))))
          (storage:add-disposing-handler container (lambda (sender)
                                                     (declare (ignore sender))))
          (xna:dispose container)
          (storage:delete-container device (format nil "Leak~d" i))))
      (is (= before (int:callback-registry-count))
          "three subscribed containers came and went and left the callback ~
           registry where they found it: ~d before, ~d after"
          before (int:callback-registry-count)))))

(define-native-test storage-device-changed-event-subscribes-and-unsubscribes
  ;; A static event, on the private singleton the MediaPlayer closure introduced.
  ;; **Nothing here raises it**: a device that comes and goes is the operating
  ;; system's business and no CNA route asks for one. What is asserted is that
  ;; subscribing and unsubscribing are accepted and that neither fires a handler
  ;; by itself, which is the whole of what a run without a hot-plugged device can
  ;; say.
  (ensure-storage-sandbox)
  (let* ((calls 0)
         (handler (lambda () (incf calls))))
    (finishes (storage:storage-device-add-device-changed-handler handler))
    (unwind-protect
         (progn
           (%with-test-device (device) (storage:is-connected device))
           (is (zerop calls)
               "selecting a device did not raise DeviceChanged, which XNA ~
                raises for a device arriving or leaving rather than for one ~
                being asked for"))
      (finishes (storage:storage-device-remove-device-changed-handler handler)))
    (finishes (storage:storage-device-remove-device-changed-handler handler))))
