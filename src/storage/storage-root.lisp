;;;; storage-root.lisp --- where the saves go, which XNA never had to say.
;;;;
;;;; **Two routes with no XNA counterpart, and the reason they are here.**
;;;;
;;;; On the Xbox and on Windows an XNA title's storage root is decided *for* it:
;;;; the CLR knows the entry assembly, the framework builds a per-title directory
;;;; from it, and `StorageDevice' has no member that names or changes it because
;;;; no member has to. There is nothing in the selection to project.
;;;;
;;;; Off that platform the question does not answer itself. A Common Lisp image
;;;; is not a title: SBCL running a script has no entry assembly, no title id and
;;;; no product name, so CNA cannot derive what XNA derived. It exposes the two
;;;; `_ext' routes instead -- one to set the application name, one to read back
;;;; the root that name produced -- and a binding that hid them would leave every
;;;; program's saves in whatever directory CNA defaulted to, with no way to say
;;;; otherwise and no way to find out where they went.
;;;;
;;;; So these are declared extensions in `src/capabilities.lisp' rather than
;;;; projected members, and they are named so that nobody mistakes them for XNA:
;;;; there is no `StorageDevice.ApplicationName' and never was.
;;;;
;;;; **The name is process-global**, and CNA's contract asks for it "once at
;;;; startup, before any storage access". Setting it later is not an error and
;;;; does not move a container that is already open; `SET-STORAGE-APPLICATION-NAME'
;;;; says so and does not pretend to relocate anything.
;;;;
;;;; --- the measured divergence this file exists to flatten --------------------
;;;;
;;;; A name CNA cannot build a directory from -- an absolute path, or one that
;;;; climbs out with `..' -- is refused. **Where it is refused is not the same in
;;;; the three admitted ABIs**, measured on 2026-09-06 with the name
;;;; `"/proc/nope"':
;;;;
;;;;   0.21.0   `cna_storage_set_app_name_ext' answers CNA_RESULT_SUCCESS. The
;;;;            first `cna_storage_get_root_size_ext' afterwards answers
;;;;            CNA_RESULT_INVALID_STATE, "Unable to create the storage
;;;;            directory." The refusal arrives at the *reader*.
;;;;   0.22.0   `cna_storage_set_app_name_ext' answers CNA_RESULT_INVALID_STATE
;;;;   0.23.0   with that message. The refusal arrives at the *setter* -- and
;;;;            **not atomically**: the root that was working does not survive
;;;;            it. `cna_storage_get_root_size_ext' then answers SUCCESS with a
;;;;            size of zero, so the root reads as `""', a device selected
;;;;            afterwards answers `IsConnected' false, and every container open
;;;;            is refused with "The storage container name must resolve within
;;;;            the storage root". Both shapes recover on the next accepted set.
;;;;
;;;; Neither is what a caller can build on: on one ABI the setter lies and on two
;;;; it breaks the process on its way out. So `SET-STORAGE-APPLICATION-NAME' does
;;;; not pass either through. It **reads the root back** after the route accepts,
;;;; which is a measurement rather than a guess about how CNA builds a path, and
;;;; it **restores the last accepted name** when either half refuses. All three
;;;; ABIs then behave the same way: an unusable name is refused by the setter,
;;;; and the process's storage root is what it was before the call.

(in-package #:microsoft.xna.framework.storage)

(defvar *storage-application-name* nil
  "The last application name CNA accepted, or NIL if this process has never set
one and is still on CNA's default.

Private, and it exists for one job: `SET-STORAGE-APPLICATION-NAME' puts it back
when a later name is refused, because on 0.22.0 and 0.23.0 the refusal has
already destroyed the root. There is no CNA route that reads the name back --
only the root it produced -- so it has to be remembered rather than asked for.")

(defun %set-application-name-natively (name)
  "Call the route, and answer the result code without interpreting it."
  (cna-lisp.internal:with-utf8-view (data length name)
    (cna-lisp.internal.ffi::%storage-set-app-name-ext data length)))

(defun %root-natively (operation)
  "Read the root, and answer it -- or NIL when there is not one.

**Two shapes mean the same thing and both become NIL**, which is the second half
of flattening the divergence the file header measures:

    CNA_RESULT_INVALID_STATE from the size route   0.21.0, on the first read
                                                   after an unusable name
    CNA_RESULT_SUCCESS with a size of zero         0.22.0 and 0.23.0, and
                                                   0.21.0 on every read after
                                                   the first

Every *other* failure is a real one and is signalled unchanged: only the
uncreatable-directory result is turned into NIL, and only because the caller
above has something better to say about it."
  (cffi:with-foreign-object (needed :uint64)
    (let ((code (cna-lisp.internal.ffi::%storage-get-root-size-ext needed)))
      (cond
        ((= code cna-lisp.internal.ffi::+result-invalid-state+) nil)
        (t (cna-lisp.internal:check-result code operation
                                           :object-type 'storage-device)
           (if (zerop (cffi:mem-ref needed :uint64))
               nil
               (cna-lisp.internal:count-then-copy-string
                (lambda (out)
                  (cna-lisp.internal.ffi::%storage-get-root-size-ext out))
                (lambda (buffer capacity out)
                  (cna-lisp.internal.ffi::%storage-copy-root-ext buffer capacity out))
                operation)))))))

(defun %refuse-application-name (name operation native-message)
  "Put the last accepted name back, then signal that NAME was refused."
  (let ((restored
          (when *storage-application-name*
            (and (= (%set-application-name-natively *storage-application-name*)
                    cna-lisp.internal.ffi::+result-success+)
                 (%root-natively operation)))))
    (error 'xna:cna-invalid-state-error
           :operation operation :object-type 'storage-device
           :native-message native-message
           :format-control
           "CNA cannot build a storage directory from the application name ~s. ~
            ~:[**The storage root of this process is now empty**, because the ~
            refusing ABI does not restore the one it had and this process had ~
            not set a name before: a device selected now answers IsConnected ~
            false and every container open is refused. Setting any accepted ~
            name repairs it.~;The storage root is unchanged: ~:*~s is still in ~
            effect.~]"
           :format-arguments (list name restored))))

(defun set-storage-application-name (name)
  "Set the application name CNA builds the storage root directory from.

    (set-storage-application-name \"MyGame\")
    (storage-root)  =>  \"/home/me/.local/share/MyGame\"

**Not an XNA member**, and there is no XNA member it stands in for: see the file
header. A declared extension.

NAME is a string and is copied during the call. Call it **once, before any
storage access** -- before the first `STORAGE-DEVICE-END-SHOW-SELECTOR' -- which
is what CNA's contract asks for. Calling it later is not an error and does not
move a container that is already open.

A name CNA cannot build a directory from is **refused here, on every admitted
ABI**, and the storage root is what it was before the call. That costs a read of
the root after the route accepts, and a re-set of the previous name when either
half refuses, because the three ABIs disagree about where the refusal arrives and
two of them break the process on their way out of it. The file header has the
measurements.

The one case that cannot be repaired is a refusal on the **first** call in a
process, on 0.22.0 or 0.23.0: there is no previous name to put back and CNA
offers no way to ask for the default it started with. The condition says so, and
any accepted name repairs it.

Answers no value."
  (let ((operation "set-storage-application-name"))
    (check-type name string)
    (cna-lisp.internal:ensure-abi-admitted)
    (let ((code (%set-application-name-natively name)))
      (if (= code cna-lisp.internal.ffi::+result-success+)
          ;; Accepted -- but 0.21.0 accepts names it cannot build a directory
          ;; from, so ask for the root before believing it.
          (let ((root (%root-natively operation)))
            (if root
                (setf *storage-application-name* name)
                (%refuse-application-name name operation nil)))
          (%refuse-application-name
           name operation
           (cna-lisp.internal:last-native-message))))
    (values)))

(defun storage-root ()
  "Answer the directory CNA puts this application's storage under, as a string.

    (storage-root)  =>  \"/home/me/.local/share/MyGame\"

**Not an XNA member**: see the file header. A declared extension, and the one
question a program on this platform has that an XNA program did not -- where its
saves actually are, so that a test can clean up after itself and a user can find
a save file.

The path is whatever CNA built from the application name; asking does not create
it, and it is not this binding's to interpret. It is read fresh on each call,
because `SET-STORAGE-APPLICATION-NAME' can change it.

It reads the root **CNA** holds rather than one remembered here, so a process
that reached the routes some other way still gets the truth.

It refuses rather than answering the empty string when CNA has no root to name -- which a
process reaches by having its very first application name refused, and nothing
else does. `SET-STORAGE-APPLICATION-NAME' explains that state."
  (let ((operation "storage-root"))
    (cna-lisp.internal:ensure-abi-admitted)
    (or (%root-natively operation)
        (error 'xna:cna-invalid-state-error
               :operation operation :object-type 'storage-device
               :native-message (cna-lisp.internal:last-native-message)
               :format-control
               "CNA has no storage root: it could not create the directory the ~
                current application name asks for. Set an application name it ~
                can build a directory from."))))
