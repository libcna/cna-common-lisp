;;;; content.lisp --- ContentManager against a real CNA runtime.
;;;;
;;;; The loop this closes: before ContentManager existed, the only way to obtain a
;;;; SpriteFont was a test-only producer, and no program written against the
;;;; public API could draw text. These tests exercise the public path end to end --
;;;; a `.cnj' descriptor on disk, through `Load<SpriteFont>', to a font whose
;;;; measurements match the hand-built one glyph for glyph.
;;;;
;;;; `tests/fixtures/test-font.cnj' describes exactly the font
;;;; `tests/native/sprite-font.lisp' builds by hand over the same atlas, which is
;;;; what makes the cross-check below worth anything: the two paths are independent
;;;; and must agree.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defparameter *font-asset* "test-font"
  "The .cnj SpriteFont in tests/fixtures, describing the same font
GLYPH-ATLAS-ROWS builds by hand over glyph-atlas-16x8.png.")

(defclass content-game (graphics-game)
  ((font :initform nil :accessor loaded-font)
   (atlas :initform nil :accessor loaded-atlas)
   (loaded-texture :initform nil :accessor loaded-texture)
   (asset :initarg :asset :initform *font-asset* :accessor asset)
   (load-error :initform nil :accessor load-error)
   (observations :initform '() :accessor observations))
  (:documentation
   "Loads assets through the game's own ContentManager during LoadContent."))

(defun %fixture-root ()
  (namestring (truename (fixture-path "test-font.cnj"))))

(defun %content-root ()
  "The directory the fixtures live in, as CNA's root directory."
  (let ((path (truename (fixture-path "test-font.cnj"))))
    (namestring (make-pathname :name nil :type nil :defaults path))))

(defun observe (game key value)
  "Record a fact from inside a callback, to be asserted outside it.

No FiveAM assertion runs inside a native callback: a failed assertion is a
condition, and a condition crossing the C frame is a different failure than the
one being tested."
  (push (cons key value) (observations game))
  value)

(defun observed (game key)
  (cdr (assoc key (observations game))))

(defmethod xna:load-content ((game content-game))
  (call-next-method)
  (handler-case
      (let ((content (xna:content game)))
        (setf (xna.content:root-directory content) (%content-root))
        (observe game :root (xna.content:root-directory content))
        ;; Counted here rather than outside the loop, because the fixture this
        ;; inherits from owns resources of its own: the claim is that a load adds
        ;; nothing when it fails, not that the game owns nothing at all.
        (observe game :children-before (length (int:children-of game)))
        (unwind-protect
             (multiple-value-bind (font atlas)
                 (xna.content:load-asset content 'gfx:sprite-font (asset game))
               (setf (loaded-font game) font
                     (loaded-atlas game) atlas))
          (observe game :children-after (length (int:children-of game)))))
    (error (condition) (setf (load-error game) condition))))

(defmacro with-content-game ((variable &rest initargs) &body body)
  "Run a CONTENT-GAME, then assert with the loaded assets still alive."
  `(let ((,variable (make-instance 'content-game :exit-after 2 ,@initargs)))
     (unwind-protect
          (progn (xna:run ,variable) ,@body)
       (progn
         (when (loaded-texture ,variable)
           (ignore-errors (xna:dispose (loaded-texture ,variable))))
         ;; The font before its atlas: CNA refuses the other order, and the
         ;; binding records that parenting so the refusal is diagnosable.
         (when (loaded-font ,variable) (ignore-errors (xna:dispose (loaded-font ,variable))))
         (when (loaded-atlas ,variable) (ignore-errors (xna:dispose (loaded-atlas ,variable))))
         ;; GRAPHICS-GAME owns a batch and a texture of its own; leaving either
         ;; alive makes DISPOSE refuse the game and strands it for every later
         ;; test, because CNA allows one active game per process.
         (when (batch ,variable) (ignore-errors (xna:dispose (batch ,variable))))
         (when (texture ,variable) (ignore-errors (xna:dispose (texture ,variable))))
         (when (manager ,variable) (ignore-errors (xna:dispose (manager ,variable))))
         (xna:dispose ,variable)))))

;;; --- the loop closes --------------------------------------------------------

(define-native-test a-sprite-font-loads-through-the-public-content-api
  "Load<SpriteFont> over a .cnj descriptor, with no test-only producer anywhere.

This is the member that makes SpriteFont reachable at all from a program written
against the public API."
  (with-content-game (game)
    (is (null (load-error game)) "loading failed: ~a" (load-error game))
    (let ((font (loaded-font game)))
      (is (typep font 'gfx:sprite-font))
      (is (typep (loaded-atlas game) 'gfx:texture-2d)
          "the loader must answer the atlas too; CNA hands back both handles")
      (is (= +glyph-atlas-line-spacing+ (gfx:line-spacing font)))
      (is (= 0.0f0 (gfx:spacing font)))
      (is (equalp #(65 66) (gfx:characters font))))))

(define-native-test a-loaded-font-and-a-built-font-agree-glyph-for-glyph
  "The descriptor on disk and GLYPH-ATLAS-ROWS describe the same font.

Two independent paths to the same table -- one through cna_sprite_font_create
with rows this suite states, one through cna_content_manager_load_sprite_font
parsing a .cnj -- so agreement is evidence about both. A descriptor that drifted
from the rows, or a loader that mis-parsed one, shows up here."
  (with-content-game (game)
    (is (null (load-error game)) "loading failed: ~a" (load-error game))
    (let ((font (loaded-font game))
          (rows (glyph-atlas-rows)))
      (loop for row in rows
            for index from 0
            do (destructuring-bind (unit bounds cropping kerning) row
                 (is (= unit (aref (gfx::%font-characters font) index)))
                 (is (xna:rectangle-equal bounds (aref (gfx::%font-glyphs font) index))
                     "glyph ~d's atlas rectangle loaded as ~a"
                     index (aref (gfx::%font-glyphs font) index))
                 (is (xna:rectangle-equal cropping (aref (gfx::%font-cropping font) index))
                     "glyph ~d's cropping loaded as ~a"
                     index (aref (gfx::%font-cropping font) index))
                 (is (xna:vector3-equal kerning (aref (gfx::%font-kerning font) index))
                     "glyph ~d's kerning loaded as ~a"
                     index (aref (gfx::%font-kerning font) index)))))))

(define-native-test a-loaded-font-measures-what-a-built-font-measures
  "MeasureString over the loaded table, against the arithmetic the built font
gives. Two glyphs eight wide with no bearings is sixteen by the line spacing."
  (with-content-game (game)
    (is (null (load-error game)) "loading failed: ~a" (load-error game))
    (let ((measured (gfx:measure-string (loaded-font game) "AB")))
      (is (= 16.0f0 (xna:vector2-x measured))
          "two 8-wide glyphs measured ~a wide" (xna:vector2-x measured))
      (is (= (coerce +glyph-atlas-line-spacing+ 'single-float) (xna:vector2-y measured))
          "one line measured ~a tall" (xna:vector2-y measured)))))

;;; --- the manager itself -----------------------------------------------------

(define-native-test a-games-content-manager-is-the-same-object-every-time
  "Game.Content is a field in XNA and answers by identity here."
  (with-content-game (game)
    (is (eq (xna:content game) (xna:content game)))))

(defclass content-setter-game (graphics-game)
  ((observations :initform '() :accessor observations)
   ;; Held so the lane can release it: disposal does not cascade here, and an
   ;; owned CONTENT-MANAGER left alive would refuse the game's own teardown.
   (assigned :initform nil :accessor assigned-manager)
   (setter-error :initform nil :accessor setter-error))
  (:documentation
   "Exercises Game.Content's setter inside LoadContent.

Inside, because the assignment needs a second CONTENT-MANAGER and building one
needs the game's graphics device, which CNA lends for the duration of a callback
and no longer. The observations are booleans so the assertions can be made after
the game has shut down."))

(defmethod xna:load-content ((game content-setter-game))
  (call-next-method)
  (handler-case
      (let* ((device (xna:graphics-device game))
             (facade (xna:content game))
             (mine (make-instance 'xna.content:content-manager :graphics-device device)))
        (setf (assigned-manager game) mine)
        (observe game :distinct (not (eq facade mine)))
        ;; The assignment, and XNA's `stfld'.
        (setf (xna:content game) mine)
        (observe game :identity (eq mine (xna:content game)))
        ;; A reference, not a copy: mutate the manager after assigning it.
        (setf (xna.content:root-directory mine) "assigned-and-then-changed")
        (observe game :mutation-visible
                 (string= "assigned-and-then-changed"
                          (xna.content:root-directory (xna:content game))))
        ;; Its own provider and its own cache. The facade's provider is the
        ;; game's services; a manager built over a device has none, and being
        ;; assigned does not lend it one.
        (observe game :assigned-keeps-its-provider
                 (null (xna.content:service-provider (xna:content game))))
        (observe game :facade-keeps-services
                 (eq (xna.content:service-provider facade) (xna:services game)))
        (observe game :caches-distinct
                 (not (eq (xna.content::%content-loaded-assets mine)
                          (xna.content::%content-loaded-assets facade))))
        ;; Nothing is disposed -- XNA's setter disposes nothing -- and ownership
        ;; does not move: the manager was already an owned child of this game
        ;; before the assignment and still is one.
        (observe game :nothing-disposed (not (xna:disposed-p facade)))
        (observe game :ownership-unmoved
                 (and (member mine (int:children-of game)) t))
        ;; NIL is refused, and refused *first*, so the property does not move.
        (observe game :null-refused
                 (handler-case (progn (setf (xna:content game) nil) nil)
                   (xna:cna-argument-error () t)))
        (observe game :unmoved-by-refusal (eq mine (xna:content game)))
        ;; The replaced facade can be put back, because it was only unreferenced.
        (setf (xna:content game) facade)
        (observe game :reassignable (eq facade (xna:content game))))
    (error (condition) (setf (setter-error game) condition))))

(define-native-test game-content-s-setter-assigns-a-reference-and-nothing-else
  "Game.Content's setter, which is `stfld' in XNA and is one here too.

The pinned IL is a null check throwing `ArgumentNullException()' and then
`ldarg.0; ldarg.1; stfld content'. There is no other effect, and in particular no
native call: CNA's `cna_game_set_content_manager_ext' **copies**, which cannot
express a reference assignment -- but nothing needs it to, because CNA's own game
never loads through the manager that route writes. This member was reported
partial on the copying route's account until the 2026-09-07 frontier audit
measured that the route had never been the obstacle.

What the assignment must and must not do is the whole test."
  (let ((game (make-instance 'content-setter-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (is (null (setter-error game)) "the setter lane failed: ~a"
               (setter-error game))
           (is-true (observed game :distinct))
           (is-true (observed game :identity)
                    "Game.Content answers the object that was assigned, by identity")
           (is-true (observed game :mutation-visible)
                    "a change made to the assigned manager is visible through the ~
                     property, which is what makes this a reference and not CNA's copy")
           (is-true (observed game :assigned-keeps-its-provider)
                    "the assigned manager keeps its own provider rather than ~
                     inheriting the facade's")
           (is-true (observed game :facade-keeps-services)
                    "and the facade still has the one the Game constructor gave it")
           (is-true (observed game :caches-distinct)
                    "two managers are two caches; assigning one does not merge them")
           (is-true (observed game :nothing-disposed)
                    "the replaced manager is not disposed; XNA's setter disposes nothing")
           (is-true (observed game :ownership-unmoved)
                    "a reference store is not an adoption: the assigned manager was ~
                     already an owned child of this game and still is")
           (is-true (observed game :null-refused)
                    "NIL is refused, as XNA's ArgumentNullException refuses it")
           (is-true (observed game :unmoved-by-refusal)
                    "and refused before anything is stored, so the property did not move")
           (is-true (observed game :reassignable)
                    "the game's own facade can be put back, because it was only ~
                     unreferenced"))
      (progn
        ;; The manager the lane built is an owned child and disposal does not
        ;; cascade, so it goes before its game -- exactly as a program's would.
        (when (assigned-manager game)
          (ignore-errors (xna:dispose (assigned-manager game))))
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (let ((teardown nil))
          (handler-case (xna:dispose game)
            (error (condition) (setf teardown condition)))
          (is (null teardown)
              "the game must shut down after Game.Content was reassigned: ~a"
              teardown))))))

(define-native-test the-root-directory-round-trips-through-cna
  "RootDirectory is set and read back through the ABI, not remembered here."
  (with-content-game (game)
    (is (string= (%content-root) (observed game :root))
        "root directory read back as ~s" (observed game :root))))

(define-native-test a-games-own-content-manager-is-disposable-and-unloads
  "`Game.Content.Dispose()' is legal, and does what XNA's does.

XNA's `ContentManager.Dispose(bool)' is `Unload()' followed by nulling both
collections -- a purely managed operation that destroys nothing native. So this
disposes the assets the manager loaded and marks the facade disposed, and CNA's
borrowed manager, which \"cannot be destroyed\", is left alone. The game shuts
down afterwards, which it could not if the assets were still alive."
  (let ((game (make-instance 'content-game :exit-after 2))
        (teardown nil))
    (unwind-protect
         (progn
           (xna:run game)
           (is (null (load-error game)) "loading failed: ~a" (load-error game))
           (let ((content (xna:content game))
                 (font (loaded-font game))
                 (atlas (loaded-atlas game)))
             (xna:dispose content)
             (is-true (xna:disposed-p content)
                      "a disposed manager must report itself disposed, as XNA's does")
             (is-true (xna:disposed-p font)
                      "Dispose must unload the font it loaded")
             (is-true (xna:disposed-p atlas)
                      "and the atlas that came with it")
             (is (eq content (xna:content game))
                 "Game.Content is a field in XNA and keeps answering the disposed ~
                  manager, rather than quietly making a new one")
             (signals xna:cna-disposed-error (xna.content:root-directory content))))
      (progn
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (handler-case (xna:dispose game)
          (error (condition) (setf teardown condition)))
        (is (null teardown)
            "the game would not shut down after Game.Content was disposed: ~a"
            teardown)))))

(define-native-test an-unknown-asset-fails-and-leaves-the-game-owning-nothing
  "A missing asset is an IO failure, and a failed load is all-or-nothing: the
game must not be left owning a font or an atlas the caller never received."
  (let ((game (make-instance 'content-game :exit-after 2 :asset "no-such-font")))
    (unwind-protect
         (progn
           (xna:run game)
           (is (typep (load-error game) 'xna:cna-io-error)
               "a missing asset gave ~a" (type-of (load-error game)))
           (is (null (loaded-font game)))
           (is (null (loaded-atlas game)))
           (is (= (observed game :children-before) (observed game :children-after))
               "a failed load changed the game's children from ~d to ~d"
               (observed game :children-before) (observed game :children-after)))
      (progn (when (batch game) (ignore-errors (xna:dispose (batch game))))
             (when (texture game) (ignore-errors (xna:dispose (texture game))))
             (when (manager game) (ignore-errors (xna:dispose (manager game))))
             (xna:dispose game)))))

(define-native-test an-asset-type-with-no-native-route-is-refused-by-name
  "CNA has one loader per asset type rather than a generic one, so the loadable
set is finite. Asking for something outside it says so and names the set."
  (with-content-game (game)
    (is (member 'gfx:sprite-font (xna.content:loadable-asset-types)))
    (is (member 'gfx:texture-2d (xna.content:loadable-asset-types)))
    (signals xna:cna-not-supported-error
      (xna.content:load-asset (xna:content game) 'xna:game "anything"))))

;;; --- Texture2D, and the dimensions CNA will not report ----------------------

(defclass texture-content-game (content-game) ())

(defmethod xna:load-content ((game texture-content-game))
  (call-next-method)
  (unless (load-error game)
    (handler-case
        (setf (loaded-texture game)
              (xna.content:load-asset (xna:content game) 'gfx:texture-2d
                                      "cna-lisp-mark.png"))
      (error (condition) (setf (load-error game) condition)))))

(define-native-test a-texture-loads-through-the-content-api
  "Load<Texture2D> over a loose image file."
  (let ((game (make-instance 'texture-content-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (is (null (load-error game)) "loading failed: ~a" (load-error game))
           (is (typep (loaded-texture game) 'gfx:texture-2d)))
      (progn
        (when (loaded-texture game) (ignore-errors (xna:dispose (loaded-texture game))))
        (when (loaded-font game) (ignore-errors (xna:dispose (loaded-font game))))
        (when (loaded-atlas game) (ignore-errors (xna:dispose (loaded-atlas game))))
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (xna:dispose game)))))

(define-native-test a-loaded-textures-size-is-refused-rather-than-invented
  "ABI 0.21.0 has no route reporting a Texture2D's dimensions. A decoded texture
knows its size because this binding read the image header; a loaded one does not,
and says so instead of answering a plausible zero."
  (with-content-game (game)
    (is (null (load-error game)) "loading failed: ~a" (load-error game))
    (let ((atlas (loaded-atlas game)))
      (signals xna:cna-not-supported-error (gfx:width atlas))
      (signals xna:cna-not-supported-error (gfx:height atlas))
      ;; and printing one must not signal, because printing never may
      (is (stringp (princ-to-string atlas))))))

;;; --- Unload -----------------------------------------------------------------

(define-native-test unload-disposes-what-it-loaded-as-xnas-does
  "XNA's Unload walks `disposableAssets' calling Dispose on every entry and then
clears both collections in a finally. Read from the assembly, and reproduced:
after an Unload the font and its atlas are disposed, and the manager is empty
and still usable.

This test used to assert the opposite -- that the font survived -- because
CNA's `cna_content_manager_unload' drops the manager's own cache and, in its own
words, \"independently owned resource handles returned by the manager are not
destroyed by this call\". That is still true of CNA's route; what changed is that
this binding no longer stops there. The manager keeps XNA's two collections, so
it has something of its own to release, and it releases it."
  (with-content-game (game)
    (is (null (load-error game)) "loading failed: ~a" (load-error game))
    (let ((content (xna:content game))
          (font (loaded-font game))
          (atlas (loaded-atlas game)))
      (xna.content:unload content)
      (is-true (xna:disposed-p font) "Unload must dispose the font it loaded")
      (is-true (xna:disposed-p atlas) "and the atlas that came with it")
      ;; ...and the manager itself is untouched: Unload is not Dispose.
      (is-false (xna:disposed-p content))
      (is (stringp (xna.content:root-directory content))
          "the manager must still work after an Unload")
      ;; A second Unload on an empty manager is an ordinary success.
      (xna.content:unload content)
      (is-true t))))

(define-native-test unload-empties-the-cache-so-the-next-load-is-a-new-object
  "The other half of Unload: `loadedAssets.Clear()'. A name loaded again after an
Unload is loaded again, and answers a different object -- which is what makes
Unload the way a program frees content and then reloads it."
  (with-content-game (game)
    (is (null (load-error game)) "loading failed: ~a" (load-error game))
    (let ((content (xna:content game))
          (first-font (loaded-font game)))
      (xna.content:unload content)
      (is-true (xna:disposed-p first-font))
      ;; Reloading needs the device, which is only lent inside a callback, so
      ;; this asserts the cache is empty rather than reloading here.
      (is (zerop (hash-table-count (xna.content::%content-loaded-assets content)))
          "Unload left ~d entry/entries in the cache"
          (hash-table-count (xna.content::%content-loaded-assets content)))
      (is (null (xna.content::%content-disposable-assets content))
          "Unload left ~d asset(s) on the disposal list"
          (length (xna.content::%content-disposable-assets content))))))

;;; --- the cache, which is XNA's and is now here too ---------------------------

(defclass twice-loading-game (content-game)
  ((second-font :initform nil :accessor second-font)
   (second-atlas :initform nil :accessor second-atlas)
   (wrong-type :initform nil :accessor wrong-type-error)
   (cleaned-name :initform nil :accessor cleaned-name-result))
  (:documentation "Loads the same asset name twice, and once as the wrong type."))

(defmethod xna:load-content ((game twice-loading-game))
  (call-next-method)
  (unless (load-error game)
    (handler-case
        (let ((content (xna:content game)))
          (multiple-value-bind (font atlas)
              (xna.content:load-asset content 'gfx:sprite-font (asset game))
            (setf (second-font game) font
                  (second-atlas game) atlas))
          ;; The cache is keyed by the *cleaned* name, so a name that cleans to
          ;; the same string is the same entry -- which is why the cleaning runs
          ;; before the lookup rather than after it.
          (setf (cleaned-name-result game)
                (xna.content:load-asset content 'gfx:sprite-font
                                        (concatenate 'string "./" (asset game))))
          ;; ...and it is keyed by the name *alone*, so asking for another type
          ;; is a failure rather than a second load.
          (handler-case
              (xna.content:load-asset content 'gfx:texture-2d (asset game))
            (error (condition) (setf (wrong-type-error game) condition))))
      (error (condition) (setf (load-error game) condition)))))

(define-native-test loading-one-asset-twice-answers-the-same-object
  "XNA's ContentManager caches by asset name: `Load<T>(\"x\")' twice answers the
same instance. So does this now, and the consequence is ownership -- a program
that loads twice owns *one* font and one atlas, and Unload is what frees them.

This test used to assert the opposite, and said so: CNA's ABI has one
create-shaped route per asset type with no cache in front of it. That is still
true of CNA; the cache is this binding's, in front of CNA's route, which is where
XNA's is too."
  (let ((game (make-instance 'twice-loading-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (is (null (load-error game)) "loading failed: ~a" (load-error game))
           (is (eq (loaded-font game) (second-font game))
               "two loads of one name answered different objects")
           (is (eq (loaded-atlas game) (second-atlas game))
               "the atlas that comes with the font must be cached with it")
           (is (eq (loaded-font game) (cleaned-name-result game))
               "`./x' and `x' clean to the same name and must be one entry"))
      (progn
        (when (loaded-font game) (ignore-errors (xna:dispose (loaded-font game))))
        (when (loaded-atlas game) (ignore-errors (xna:dispose (loaded-atlas game))))
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (xna:dispose game)))))

(define-native-test a-cached-name-asked-for-as-another-type-is-refused
  "The cache is keyed by the name and not by the type, so `Load<Texture2D>' on a
name already loaded as a SpriteFont is a failure and not a second load. XNA
throws ContentLoadException there; this binding's exception types are a separate
closure, so it is an argument failure naming both types."
  (let ((game (make-instance 'twice-loading-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (is (null (load-error game)) "loading failed: ~a" (load-error game))
           (is (typep (wrong-type-error game) 'xna:cna-argument-error)
               "asking for the wrong type gave ~a" (type-of (wrong-type-error game)))
           (is (search "sprite-font" (string-downcase
                                      (princ-to-string (wrong-type-error game))))
               "the refusal should name what is actually cached: ~a"
               (wrong-type-error game)))
      (progn
        (when (loaded-font game) (ignore-errors (xna:dispose (loaded-font game))))
        (when (loaded-atlas game) (ignore-errors (xna:dispose (loaded-atlas game))))
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (xna:dispose game)))))

(define-native-test loading-refuses-an-empty-name-and-a-disposed-manager
  "XNA's Load checks the manager first and the name second: a disposed manager is
ObjectDisposedException whatever the name, and an empty name is
ArgumentNullException. The order is the assembly's."
  (with-content-game (game)
    (let ((content (xna:content game)))
      (signals xna:cna-argument-error
        (xna.content:load-asset content 'gfx:sprite-font ""))
      (xna:dispose content)
      (signals xna:cna-disposed-error
        (xna.content:load-asset content 'gfx:sprite-font "")))))

;;; --- a refused disposal must cost the object nothing -------------------------
;;;
;;; DISPOSE invalidates through an UNWIND-PROTECT, so a refusal raised from inside
;;; the destruction still ran the invalidation on the way out: `Game.Content' came
;;; back marked disposed and holding no handle, over a native manager that was
;;; -- correctly -- never destroyed. The refusal now happens in %CHECK-DISPOSABLE,
;;; before anything is touched. These tests are what says so.

(defclass refused-dispose-game (content-game)
  ((device-refusal :initform nil :accessor device-refusal)
   (device-still-works :initform nil :accessor device-still-works))
  (:documentation "Disposes the parent-owned facade that has nothing to release."))

(defmethod xna:load-content ((game refused-dispose-game))
  (call-next-method)
  (let ((device (xna:graphics-device game)))
    (handler-case (xna:dispose device)
      (error (condition) (setf (device-refusal game) condition)))
    ;; A legal operation, through the facade that was just refused. It has to
    ;; reach CNA -- the renderer name is a real ABI round trip.
    (handler-case (setf (device-still-works game) (gfx:renderer-name device))
      (error (condition) (setf (device-still-works game) condition)))))

(define-native-test a-refused-disposal-leaves-the-facade-completely-usable
  "The graphics device refuses to be disposed and is untouched by refusing.

The refusal is right: CNA lends the device for a callback's duration and releases
it with the game, and XNA's `GraphicsDevice.Dispose' is itself reported missing
because a CNA-Lisp program never constructs one. What must not happen is the
object paying for the refusal -- a caller who wraps it in HANDLER-CASE, which is
the reasonable thing to do, must be left with the same working facade.

`Game.Content' used to be the other half of this test and no longer is: it is
disposable now, because XNA's `ContentManager.Dispose()' has real work to do that
is not a native handle. The bug this test exists for is the same either way --
DISPOSE invalidates through an UNWIND-PROTECT, so a refusal raised from inside it
marked the object disposed on the way out."
  (let ((game (make-instance 'refused-dispose-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (is (typep (device-refusal game) 'xna:cna-ownership-error)
               "disposing the graphics device gave ~a" (type-of (device-refusal game)))
           (is-false (xna:disposed-p (xna:graphics-device game))
                     "the refused device was marked disposed anyway")
           (is (stringp (device-still-works game))
               "the refused device could no longer be used: ~a" (device-still-works game)))
      (progn
        (when (loaded-font game) (ignore-errors (xna:dispose (loaded-font game))))
        (when (loaded-atlas game) (ignore-errors (xna:dispose (loaded-atlas game))))
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (xna:dispose game)))))

;;; --- construction is all-or-nothing here too --------------------------------

(defclass constructing-game (content-game)
  ((no-device :initform nil :accessor no-device-error)
   (owned :initform nil :accessor owned-manager)
   (owned-root :initform nil :accessor owned-root)
   (owned-is-distinct :initform nil :accessor owned-is-distinct)
   (owned-child-count :initform nil :accessor owned-child-count)
   (facade-with-device :initform nil :accessor facade-with-device-error))
  (:documentation "Builds content managers the two legal ways, and one illegal way."))

(defmethod xna:load-content ((game constructing-game))
  (call-next-method)
  (let ((device (xna:graphics-device game)))
    ;; 1. no graphics device: refused at construction, not at first load.
    (handler-case (make-instance 'xna.content:content-manager)
      (error (condition) (setf (no-device-error game) condition)))
    ;; 2. the facade shape is not a public constructor either.
    (handler-case (make-instance 'xna.content:content-manager
                                 :ownership :parent-owned :owner game
                                 :graphics-device device)
      (error (condition) (setf (facade-with-device-error game) condition)))
    ;; 3. an owned one, built the declared way, and usable immediately.
    (let ((manager (make-instance 'xna.content:content-manager
                                  :graphics-device device
                                  :root-directory (%content-root))))
      (setf (owned-manager game) manager
            (owned-root game) (xna.content:root-directory manager)
            (owned-is-distinct game) (not (eq manager (xna:content game)))
            (owned-child-count game)
            (count manager (int:children-of game))))))

(define-native-test a-content-manager-refuses-to-exist-without-what-it-needs
  "`(make-instance 'content-manager)' used to answer a zombie: no handle, no
owner, and a failure deferred to whichever load happened first. There are two
ways a manager comes into existence and neither of them is \"partly\"."
  (let ((game (make-instance 'constructing-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (is (typep (no-device-error game) 'xna:cna-usage-error)
               "a manager with no device was built anyway, or gave ~a"
               (type-of (no-device-error game)))
           (is (typep (facade-with-device-error game) 'xna:cna-usage-error)
               "the facade shape accepted a graphics device: ~a"
               (type-of (facade-with-device-error game)))
           (let ((manager (owned-manager game)))
             (is (typep manager 'xna.content:content-manager))
             (is-false (xna:disposed-p manager))
             (is (string= (%content-root) (owned-root game))
                 "the owned manager's root directory read back as ~s" (owned-root game))
             (is-true (owned-is-distinct game)
                      "an owned manager and Game.Content answered the same object")
             (is (= 1 (owned-child-count game))
                 "the owned manager is registered as a child of the game ~d time(s)"
                 (owned-child-count game))))
      (progn
        (when (owned-manager game) (ignore-errors (xna:dispose (owned-manager game))))
        (when (loaded-font game) (ignore-errors (xna:dispose (loaded-font game))))
        (when (loaded-atlas game) (ignore-errors (xna:dispose (loaded-atlas game))))
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (xna:dispose game)))))

(define-native-test an-owned-content-manager-is-disposed-like-any-other-child
  "The other half of the ownership question: an owned manager *is* disposable,
and the game refuses to shut down while it is alive. Everything else the fixture
owns is released first, so the refusal can only be about the manager -- and the
condition has to name it."
  (let ((game (make-instance 'constructing-game :exit-after 2))
        (refused nil))
    (unwind-protect
         (progn
           (xna:run game)
           (when (loaded-font game) (xna:dispose (loaded-font game)))
           (when (loaded-atlas game) (xna:dispose (loaded-atlas game)))
           (when (batch game) (xna:dispose (batch game)))
           (when (texture game) (xna:dispose (texture game)))
           (when (manager game) (xna:dispose (manager game)))
           (handler-case (xna:dispose game)
             (xna:cna-ownership-error (condition) (setf refused condition)))
           (is-true refused
                    "the game shut down with an owned content manager still alive")
           (is (search "content-manager" (princ-to-string refused))
               "the refusal did not name the manager: ~a" refused)
           (xna:dispose (owned-manager game))
           (is-true (xna:disposed-p (owned-manager game)))
           ;; and now it shuts down
           (xna:dispose game)
           (is-true (xna:disposed-p game)))
      (progn
        (when (owned-manager game) (ignore-errors (xna:dispose (owned-manager game))))
        (when (loaded-font game) (ignore-errors (xna:dispose (loaded-font game))))
        (when (loaded-atlas game) (ignore-errors (xna:dispose (loaded-atlas game))))
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (ignore-errors (xna:dispose game))))))

;;; --- Load<Effect> ------------------------------------------------------------
;;;
;;; The fourth asset type, and the one whose absence was a wrong reason: the
;;; declared reason for `ContentManager.Load' named three loader routes and said
;;; those were "the ones CNA has a route for". `cna_content_manager_load_effect'
;;; is a fourth, for a type that is in the selection, and CNA's own header calls
;;; it "the canonical `Load<Effect>' specialization".
;;;
;;; It reads three shapes and only the compiled `.xnb' one needs
;;; CNA_GRAPHICS_CAPABILITY_COMPILED_EFFECTS, which neither qualification renderer
;;; has. A `.cnj' descriptor naming a stock effect needs nothing, which is why
;;; these run on HEADLESS.

(defclass effect-content-game (graphics-game)
  ((results :initform '() :accessor effect-results)
   (loaded :initform '() :accessor loaded-effects)
   (types :initform nil :accessor loadable-types)
   (failure :initform nil :accessor effect-load-failure))
  (:documentation "Loads Effects through the game's own ContentManager."))

(defmethod xna:load-content ((game effect-content-game))
  (call-next-method)
  (handler-case
      (let ((content (xna:content game)))
        (setf (xna.content:root-directory content) (%content-root)
              (loadable-types game) (xna.content:loadable-asset-types))
        (flet ((attempt (label name)
                 (push (cons label
                             (handler-case
                                 (let ((effect (xna.content:load-asset
                                                content 'gfx:effect name)))
                                   (push effect (loaded-effects game))
                                   (list :class (type-of effect)
                                         :techniques (gfx:collection-count
                                                      (gfx:effect-techniques effect))
                                         ;; The same name twice is one asset: the
                                         ;; cache is keyed by the cleaned name.
                                         :cached (eq effect
                                                     (xna.content:load-asset
                                                      content 'gfx:effect name))))
                               (error (condition) (type-of condition))))
                       (effect-results game))))
          (attempt :basic "stock-basic-effect")
          (attempt :dual "stock-dual-texture-effect")
          (attempt :missing "no-such-effect-asset")
          ;; A descriptor that is a SpriteFont, asked for as an Effect: the cache
          ;; is keyed by name and not by type, so this must be the loader
          ;; refusing rather than a font coming back.
          (attempt :wrong-type *font-asset*)))
    (error (condition) (setf (effect-load-failure game) condition))))

(defmacro with-effect-content-game ((game) &body body)
  `(let ((,game (make-instance 'effect-content-game :exit-after 2)))
     (unwind-protect
          (progn (xna:run ,game)
                 (is (null (effect-load-failure ,game))
                     "the fixture failed: ~a" (effect-load-failure ,game))
                 ,@body)
       (progn
         (dolist (effect (loaded-effects ,game)) (ignore-errors (xna:dispose effect)))
         (when (batch ,game) (ignore-errors (xna:dispose (batch ,game))))
         (when (texture ,game) (ignore-errors (xna:dispose (texture ,game))))
         (when (manager ,game) (ignore-errors (xna:dispose (manager ,game))))
         (xna:dispose ,game)))))

(defun %effect-result (game label)
  (cdr (assoc label (effect-results game))))

(define-native-test an-effect-is-a-loadable-asset-type
  "LOADABLE-ASSET-TYPES answers what LOAD-ASSET has a route for, so EFFECT being
in it is the claim that the route exists and is wired up."
  (with-effect-content-game (game)
    (is (member 'gfx:effect (loadable-types game))
        "EFFECT is not among ~a" (loadable-types game))))

(define-native-test a-loaded-effect-is-the-class-its-type-name-names
  "**Not flattened to EFFECT.** CNA answers an opaque effect handle, but it also
answers that handle's runtime type name in full -- `cna_effect_copy_type_name'
gives \"Microsoft.Xna.Framework.Graphics.BasicEffect\" -- so a descriptor naming a
stock effect comes back as that stock effect's own class, which is what XNA's
content reader produces.

The technique count is asserted because it is the evidence that the object graph
was built from the loaded handle rather than left empty: an effect with no
technique could not apply a pass."
  (with-effect-content-game (game)
    (let ((basic (%effect-result game :basic))
          (dual (%effect-result game :dual)))
      (is (eq 'gfx:basic-effect (getf basic :class))
          "a BasicEffect descriptor loaded as ~a" (getf basic :class))
      (is (plusp (or (getf basic :techniques) 0))
          "the loaded BasicEffect had ~a technique(s)" (getf basic :techniques))
      (is (eq 'gfx:dual-texture-effect (getf dual :class))
          "a DualTextureEffect descriptor loaded as ~a" (getf dual :class))
      (is (plusp (or (getf dual :techniques) 0))))))

(define-native-test loading-one-effect-twice-answers-one-effect
  "The cache is ContentManager's, and it holds an Effect exactly as it holds a
texture or a font: the second Load answers the first object."
  (with-effect-content-game (game)
    (is-true (getf (%effect-result game :basic) :cached)
             "the second Load<Effect> answered a different object")
    (is-true (getf (%effect-result game :dual) :cached))))

(define-native-test loading-an-effect-refuses-what-is-not-one
  "A name that names nothing is an IO failure, which is what CNA documents for
\"a missing, malformed or wrongly-typed asset\". A descriptor that *is* an asset
but is a SpriteFont is the same failure and not a font: the cache is keyed by the
cleaned name and not by the type, so a wrongly-typed load has to be refused at
the loader rather than answered from somewhere else."
  (with-effect-content-game (game)
    (is (eq 'xna:cna-io-error (%effect-result game :missing))
        "a missing effect asset gave ~a" (%effect-result game :missing))
    (is (eq 'xna:cna-io-error (%effect-result game :wrong-type))
        "a SpriteFont descriptor loaded as an Effect gave ~a"
        (%effect-result game :wrong-type))))
