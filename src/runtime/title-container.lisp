;;;; title-container.lisp --- Microsoft.Xna.Framework.TitleContainer.
;;;;
;;;; One static member: `OpenStream(String)`, which answers a stream over a file
;;;; in the title's content location. Read from the pinned assembly rather than
;;;; from a description of it, because almost all of this member is *validation*
;;;; and validation is exactly the part a reimplementation from first principles
;;;; gets wrong.
;;;;
;;;; **CNA has a route for this and it is deliberately not used.**
;;;; `cna_title_container_read_ext' reads a whole file from the title location,
;;;; and its own header says why it is shaped that way: "The canonical operation
;;;; hands back an open stream. This ABI has no stream handle for title content
;;;; ... so the count/copy pair delivers the whole file instead. That is a
;;;; deliberate narrowing: incremental reads over a title stream are not
;;;; available." XNA's member answers a `FileStream' -- lazy, seekable, as large
;;;; as the file and no larger in memory -- and Common Lisp has exactly that in
;;;; `OPEN'. Taking CNA's narrowing here would make this member *less* like XNA
;;;; than the language already allows it to be, for no gain: reading a file is
;;;; not a CNA-owned resource, and nothing about it needs to cross the C boundary.
;;;;
;;;; What does come from CNA is the **title location**, through
;;;; `cna_title_location_copy_path' -- so a program that overrode the base path
;;;; through CNA is honoured, exactly as XNA reads `TitleLocation.Path'.
;;;;
;;;; **The path cleaning is XNA's, transcribed.** `GetCleanPath' and
;;;; `IsCleanPathAbsolute' are private in the assembly and are what decide whether
;;;; a name is refused, so they are reproduced here rather than delegated to CNA
;;;; or to the host: `a/../b' resolves to `b' and is accepted, `../b' is refused,
;;;; and the seven characters `IsCleanPathAbsolute' rejects are the seven the
;;;; assembly's `badCharacters' array holds -- read out of its static data blob,
;;;; not guessed.

(in-package #:microsoft.xna.framework)

(defparameter +title-container-bad-characters+ '(#\: #\* #\? #\" #\< #\> #\|)
  "The seven characters `IsCleanPathAbsolute' refuses.

Read from the pinned assembly's static data rather than assumed: XNA's
`badCharacters' is a seven-element char array initialised from a fourteen-byte
blob that disassembles as `3A 00 2A 00 3F 00 22 00 3C 00 3E 00 7C 00'. They are
Windows's invalid path characters together with the drive colon.")

(defun %replace-all (string from to)
  "Every occurrence of FROM in STRING replaced by TO, as String.Replace does."
  (with-output-to-string (out)
    (let ((start 0)
          (width (length from)))
      (loop
        (let ((at (search from string :start2 start)))
          (cond (at (write-string string out :start start :end at)
                    (write-string to out)
                    (setf start (+ at width)))
                (t (write-string string out :start start)
                   (return))))))))

(defun %collapse-parent-directory (path position remove-length)
  "XNA's CollapseParentDirectory: remove one `\\..' segment and what it undoes.

Answers the new path and the position to resume searching from. Transcribed from
the assembly: the segment removed runs from just after the previous separator
through POSITION plus REMOVE-LENGTH, and the resumption point is the start of
that segment less one, floored at one."
  (let* ((previous (position #\\ path :from-end t :end position))
         (start (if previous (1+ previous) 0)))
    (values (concatenate 'string
                         (subseq path 0 start)
                         (subseq path (min (length path) (+ position remove-length))))
            (max (1- start) 1))))

(defun %clean-title-path (path)
  "XNA's TitleContainer.GetCleanPath, transcribed from the assembly.

Slashes become backslashes, `\\.\\' segments collapse, a leading `.\\' and a
trailing `\\.' are stripped, `\\..\\' segments are collapsed left to right, and a
path that reduces to `.' becomes empty."
  (let ((path (substitute #\\ #\/ path)))
    (setf path (%replace-all path "\\.\\" "\\"))
    (loop while (and (>= (length path) 2) (string= ".\\" path :end2 2))
          do (setf path (subseq path 2)))
    (loop while (and (>= (length path) 2)
                     (string= "\\." path :start2 (- (length path) 2)))
          do (setf path (if (> (length path) 2)
                            (subseq path 0 (- (length path) 2))
                            "\\")))
    (let ((at 1))
      (loop while (< at (length path))
            do (let ((found (search "\\..\\" path :start2 at)))
                 (if (null found)
                     (return)
                     (multiple-value-setq (path at)
                       (%collapse-parent-directory path found 4))))))
    (when (and (>= (length path) 3)
               (string= "\\.." path :start2 (- (length path) 3)))
      (let ((at (- (length path) 3)))
        (when (plusp at)
          (setf path (%collapse-parent-directory path at 3)))))
    (if (string= path ".") "" path)))

(defun %clean-title-path-absolute-p (path)
  "XNA's TitleContainer.IsCleanPathAbsolute, transcribed from the assembly.

`Absolute' is XNA's word for `not safely inside the title', which is why a
relative path with a `..' in it counts: the member refuses anything that could
name a file the title does not contain."
  (or (find-if (lambda (character) (member character +title-container-bad-characters+))
               path)
      (and (plusp (length path)) (char= #\\ (char path 0)))
      (and (>= (length path) 3) (string= "..\\" path :end2 3))
      (search "\\..\\" path)
      (and (>= (length path) 3) (string= "\\.." path :start2 (- (length path) 3)))
      (string= ".." path)))

(defun %title-location-path ()
  "The title's base path, from CNA, so an override made there is honoured."
  (let ((game (cna-lisp.internal:active-game)))
    (unless game
      (error 'cna-invalid-state-error
             :operation "title-container-open-stream" :object-type 'title-container
             :format-control
             "there is no live game, and CNA resolves the title location against one. ~
              XNA's TitleContainer is static and needs none; CNA's title-location routes ~
              take a game handle for thread affinity, which is the same reason ~
              Keyboard.GetState works from the process's one active game."))
    (cna-lisp.internal:check-usable game "title-container-open-stream")
    (let ((handle (cna-lisp.internal:handle-of game)))
      (cna-lisp.internal:count-then-copy-string
       (lambda (out)
         (cna-lisp.internal.ffi::%title-location-get-path-size handle out))
       (lambda (buffer capacity out)
         (cna-lisp.internal.ffi::%title-location-copy-path handle buffer capacity out))
       "title-container-open-stream"))))

(defun title-container-open-stream (name)
  "TitleContainer.OpenStream(String): a stream over a file in the title's content.

    (with-open-stream (in (title-container-open-stream \"Content/logo.png\"))
      (gfx:texture-2d-from-stream device in))

The stream is an ordinary Common Lisp binary input stream and is the **caller's**
to close, exactly as XNA's `FileStream' is. See `src/framework/streams.lisp' for
what `System.IO.Stream' maps onto and why.

NAME is relative to the title's content location and is validated the way XNA
validates it: an empty name is an argument failure, `a/../b' resolves to `b' and
is accepted, and anything that could name a file outside the title -- a leading
separator, a leading or trailing `..', an embedded `\\..\\', or any of the seven
characters XNA's `badCharacters' holds -- is refused as an argument failure and
not as a missing file. A name that survives validation and names nothing is a
`CNA-IO-ERROR', which is what XNA's `FileNotFoundException' says."
  (when (or (null name) (and (stringp name) (zerop (length name))))
    (error 'cna-argument-error
           :operation "title-container-open-stream" :parameter-name "name"
           :format-control
           "an asset name is required; XNA throws ArgumentNullException for a null or ~
            empty one."))
  (check-type name string)
  (let ((clean (%clean-title-path name)))
    (when (%clean-title-path-absolute-p clean)
      (error 'cna-argument-error
             :operation "title-container-open-stream" :parameter-name "name"
             :format-control
             "~s does not name a file inside the title. XNA refuses a rooted path, one ~
              that walks out with `..', and any name holding one of ~{~a~^ ~} -- the seven ~
              characters its own badCharacters array holds."
             :format-arguments (list name +title-container-bad-characters+)))
    (let ((path (merge-pathnames (substitute #\/ #\\ clean)
                                 (%title-location-directory))))
      (handler-case (open path :element-type '(unsigned-byte 8))
        (file-error ()
          (error 'cna-io-error
                 :operation "title-container-open-stream" :object-type 'title-container
                 :format-control
                 "~s could not be opened from the title's content location (~a). XNA ~
                  reports this as FileNotFoundException."
                 :format-arguments (list name (%title-location-path))))))))

(defun %title-location-directory ()
  "The title's base path as a directory pathname, for MERGE-PATHNAMES."
  (let ((path (%title-location-path)))
    (pathname (if (and (plusp (length path))
                       (char/= #\/ (char path (1- (length path)))))
                  (concatenate 'string path "/")
                  path))))
