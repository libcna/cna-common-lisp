;;;; conditions.lisp --- the one exception Microsoft.Xna.Framework.Storage raises.
;;;;
;;;; Except that, measured rather than assumed, **it raises it nowhere**.
;;;;
;;;; `StorageDeviceNotConnectedException' is XNA's own. Unlike the three in the
;;;; Audio namespace it is not sealed, and it extends
;;;; `System.Runtime.InteropServices.ExternalException' -- the CLR's "a native
;;;; call failed" base, which is what `CNA-NATIVE-ERROR' already is here. So it
;;;; is projected as a condition class under `CNA-NOT-SUPPORTED-ERROR', left open
;;;; to subclassing, with the three constructors that are ways to make one.
;;;;
;;;; What is *not* projected is a route that signals it, and that is a finding
;;;; rather than an omission. Two measurements:
;;;;
;;;;   the pinned IL   `Microsoft.Xna.Framework.Storage.dll' names the type six
;;;;                   times -- the class, its four constructors, and its
;;;;                   `[Serializable]' attribute -- and constructs it **zero**
;;;;                   times. No `newobj' of it appears in that assembly, and no
;;;;                   other pinned assembly mentions it at all. XNA declares
;;;;                   this exception and never throws it.
;;;;   the pinned ABIs `CNA/C/storage.h' documents the result codes each of the
;;;;                   forty-nine storage routes can answer, and
;;;;                   `CNA_RESULT_NOT_SUPPORTED' is not among them for any of
;;;;                   them, in any of the three admitted versions.
;;;;
;;;; Neither side produces one, so **nothing here maps a result code onto it**.
;;;; Inventing a mapping -- "a device route that answered NOT_SUPPORTED means the
;;;; device went away" -- would put this binding's guess where XNA has a fact, and
;;;; would mislabel any unrelated NOT_SUPPORTED that a future ABI starts
;;;; answering. The class is real, catchable and signallable by a program; no
;;;; CNA-Lisp route signals it, because no measurement says one should.
;;;;
;;;; **It declares four constructors and the other three exceptions declare
;;;; three.** The fourth is `new(SerializationInfo, StreamingContext)', the CLR's
;;;; protected deserialization constructor, which every `[Serializable]' exception
;;;; carries. Serialization is not projected and has no counterpart, so that one
;;;; is declared not applicable rather than collapsed onto MAKE-CONDITION with the
;;;; other three: it is not a way to construct the exception, it is the runtime's
;;;; way to rebuild one from a stream this binding has no notion of.

(in-package #:microsoft.xna.framework.storage)

(define-condition storage-device-not-connected-error (xna:cna-not-supported-error) ()
  (:documentation
   "The storage device is not connected.

CNA-Lisp's projection of
Microsoft.Xna.Framework.Storage.StorageDeviceNotConnectedException.

A statement about the *device*, not about the program: it means a device a
program is holding has gone away.

**No CNA-Lisp route signals it**, and that is measured on both sides rather than
an omission: the pinned Storage assembly declares this type and constructs it
zero times, and `CNA/C/storage.h' documents no storage route as answering
`CNA_RESULT_NOT_SUPPORTED' in any admitted ABI. A binding that mapped some
result code onto it anyway would be guessing. The file header sets out both
measurements.

What the class still is, is real: a program can signal one, handlers can catch
one, and it can be subclassed. It is a subtype of `CNA-NOT-SUPPORTED-ERROR', so
a handler for that catches it -- which is also the supertype of
`NO-AUDIO-HARDWARE-ERROR' and `NO-MICROPHONE-CONNECTED-ERROR', two conditions
that *are* signalled, from the audio and capture families that do answer that
code.

**Not sealed in XNA**, unlike every other exception in this selection, so the
condition class is left open to subclassing here as well.")
  (:report
   (lambda (condition stream)
     (format stream "~@[~a: ~]" (xna:cna-error-operation condition))
     (let ((control (xna::%cna-error-format-control condition)))
       (if control
           (apply #'format stream control (xna::%cna-error-format-arguments condition))
           (format stream
                   "the storage device is not connected. No CNA-Lisp route ~
                    signals this: the pinned XNA assembly never constructs the ~
                    exception and no admitted CNA ABI documents a storage route ~
                    answering CNA_RESULT_NOT_SUPPORTED, so one that arrives came ~
                    from the program.")))
     (let ((message (xna:cna-error-native-message condition)))
       (when message (format stream " ~a" message)))
     (let ((cause (xna:cna-error-cause condition)))
       (when cause (format stream " Caused by ~a: ~a" (type-of cause) cause))))))
