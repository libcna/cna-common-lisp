;;;; capabilities.lisp --- what CNA-Lisp claims, and what it deliberately does not.
;;;;
;;;; Introspection can tell the structural verifier which symbols exist. It
;;;; cannot tell it which absences are decisions and which are unfinished work.
;;;; That is what this file records: every deliberate absence, with the reason it
;;;; is absent and the evidence behind the reason.
;;;;
;;;; Nothing here is a claim about a member being present. A member is present
;;;; only if the image says so.

(in-package #:cna-lisp.internal)

(defparameter *binding-extensions*
  '((microsoft.xna.framework dispose disposed-p with-disposal
     "Deterministic disposal. XNA spells disposal differently on each type that
      has it, and CNA-Lisp needs one question and one operation that can be
      applied to anything holding a native resource.")
    (microsoft.xna.framework cna-error-cause
     "Where `System.Exception''s innerException constructor argument goes. Two
      selected XNA types are exception classes and each declares the CLR's
      three-constructor set; `new(String, Exception)' needs somewhere to put its
      second argument, and without this reader it had nowhere -- which would make
      that constructor one this projection cannot express rather than one it
      collapses. `System.Exception' is the base-class library's and is not
      projected as a type: a Common Lisp condition is what it projects onto, the
      same rule `System.IO.Stream' is read by.")
    (microsoft.xna.framework clr-type-name
     "The .NET type name CNA reports for a projected object, so a structural
      claim can be checked against the runtime instead of asserted.")
    (microsoft.xna.framework total-game-time-seconds elapsed-game-time-seconds
     "Seconds derived from the exact tick counts. The ticks are the value; these
      are convenience.")
    (microsoft.xna.framework predefined-color predefined-color-names
     "Reaching XNA's predefined colours by keyword, which the generated table
      makes exhaustive without 141 exported functions.")
    (microsoft.xna.framework point-equal rectangle-equal vector2-equal color-equal
     "Value equality as functions. Common Lisp has no operator overloading, so
      the == and Equals members project to named predicates.")
    (microsoft.xna.framework +bounding-frustum-plane-count+
     "The number of planes a frustum has. XNA keeps its own NumPlanes constant
      private, but the six plane readers are public, so a caller iterating them
      needs the count from somewhere other than a literal 6.")
    (microsoft.xna.framework bounding-frustum-equal
     "BoundingFrustum.Equals and op_Equality as a named predicate, for the same
      reason the value types have one: Common Lisp has no operator overloading.")
    (microsoft.xna.framework rectangle-contains-coordinates
     "Rectangle.Contains(int, int). Its three arguments cannot share a congruent
      generic function with the two-argument overloads.")
    (microsoft.xna.framework
     component-count component-at components-of add-component insert-component
     remove-component remove-component-at clear-components contains-component
     component-index
     "GameComponentCollection's own operations. XNA inherits them from
      System.Collections.ObjectModel.Collection<IGameComponent>, so the contract
      records them on the BCL type rather than on the XNA one and they are not
      members this projection can map. A collection nothing can be added to would
      be useless, so they are here, named for what they hold rather than as bare
      ADD and REMOVE -- the same reason APPLY-EFFECT-PASS is not APPLY.
      COMPONENT-INDEX answers NIL where XNA's IndexOf answers -1, because a
      position is a non-negative index and -1 is a sentinel.")
    (microsoft.xna.framework
     launch-parameter launch-parameter-names
     "LaunchParameters' own operations. XNA derives the type from
      Dictionary<string, string> and adds nothing at all, so every operation on
      one belongs to the BCL dictionary. These two are the reachable half of it:
      read a value, set or remove one, and list the names.")
    (microsoft.xna.framework.content loadable-asset-types
     "Which asset types LOAD-ASSET has a native route for. XNA's Load<T> is
      generic over any type with a content reader and needs no such list; CNA's
      ABI has one loader per asset type, so the set this binding can honour is
      finite. Naming it is better than discovering it one failure at a time.")
    (microsoft.xna.framework.graphics renderer-name
     "Which renderer is behind the device. XNA has no equivalent; without it a
      headless qualification run cannot be interpreted.")
    (microsoft.xna.framework.graphics texture-2d-from-png-bytes texture-2d-from-png-file
     "The same CNA decode route TEXTURE-2D-FROM-STREAM uses, reached from a byte
      vector and from a pathname instead of from a stream. FromStream itself is
      now projected, so these are no longer standing in for it: they are the two
      shapes a Lisp caller most often already has, and neither has an XNA member
      to be confused with.")
    (microsoft.xna.framework
     cna-error cna-native-error cna-usage-error
     cna-invalid-argument-error cna-invalid-object-error cna-invalid-state-error
     cna-out-of-memory-error cna-io-error cna-not-supported-error cna-platform-error
     cna-thread-error cna-callback-error cna-overflow-error cna-encoding-error
     cna-internal-error cna-shutting-down-error cna-buffer-too-small-error
     cna-disposed-error cna-ownership-error cna-scope-error
     cna-native-library-error cna-abi-rejected-error cna-invalid-cast-error
     cna-error-operation cna-error-native-message cna-error-object-type
     cna-abi-found-version cna-abi-admitted-versions cna-native-library-path
     cna-callback-underlying-condition
     cna-argument-error cna-argument-out-of-range-error cna-error-parameter-name
     "The condition hierarchy. XNA has exception types of its own, and they are a
      separate closure; these are the conditions a binding over a native runtime
      must have in order to report a native failure as a Lisp condition instead of
      a result code. The CNA result code behind one is deliberately not readable.")
    (microsoft.xna.framework +plane-normalize-epsilon+
     "The binary32 epsilon Plane.Normalize compares its squared length against
      before deciding to do nothing. It is a literal in the assembly rather than a
      named constant there, and naming it here is what lets a test assert the
      early exit instead of describing it.")
    (microsoft.xna.framework +ticks-per-second+ +default-target-elapsed-time-ticks+
     "The TimeSpan tick rate and XNA's default fixed step, as named constants. The
      values are part of the contract; naming them keeps them out of prose.")
    (microsoft.xna.framework color-from-packed-value
     "Constructing a Color from its packed value. XNA reaches this through the
      settable PackedValue property on a default-constructed Color; a constructor
      is the direct way to say it in Lisp.")
    (microsoft.xna.framework window-title
     "The game window's title, reached through the game in one call instead of
      two. GameWindow *is* projected now, so this is a convenience rather than the
      only route: (window-title game) and (title (window game)) read the same CNA
      title, and both read it rather than remembering it. XNA has no Game.Title,
      which is why this is declared here.")
    (microsoft.xna.framework.graphics render-target-binding-equal
     "Structural equality for RenderTargetBinding, for the reason VIEWPORT-EQUAL
      records: the XNA struct has no Equals of its own, and a projected value type
      that cannot be compared is awkward to test.")
    (microsoft.xna.framework.graphics viewport-equal
     "Structural equality for Viewport. The XNA struct has no Equals of its own,
      and a projected value type that cannot be compared is awkward to test.")
    (microsoft.xna.framework.graphics vertex-element-format-size
     "The size in bytes of one VertexElementFormat. XNA keeps the same table
      private, in VertexElementValidator.GetTypeSize, but it is what decides
      whether a VertexDeclaration is legal, so a caller laying out a vertex needs
      it from somewhere other than a literal.")
    (microsoft.xna.framework.input keyboard-get-state
     "Keyboard.GetState. Static classes project as <class>-<member> so that
      Mouse and GamePad can join the namespace without colliding.")
    (microsoft.xna.framework.media songs-vector
     "Every song in a SongCollection, as a fresh vector. XNA's collection is
      IEnumerable<Song> and a program walks it with foreach; Common Lisp has no
      IEnumerator<T> to project and the type is not in the selection, so
      GetEnumerator is declared not applicable and this is what a program uses
      instead. A vector rather than a list so that the count is O(1) and the
      elements are indexable, which is what the original's enumerator plus Count
      gives together.")
    (microsoft.xna.framework.media song-equal
     "Whether two songs are the same song, over cna_song_equals. Song is
      IEquatable<Song> and declares op_Equality, Equals(Object) and Equals(Song);
      Common Lisp has no operator overloading and one equality predicate per type
      is what those project onto, so the predicate itself is the extension and
      the three members map to it. **It is not EQ**: XNA's queue and collection
      indexers both answer `new Song(handle)', so two objects for one underlying
      song are equal and are not identical, and a program needs a way to say so.")
    (microsoft.xna.framework.media make-visualization-data
     "VisualizationData's parameterless constructor. A constructor function
      rather than MAKE-INSTANCE because the type owns nothing native and its
      whole job is to arrive with two buffers already allocated at the size CNA's
      own CNA_VISUALIZATION_DATA_SIZE names.")
    (microsoft.xna.framework.media count-of
     "The element count of a SongCollection or a MediaQueue. Named COUNT-OF
      because CL:COUNT is a standard sequence function and this package shadows
      nothing; XNA spells both Count, so the rename is this projection's and is
      declared here.")
    (microsoft.xna.framework.storage
     file-mode file-mode-value file-mode-from-value all-file-mode
     file-access file-access-value file-access-from-value all-file-access
     file-share file-share-value file-share-from-value all-file-share
     "The three `System.IO' enumerations `OpenFile' takes. **None is an XNA
      type**, so none is in the selection and none is projected as a type -- the
      same statement `System.IO.Stream' gets. What a projection still owes is a
      name for each value, because three overloads take them, and the name is a
      keyword in a table of the usual shape whose values are asserted against
      CNA's own constants. `FileShare' carries [Flags] in the BCL and is
      **combinable here**, because CNA's route documents its parameter as zero or
      more bits: `(:read :delete)' and `:read-write' are both accepted, as
      `FileShare.Read | FileShare.Delete' and `FileShare.ReadWrite' both are in
      XNA. What the sharing states has no effect on any admitted ABI, which is
      CNA's own documented limitation rather than this projection's; see
      `docs/limitations.md'.")
    (microsoft.xna.framework.storage storage-stream
     "The class of the Common Lisp stream `CreateFile' and `OpenFile' answer.
      `System.IO.Stream' is not a projected type -- it becomes an ordinary CL
      stream -- but the *class* has to be nameable so that a program can declare
      a type or specialise a method on it, which is what an ordinary CL stream
      class always is.")
    (microsoft.xna.framework.storage async-state
     "`IAsyncResult.AsyncState': the object a caller passed to a `Begin' half,
      read back from what it answered. `System.IAsyncResult' is the base-class
      library's and is not a projected type, so its interface is not projected
      either -- but the state is the one thing a caller put in and would
      otherwise have no way back to. Its three other members are constants in
      XNA (true, true, and an already-signalled wait handle) and a reader that
      answered a constant would be offering a question with one answer.")
    (microsoft.xna.framework.storage set-storage-application-name storage-root
     "Naming the directory a program's saves go in, and reading back where that
      is. **XNA has no such members and needed none**: on Windows and the Xbox
      the CLR knows the entry assembly and the framework builds a per-title root
      from it, so `StorageDevice' never had to expose the question. A Common Lisp
      image is not a title -- no entry assembly, no title id, no product name --
      so nothing derives it here, and CNA answers with two `_ext' routes. Hiding
      them would leave every program's saves in CNA's default directory with no
      way to choose another and no way to learn which one it was; the name says
      plainly that these are not XNA members.")
    (microsoft.xna.framework.media song song-collection
     "Making a Song or a SongCollection at all. **XNA has no public constructor
      for either** -- a Song comes from Song.FromUri or a MediaLibrary, and a
      SongCollection only from a MediaLibrary, an Album, an Artist or a Genre,
      and MediaLibrary is not in this closure. CNA does offer creation routes
      that take a local file path and an array of songs, so MAKE-INSTANCE over
      them is declared here: without it a program could not reach this closure at
      all, since Song.FromUri is projected but a collection would be
      unobtainable."))
  "Public symbols CNA-Lisp adds that are not XNA members, with why each exists.
The structural verifier requires every extension to appear here; an exported
symbol that is neither a mapped XNA member nor a declared extension is a
diagnostic.")

(defparameter *declared-absences*
  '((:member "Microsoft.Xna.Framework.Graphics.GraphicsDevice.Viewport.set"
     :status :partial
     :reason-code "by-value-aggregate-needs-shim"
     :reason "cna_graphics_device_set_viewport takes CNA_Viewport (24 bytes) by
              value. The System V AMD64 ABI classifies it MEMORY, which CFFI
              cannot pass without cffi-libffi -- a dependency a released CNA-Lisp
              must not have. The generator proves that refusal and emits a tiny
              private shim that takes the aggregate by pointer and the real route
              by function pointer; the setter goes through it. The shim is
              optional and not shipped prebuilt, so without CNA_LISP_SHIM the
              setter refuses with an actionable condition. See docs/native-abi.md."))
  "Absences CNA-Lisp has decided on, rather than not reached yet. Each carries the
reason it is absent; an externally blocked entry carries the evidence too.

**Every entry is checked against the generated report.** `verify.py`'s
`stale_declared_absence` requires the subject to still be absent *and* the status
here to be the status the report measures, because this table went stale in
silence once: seven of its eight entries survived the closures that answered
them, four naming something by then complete and three still calling `GameWindow`,
`ContentManager` and `Game.Content` missing after each had become partial. A
reason that has been answered is deleted rather than reworded -- Git keeps it, and
`docs/limitations.md` keeps the ones worth remembering.

The reasons for the members that are merely *not reached yet* are not here. They
live one per member in `tools/api-compat/mapping-rules.json`, which carries one
for every missing member and every partial one; this table is only for absences
that are a decision.")
