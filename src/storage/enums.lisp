;;;; enums.lisp --- the three base-class-library enumerations Storage takes.
;;;;
;;;; **None of these is an XNA type.** `System.IO.FileMode', `FileAccess' and
;;;; `FileShare' belong to the base-class library, so they are not in the
;;;; selection and are not projected as types -- the same statement
;;;; `System.IO.Stream' gets. What a projection still owes is a *name* for each
;;;; value, because three `OpenFile' overloads take them, and the name is a
;;;; keyword in a table of the usual shape.
;;;;
;;;; The values are CNA's, and they are the BCL's: `CNA_FILE_MODE_CREATE_NEW' is
;;;; 1 and `System.IO.FileMode.CreateNew' is 1. A test asserts each keyword's
;;;; value against CNA's own constant, for the reason every other enumeration
;;;; here is checked rather than assumed -- `BlendFunction' is the standing
;;;; counterexample.
;;;;
;;;; **`FileShare' is a flags enumeration and is projected as one**, which is
;;;; what the header says to do rather than what its neighbours suggest.
;;;; `cna_storage_container_open_file_share' documents its parameter as "zero or
;;;; more `CNA_FILE_SHARE_*` bits" -- bits, not one identity -- and all three
;;;; admitted ABIs define six of them, `CNA_FILE_SHARE_INHERITABLE' (16)
;;;; included. So the table carries all six and combines, and a caller writes
;;;; either `:READ-WRITE' or `(:READ :WRITE)' for the same value, exactly as an
;;;; XNA caller writes `FileShare.ReadWrite' or `FileShare.Read | FileShare.Write'.
;;;; Refusing the list would have narrowed a call the original can express.
;;;;
;;;; **And CNA ignores the value.** The same header says so in as many words:
;;;; "The canonical implementation currently ignores @p file_share, so this route
;;;; differs from `cna_storage_container_open_file_access' only in which
;;;; selection the caller states explicitly." That is a behaviour limit of the
;;;; admitted ABIs, recorded in `docs/limitations.md' and repeated on `OPEN-FILE'
;;;; -- the three-keyword overload is reachable, spelled and accepted, and the
;;;; sharing it states has no effect on any of them.

(in-package #:microsoft.xna.framework.storage)

(xna::define-xna-enum file-mode
  '((:create-new     . 1)
    (:create         . 2)
    (:open           . 3)
    (:open-or-create . 4)
    (:truncate       . 5)
    (:append         . 6))
  :documentation
  "System.IO.FileMode: how `OPEN-FILE' should find or make the file.

  :CREATE-NEW      make it, and fail if it is already there
  :CREATE          make it, overwriting one that is already there
  :OPEN            open it, and fail if it is not there
  :OPEN-OR-CREATE  open it if it is there and make it otherwise
  :TRUNCATE        open it and cut it to nothing
  :APPEND          open or make it, and seek to the end before each write

A base-class-library enumeration rather than an XNA one, so it is not a projected
type; these keywords are a declared binding extension.")

(xna::define-xna-enum file-access
  '((:read       . 1)
    (:write      . 2)
    (:read-write . 3))
  :documentation
  "System.IO.FileAccess: what `OPEN-FILE' should be allowed to do with the file.

`:READ-WRITE' is 3, which is `:READ' logior `:WRITE' -- the BCL numbers it that
way and CNA gives the combination its own identity.")

(xna::define-xna-enum file-share
  '((:none        . 0)
    (:read        . 1)
    (:write       . 2)
    (:read-write  . 3)
    (:delete      . 4)
    (:inheritable . 16))
  :documentation
  "System.IO.FileShare: what another opener may do while this handle is open.

  :NONE         nobody else may open it
  :READ         another opener may read it
  :WRITE        another opener may write it
  :READ-WRITE   both, and the BCL's own name for the pair -- it is 3, which is
                :READ logior :WRITE
  :DELETE       it may be deleted while this handle is open
  :INHERITABLE  child processes inherit the handle

**A flags enumeration, and combinable**: `(:read :delete)' is as good as
`:READ-WRITE', because CNA's route takes zero or more bits -- its own words --
and XNA's caller writes `FileShare.Read | FileShare.Delete'.

Zero or more bits includes **zero**: the empty list is 0, which is `:NONE', and
so is NIL, since NIL is the empty list. That is the flags reading rather than an
oversight -- every flags enumeration in this binding takes a list and folds it
with `logior' from 0 -- and it is stated here because `:SHARE NIL' reading as *no
value given* is the mistake it could otherwise cause. There is no shape in
which `:SHARE' is absent-but-supplied: `%CHECK-OVERLOAD-KEYWORDS' decides the
overload from the keyword *set*, so supplying `:SHARE' at all names the
four-argument `OpenFile` whatever its value is. `FILE-SHARE-FROM-VALUE' answers every
member whose bits are all present, so 3 decodes as `(:READ :WRITE :READ-WRITE)' --
the honest reading of a value that really does name all three.

**CNA ignores it.** `cna_storage_container_open_file_share' says the canonical
implementation currently ignores this parameter, in every admitted ABI, so the
sharing a caller states is accepted and has no effect. That is a limitation of
the ABIs rather than of the projection; `docs/limitations.md' records it and
`OPEN-FILE' repeats it."
  :flags t)
