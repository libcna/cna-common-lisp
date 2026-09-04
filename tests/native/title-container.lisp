;;;; title-container.lisp --- TitleContainer.OpenStream and the paths it refuses.
;;;;
;;;; Almost all of this member is *validation*, so almost all of this file is
;;;; about which names are refused and which are not. The rules are XNA's,
;;;; transcribed from the pinned assembly's `GetCleanPath' and
;;;; `IsCleanPathAbsolute', and the point of testing them one at a time is that a
;;;; reimplementation from a description gets exactly this kind of thing wrong:
;;;; `a/../b' resolves and is **accepted**, while `../b' is refused, and nothing
;;;; but reading the code says which way round that goes.
;;;;
;;;; The pure half -- what the two path functions do to a string -- needs no
;;;; native library and would be a unit test if the functions were public; they
;;;; are private, so it runs here with the rest.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defclass title-container-game (counting-game)
  ((base :initform nil :accessor title-base)
   (opened :initform nil :accessor opened-octets)
   (outcomes :initform '() :accessor path-outcomes)
   (failure :initform nil :accessor title-failure))
  (:documentation "Reads the title location and opens files relative to it."))

(defun %title-outcome (game label thunk)
  (push (cons label
              (handler-case (let ((value (funcall thunk)))
                              (when (streamp value) (close value))
                              :accepted)
                (error (condition) (type-of condition))))
        (path-outcomes game)))

(defmethod xna:load-content ((game title-container-game))
  (call-next-method)
  (handler-case
      (progn
        (setf (title-base game) (xna::%title-location-path))
        ;; A file that certainly exists relative to the title location: the
        ;; location is the executable's directory, which for this suite is
        ;; wherever SBCL was started, so a file is written there first.
        (let* ((name "cna-lisp-title-probe.bin")
               (path (merge-pathnames name (xna::%title-location-directory))))
          (with-open-file (out path :direction :output :element-type '(unsigned-byte 8)
                                    :if-exists :supersede)
            (write-sequence #(67 78 65 45 76 105 115 112) out))
          (unwind-protect
               (progn
                 (setf (opened-octets game)
                       (with-open-stream (in (xna:title-container-open-stream name))
                         (let ((buffer (make-array 8 :element-type '(unsigned-byte 8))))
                           (read-sequence buffer in)
                           buffer)))
                 ;; the ordinary shapes
                 (%title-outcome game :relative
                                 (lambda () (xna:title-container-open-stream name)))
                 (%title-outcome game :dot-slash
                                 (lambda ()
                                   (xna:title-container-open-stream
                                    (concatenate 'string "./" name))))
                 (%title-outcome game :resolved-parent
                                 (lambda ()
                                   (xna:title-container-open-stream
                                    (concatenate 'string "anywhere/../" name))))
                 (%title-outcome game :backslash-separator
                                 (lambda ()
                                   (xna:title-container-open-stream
                                    (concatenate 'string ".\\" name))))
                 ;; and the ones XNA refuses
                 (%title-outcome game :missing
                                 (lambda ()
                                   (xna:title-container-open-stream "no-such-title-file")))
                 (%title-outcome game :empty
                                 (lambda () (xna:title-container-open-stream "")))
                 (%title-outcome game :null
                                 (lambda () (xna:title-container-open-stream nil)))
                 (%title-outcome game :leading-parent
                                 (lambda ()
                                   (xna:title-container-open-stream "../etc/passwd")))
                 (%title-outcome game :embedded-parent
                                 (lambda ()
                                   (xna:title-container-open-stream "a/../../etc/passwd")))
                 (%title-outcome game :rooted
                                 (lambda ()
                                   (xna:title-container-open-stream "/etc/passwd")))
                 (%title-outcome game :drive-letter
                                 (lambda ()
                                   (xna:title-container-open-stream "C:/Windows/win.ini")))
                 (dolist (character '(#\* #\? #\" #\< #\> #\|))
                   (%title-outcome game (intern (format nil "BAD-~a" (char-code character))
                                                :keyword)
                                   (let ((character character))
                                     (lambda ()
                                       (xna:title-container-open-stream
                                        (format nil "a~ab" character)))))))
            (ignore-errors (delete-file path)))))
    (error (condition) (setf (title-failure game) condition))))

(defmacro with-title-container-game ((game) &body body)
  `(let ((,game (make-instance 'title-container-game :exit-after 2)))
     (unwind-protect
          (progn (xna:run ,game)
                 (is (null (title-failure ,game))
                     "the fixture failed: ~a" (title-failure ,game))
                 ,@body)
       (xna:dispose ,game))))

(defun %title-result (game label)
  (cdr (assoc label (path-outcomes game))))

;;; --- the member ------------------------------------------------------------

(define-native-test the-title-location-is-a-real-path-from-cna
  "TitleLocation.Path comes from CNA rather than from anything guessed here, so a
program that overrode it through the ABI is honoured."
  (with-title-container-game (game)
    (is (stringp (title-base game)))
    (is (plusp (length (title-base game)))
        "the title location came back empty")))

(define-native-test open-stream-answers-a-readable-stream-over-the-file
  "The stream is an ordinary Common Lisp binary input stream and really holds the
file's bytes: eight known ones, written just before and read straight back."
  (with-title-container-game (game)
    (is (equalp #(67 78 65 45 76 105 115 112) (opened-octets game))
        "the stream answered ~a" (opened-octets game))))

(define-native-test open-stream-accepts-the-names-xna-accepts
  "Four shapes that must all reach the same file.

`a/../b' resolving to `b' is the one worth stating: XNA cleans the path *before*
it decides whether the path escapes, so an interior `..' that cancels out is
accepted while a leading one is not. A validator that checked for `..' first
would refuse this, and would be wrong."
  (with-title-container-game (game)
    (dolist (label '(:relative :dot-slash :resolved-parent :backslash-separator))
      (is (eq :accepted (%title-result game label))
          "~a was refused with ~a" label (%title-result game label)))))

(define-native-test open-stream-refuses-what-xna-refuses-and-says-which
  "A name that escapes the title is an **argument** failure and a name that
merely names nothing is an **IO** failure, which is the distinction XNA draws
between ArgumentException and FileNotFoundException. Collapsing the two would
make a traversal attempt look like a typo."
  (with-title-container-game (game)
    (is (eq 'xna:cna-io-error (%title-result game :missing))
        "a missing file gave ~a" (%title-result game :missing))
    (dolist (label '(:empty :null :leading-parent :embedded-parent :rooted
                     :drive-letter))
      (is (eq 'xna:cna-argument-error (%title-result game label))
          "~a gave ~a rather than an argument failure"
          label (%title-result game label)))))

(define-native-test open-stream-refuses-each-of-the-seven-bad-characters
  "The seven are XNA's own `badCharacters', read out of the assembly's static
data blob rather than guessed. The colon is covered by the drive-letter case
above; these are the other six."
  (with-title-container-game (game)
    (dolist (character '(#\* #\? #\" #\< #\> #\|))
      (let ((label (intern (format nil "BAD-~a" (char-code character)) :keyword)))
        (is (eq 'xna:cna-argument-error (%title-result game label))
            "a name containing ~a gave ~a" character (%title-result game label))))))

;;; --- the path cleaning, which is where the behaviour actually lives ---------

(define-native-test the-path-cleaning-is-xnas-and-not-the-hosts
  "GetCleanPath, one rule at a time.

Transcribed from the assembly, so these are assertions about XNA rather than
about this implementation: a reimplementation that used the host's path
normaliser instead would differ on most of them."
  (flet ((clean (in) (xna::%clean-title-path in)))
    (is (string= "a\\b" (clean "a/b")) "slashes fold to backslashes")
    (is (string= "a\\b" (clean "a\\.\\b")) "a `\\.\\' segment collapses")
    (is (string= "b" (clean "./b")) "a leading `.\\' is stripped")
    (is (string= "b" (clean ".\\.\\b")) "and stripped repeatedly")
    (is (string= "a" (clean "a\\.")) "a trailing `\\.' is stripped")
    (is (string= "b" (clean "a/../b")) "an interior `..' cancels the segment before it")
    (is (string= "d" (clean "a/b/../../d")) "and does so repeatedly, left to right")
    (is (string= "" (clean ".")) "a path that reduces to `.' becomes empty")
    (is (string= "..\\b" (clean "../b"))
        "a *leading* `..' is left alone by the cleaning -- it is the refusal that ~
         catches it, and the two steps are separate on purpose")))

(define-native-test the-escape-check-is-xnas-and-not-a-substring-search
  "IsCleanPathAbsolute, one rule at a time, on already-cleaned paths."
  (flet ((escapes (in) (and (xna::%clean-title-path-absolute-p in) t)))
    (is-false (escapes "a\\b"))
    (is-false (escapes "b"))
    (is-true (escapes "\\a") "a rooted path escapes")
    (is-true (escapes "..\\b") "a leading `..' escapes")
    (is-true (escapes "a\\..\\..\\b") "an `..' that is still there after cleaning escapes")
    (is-true (escapes "a\\..") "a trailing `..' escapes")
    (is-true (escapes "..") "and `..' on its own")
    (dolist (character '(#\: #\* #\? #\" #\< #\> #\|))
      (is-true (escapes (format nil "a~ab" character))
               "~a is one of XNA's seven bad characters" character))
    ;; and one that is *not* one of the seven, so the list is a list and not
    ;; "anything unusual"
    (is-false (escapes "a b") "a space is not a bad character")
    (is-false (escapes "a'b") "nor is an apostrophe")))
