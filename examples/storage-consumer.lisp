;;;; storage-consumer.lisp --- save and load a game, using only CNA-Lisp's public API.
;;;;
;;;; **What this is for.** The storage tests reach the internal package once, for
;;;; a native cross-check that is the point of that test: whether CNA's
;;;; `cna_storage_container_get_storage_device' names the same handle the
;;;; ownership graph does. That is legitimate for a test and is not available to
;;;; a program. This file is the independent evidence that none of it is
;;;; *needed*: it does a complete save-and-load session -- name the application,
;;;; find out where the saves go, select a device, open a container, write a save
;;;; file, list what is there, read it back, delete it, and close all three
;;;; levels in order -- through nothing but the two exported packages, and prints
;;;; machine-readable lines a script can check.
;;;;
;;;; **It makes no game**, and that is the other thing it demonstrates. Every
;;;; other consumer in this repository starts with `(make-instance 'xna:game)',
;;;; because every other surface reaches CNA through one. No storage route takes
;;;; a game, so this program does not make one, and the native library is loaded
;;;; and the ABI checked by the storage calls themselves.
;;;;
;;;; **The audit this file has to pass** is in the script that runs it, and it is
;;;; mechanical: no `CNA-LISP.INTERNAL', no `CFFI', no handle, no result code and
;;;; no private `%'-symbol. If a save-game program needed any of those, the
;;;; projection would be incomplete and this would be how that was found.
;;;;
;;;; **It writes to the filesystem and it cleans up after itself.** The
;;;; application name it sets is its own, so nothing it writes lands in another
;;;; program's directory, and the container it opens is deleted before it exits.

(defpackage #:cna-lisp-storage-consumer
  (:use #:cl)
  (:local-nicknames (#:xna #:microsoft.xna.framework)
                    (#:storage #:microsoft.xna.framework.storage))
  (:export #:main))

(in-package #:cna-lisp-storage-consumer)

(defparameter *application* "CnaLispStorageConsumer"
  "The application name this program runs under, so that its saves are its own.

Set before any storage access, which is what CNA asks for and what
`SET-STORAGE-APPLICATION-NAME' documents.")

(defparameter *container* "SaveGames"
  "The container name, which is what an XNA title would have called it.")

(defparameter *save* "slot1.sav"
  "One save file, written and read back inside this one run.")

(defun report (key control &rest arguments)
  "Print one machine-readable line: `STORAGE-CONSUMER <key> <text>'."
  (format t "~&STORAGE-CONSUMER ~a ~?~%" key control arguments)
  (finish-output))

(defun save-bytes (level score name)
  "A save file's contents, as bytes. Deliberately trivial: what is demonstrated
is the storage API, not a serialisation format."
  (map '(vector (unsigned-byte 8)) #'char-code
       (format nil "level=~d score=~d name=~a" level score name)))

(defun main ()
  "Save a game and load it back, and print what happened. Answers an exit code."
  ;; The name first, before anything touches storage.
  (storage:set-storage-application-name *application*)
  (report "root" "~s" (storage:storage-root))

  (let ((selected nil))
    ;; The Begin/End pair, with a callback -- which XNA invokes before Begin
    ;; returns, and so does this.
    (let* ((result (storage:storage-device-begin-show-selector
                    (lambda (r) (setf selected r))
                    :the-consumers-state))
           (device (storage:storage-device-end-show-selector result)))
      (report "callback" "~a" (if (eq selected result) "before-begin-returned" "no"))
      (report "async-state" "~a" (storage:async-state result))
      (unwind-protect
           (progn
             (report "device" "connected=~a free=~d total=~d"
                     (if (storage:is-connected device) "yes" "no")
                     (storage:free-space device)
                     (storage:total-space device))
             (let ((container (storage:end-open-container
                               device
                               (storage:begin-open-container
                                device *container* nil nil))))
               (unwind-protect
                    (progn
                      (report "container" "~s type=~s"
                              (storage:display-name container)
                              (xna:clr-type-name container))

                      ;; Write the save. WITH-OPEN-STREAM, because it is an
                      ;; ordinary Common Lisp stream.
                      (let ((bytes (save-bytes 7 4200 "Robert")))
                        (with-open-stream (stream (storage:open-file
                                                   container *save*
                                                   :mode :create :access :write))
                          (write-sequence bytes stream))
                        (report "wrote" "~d bytes to ~s" (length bytes) *save*))

                      ;; A subdirectory, because a title with more than one kind
                      ;; of save wants one.
                      (storage:create-directory container "screenshots")
                      (report "directories" "~s"
                              (coerce (storage:get-directory-names container) 'list))
                      (report "files" "~s"
                              (coerce (storage:get-file-names container "*.sav") 'list))

                      ;; Read it back.
                      (with-open-stream (stream (storage:open-file
                                                 container *save*
                                                 :mode :open :access :read))
                        (let* ((length (file-position stream :end))
                               (buffer (make-array length
                                                   :element-type '(unsigned-byte 8))))
                          (file-position stream 0)
                          (let ((end (read-sequence buffer stream)))
                            (report "read" "~s"
                                    (map 'string #'code-char (subseq buffer 0 end))))))

                      ;; A share the original could have asked for. CNA ignores
                      ;; it on every admitted ABI, which OPEN-FILE says; the
                      ;; point here is that the call is expressible.
                      (with-open-stream (stream (storage:open-file
                                                 container *save*
                                                 :mode :open :access :read
                                                 :share '(:read :delete)))
                        (report "shared-open" "~a"
                                (if (input-stream-p stream) "readable" "no")))

                      ;; Tidy up inside the container.
                      (storage:delete-file container *save*)
                      (storage:delete-directory container "screenshots")
                      (report "emptied" "files=~d directories=~d"
                              (length (storage:get-file-names container))
                              (length (storage:get-directory-names container)))
                      (report "done" "the whole session used only the public API")
                      0)
                 ;; Children first: the streams are closed already, so the
                 ;; container may go.
                 (xna:dispose container)
                 (storage:delete-container device *container*)))
             0)
        (xna:dispose device)))))
