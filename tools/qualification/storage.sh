#!/bin/sh
# Storage qualification: prove both branches of the save-game surface, and prove
# that a save written by one process is there for the next one.
#
# **Why this is a script and not just the suite.** Two of the four lanes below
# cannot be run inside one image:
#
#   * the application name is **process-global** and CNA offers no way to unset
#     it, so "a process whose very first name is refused" is a state one image
#     can be in once and never again;
#   * "a save written by one process is read by another" needs two processes by
#     definition.
#
# That is the same constraint the audio, capture and playback lanes have with
# SDL's process-global driver selection, arriving from a different direction.
#
# **What each lane proves, and what it does not.**
#
#   STORAGE_NO_ROOT       a fresh process whose first application name CNA cannot
#                         build a directory from. The setter refuses on all three
#                         admitted ABIs -- which is this binding's doing, since
#                         0.21.0 accepts the name and fails later at the reader,
#                         and 0.22.0 and 0.23.0 refuse but destroy the root on
#                         their way out. Afterwards `STORAGE-ROOT' refuses, a
#                         device still selects, `IsConnected' answers **false**,
#                         and opening a container is refused. That is XNA's
#                         disconnected device, reached deterministically and
#                         asserted rather than skipped.
#
#   STORAGE_SUITE         the whole test system, with all eight kinds of storage
#                         evidence required: the root, the refusal that leaves it
#                         standing, the device selected with no game in the
#                         image, the container, the stream round trip, both sets
#                         of overload shapes, the three-deep ownership graph that
#                         refuses to cascade, and the Disposing event.
#
#   STORAGE_PERSISTENCE   two processes. The first writes a save and exits; the
#                         second, which shares nothing with it but the
#                         application name, finds the file, reads the bytes back
#                         and deletes the container. **This is the claim a
#                         single-process round trip cannot make** -- that the
#                         bytes are in the filesystem rather than in a buffer --
#                         and it is the reason the storage surface exists.
#
#   STORAGE_CONSUMER      the public-only consumer, audited mechanically for any
#                         reach into the internal package, CFFI, a handle, a
#                         result code or a private `%'-symbol. The tests use one
#                         internal cross-check on purpose; this proves a complete
#                         save-and-load session needs none of it, **and needs no
#                         `GAME'**, which no other consumer in this repository
#                         can say.
#
# **No lane here is a claim about durability.** Bytes that survive a process
# boundary have reached the filesystem. They have not survived a power cut, a
# full disk, or a filesystem that lies about `fsync', and nothing below implies
# that they would. The strongest claim this evidence supports is:
#
#     a save file written through CNA-Lisp's public API is on the filesystem
#     under a root the program named, is found and read back by a different
#     process, and the three-deep device/container/stream graph opens and closes
#     in the order CNA requires -- and CNA-Lisp reproduces the XNA semantics over
#     that.
#
#   CNA_NATIVE_LIBRARY=/abs/path/libcna_c_api.so tools/qualification/storage.sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
sbcl=${SBCL:-sbcl}

if [ -z "${CNA_NATIVE_LIBRARY:-}" ]; then
    echo "CNA_NATIVE_LIBRARY must name a qualified CNA C ABI library" >&2
    exit 2
fi

mkdir -p "$root/build-probe"
cd "$root"

# An application name CNA cannot build a directory from, on any admitted ABI: an
# absolute path into a filesystem that does not take directories.
unusable_name=/proc/cna-lisp-storage-cannot-be-created

# The application name the persistence lane's two processes share. It is not the
# suite's, so a failed run of one cannot confuse the other.
persist_name=CnaLispStoragePersistence

lisp() {
    "$sbcl" --non-interactive \
        --load "$HOME/quicklisp/setup.lisp" \
        --eval '(push (truename ".") asdf:*central-registry*)' \
        --eval '(asdf:load-system "cna-common-lisp")' "$@"
}

# ---------------------------------------------------------------------------
# 1. The no-root branch, in a process that has never had a usable name.
# ---------------------------------------------------------------------------
echo "== lane no-root: a first application name CNA cannot use =="
no_root_log="$root/build-probe/storage-no-root.log"

cat > "$root/build-probe/storage-no-root.lisp" <<'LISP'
(defpackage #:cna-lisp-storage-no-root
  (:use #:cl)
  (:local-nicknames (#:xna #:microsoft.xna.framework)
                    (#:storage #:microsoft.xna.framework.storage)))
(in-package #:cna-lisp-storage-no-root)

(defun report (key control &rest arguments)
  (format t "~&NO-ROOT ~a ~?~%" key control arguments)
  (finish-output))

(defun main ()
  (let ((name (second sb-ext:*posix-argv*)))
    ;; The very first storage call this process makes, and it must be refused.
    (report "set" "~a"
            (handler-case (progn (storage:set-storage-application-name name)
                                 "ACCEPTED")
              (xna:cna-invalid-state-error () "REFUSED")
              (error (e) (format nil "OTHER ~a" (type-of e)))))
    (report "root" "~a"
            (handler-case (format nil "NAMED ~s" (storage:storage-root))
              (xna:cna-invalid-state-error () "REFUSED")
              (error (e) (format nil "OTHER ~a" (type-of e)))))
    ;; A device still selects -- XNA's StorageDevice is not the filesystem -- and
    ;; it reports itself disconnected, which is the whole point of the branch.
    (let ((device (storage:storage-device-end-show-selector
                   (storage:storage-device-begin-show-selector nil nil))))
      (unwind-protect
           (progn
             (report "connected" "~a"
                     (if (storage:is-connected device) "yes" "no"))
             (report "open-container" "~a"
                     (handler-case
                         (progn (storage:end-open-container
                                 device
                                 (storage:begin-open-container
                                  device "Anything" nil nil))
                                "ACCEPTED")
                       (error (e) (format nil "REFUSED ~a" (type-of e))))))
        (xna:dispose device)))
    ;; And an accepted name repairs the process, which is what makes this a
    ;; branch rather than a wound.
    (storage:set-storage-application-name "CnaLispStorageNoRootRepair")
    (report "repaired" "~s" (storage:storage-root))
    (report "done" "the no-root branch is what it says")
    0))
LISP

lisp --load "$root/build-probe/storage-no-root.lisp" \
     --eval '(uiop:quit (cna-lisp-storage-no-root::main))' \
     "$unusable_name" > "$no_root_log" 2>&1 || {
        echo "FAIL the no-root lane failed; last lines:" >&2
        tail -30 "$no_root_log" >&2
        exit 1
     }
grep '^NO-ROOT ' "$no_root_log" | sed 's/^/  /'

no_root_value() { sed -n "s/^NO-ROOT $1 //p" "$no_root_log" | head -1; }
for pair in "set REFUSED" "root REFUSED" "connected no"; do
    key=${pair%% *}; want=${pair#* }
    got=$(no_root_value "$key")
    if [ "$got" != "$want" ]; then
        echo "FAIL the no-root lane's '$key' had to be '$want' and was '$got'" >&2
        exit 1
    fi
done
case "$(no_root_value open-container)" in
    REFUSED*) : ;;
    *) echo "FAIL a container opened on a device with no storage root" >&2; exit 1 ;;
esac
if [ -z "$(no_root_value repaired)" ]; then
    echo "FAIL an accepted application name did not repair the process" >&2
    exit 1
fi
rmdir "$HOME/.local/share/CnaLispStorageNoRootRepair" 2>/dev/null || true
echo "  log $no_root_log"
echo

# ---------------------------------------------------------------------------
# 2. The suite, with every kind of storage evidence required.
# ---------------------------------------------------------------------------
echo "== lane suite: the whole test system =="
suite_log="$root/build-probe/storage-suite.log"
"$here/with-virtual-screen.sh" "$sbcl" --non-interactive \
    --load "$HOME/quicklisp/setup.lisp" \
    --eval '(push (truename ".") asdf:*central-registry*)' \
    --eval '(asdf:test-system "cna-common-lisp")' > "$suite_log" 2>&1 || {
        echo "FAIL the suite failed; last lines:" >&2
        tail -40 "$suite_log" >&2
        exit 1
    }
grep -E "^(checks passed|failures|not run) " "$suite_log" | sed 's/^/  /'
grep -E "^storage +: " "$suite_log" | sed 's/^/  /' || true

for kind in root no-root device container stream overloads ownership events; do
    if ! grep -q "^storage       : $kind -- " "$suite_log"; then
        echo "FAIL the suite had to produce '$kind' evidence and did not:" >&2
        grep -E '^storage +: ' "$suite_log" >&2 || echo "  (no storage line at all)" >&2
        exit 1
    fi
done
echo "  all eight kinds of storage evidence were produced"
echo "  log $suite_log"
echo

# ---------------------------------------------------------------------------
# 3. Persistence across a process boundary.
# ---------------------------------------------------------------------------
echo "== lane persistence: one process writes, another reads =="
write_log="$root/build-probe/storage-persist-write.log"
read_log="$root/build-probe/storage-persist-read.log"

cat > "$root/build-probe/storage-persist.lisp" <<'LISP'
(defpackage #:cna-lisp-storage-persist
  (:use #:cl)
  (:local-nicknames (#:xna #:microsoft.xna.framework)
                    (#:storage #:microsoft.xna.framework.storage)))
(in-package #:cna-lisp-storage-persist)

(defparameter *payload* "a save written by another process")

(defun report (key control &rest arguments)
  (format t "~&PERSIST ~a ~?~%" key control arguments)
  (finish-output))

(defmacro with-container ((container name application) &body body)
  `(progn
     (storage:set-storage-application-name ,application)
     (report "root" "~s" (storage:storage-root))
     (let ((device (storage:storage-device-end-show-selector
                    (storage:storage-device-begin-show-selector nil nil))))
       (unwind-protect
            (let ((,container (storage:end-open-container
                               device
                               (storage:begin-open-container device ,name nil nil))))
              (unwind-protect (progn ,@body)
                (xna:dispose ,container)))
         (xna:dispose device)))))

(defun write-phase (application)
  (with-container (container "SaveGames" application)
    (with-open-stream (stream (storage:open-file container "slot1.sav"
                                                 :mode :create :access :write))
      (write-sequence (map '(vector (unsigned-byte 8)) #'char-code *payload*)
                      stream))
    (report "wrote" "~d bytes" (length *payload*)))
  (report "done" "the writing process is exiting")
  0)

(defun read-phase (application)
  (let ((text nil))
    (with-container (container "SaveGames" application)
      (report "exists" "~a" (if (storage:file-exists container "slot1.sav") "yes" "no"))
      (report "listed" "~s" (coerce (storage:get-file-names container) 'list))
      (with-open-stream (stream (storage:open-file container "slot1.sav"
                                                   :mode :open :access :read))
        (let* ((length (file-position stream :end))
               (buffer (make-array length :element-type '(unsigned-byte 8))))
          (file-position stream 0)
          (setf text (map 'string #'code-char
                          (subseq buffer 0 (read-sequence buffer stream))))))
      (report "read" "~s" text)
      (report "matches" "~a" (if (string= text *payload*) "yes" "no"))
      (storage:delete-file container "slot1.sav"))
    ;; and remove the container itself, so the lane leaves nothing behind
    (let ((device (storage:storage-device-end-show-selector
                   (storage:storage-device-begin-show-selector nil nil))))
      (unwind-protect (storage:delete-container device "SaveGames")
        (xna:dispose device)))
    (report "done" "the reading process is exiting")
    (if (string= text *payload*) 0 1)))
LISP

lisp --load "$root/build-probe/storage-persist.lisp" \
     --eval "(uiop:quit (cna-lisp-storage-persist::write-phase \"$persist_name\"))" \
     > "$write_log" 2>&1 || {
        echo "FAIL the writing process failed; last lines:" >&2
        tail -30 "$write_log" >&2
        exit 1
     }
grep '^PERSIST ' "$write_log" | sed 's/^/  write: /'

lisp --load "$root/build-probe/storage-persist.lisp" \
     --eval "(uiop:quit (cna-lisp-storage-persist::read-phase \"$persist_name\"))" \
     > "$read_log" 2>&1 || {
        echo "FAIL the reading process did not find what the writer left; last lines:" >&2
        tail -30 "$read_log" >&2
        exit 1
     }
grep '^PERSIST ' "$read_log" | sed 's/^/  read:  /'

if [ "$(sed -n 's/^PERSIST matches //p' "$read_log" | head -1)" != "yes" ]; then
    echo "FAIL the second process read something other than what the first wrote" >&2
    exit 1
fi
if [ "$(sed -n 's/^PERSIST exists //p' "$read_log" | head -1)" != "yes" ]; then
    echo "FAIL the second process did not find the save file at all" >&2
    exit 1
fi
rmdir "$HOME/.local/share/$persist_name" 2>/dev/null || true
echo "  a save crossed a process boundary intact"
echo "  logs $write_log $read_log"
echo

# ---------------------------------------------------------------------------
# 4. The public-only consumer.
# ---------------------------------------------------------------------------
echo "== lane consumer: the public API alone, and no game at all =="
consumer="$root/examples/storage-consumer.lisp"
consumer_log="$root/build-probe/storage-consumer.log"

code=$(sed 's/;.*$//' "$consumer")
audit() {
    pattern=$1; what=$2
    if printf '%s\n' "$code" | grep -qiE -- "$pattern"; then
        echo "FAIL $consumer uses $what, so it is not public-only and proves" >&2
        echo "     nothing about the public API:" >&2
        printf '%s\n' "$code" | grep -niE -- "$pattern" >&2
        exit 1
    fi
}
audit 'cna-lisp\.internal'   "the internal package"
audit 'cffi'                 "CFFI"
audit 'handle-of'            "a native handle"
audit 'check-result'         "a CNA result code"
audit 'defcfun|foreign-'     "a foreign definition"
audit '(^|[( :])%[a-z]'      "a private %-symbol"
# The claim this consumer makes that no other one can: it never constructs a game.
if printf '%s\n' "$code" | grep -qE "make-instance +'xna:game|make-instance +\(quote xna:game\)"; then
    echo "FAIL $consumer constructs a GAME, so it does not show that the storage" >&2
    echo "     surface needs none." >&2
    exit 1
fi
echo "  audited: no internal package, no CFFI, no handle, no result code,"
echo "           no private %-symbol -- and no GAME"

lisp --load "$consumer" \
     --eval '(uiop:quit (cna-lisp-storage-consumer:main))' > "$consumer_log" 2>&1 || {
        echo "FAIL the public-only consumer failed; last lines:" >&2
        tail -30 "$consumer_log" >&2
        exit 1
     }
grep '^STORAGE-CONSUMER ' "$consumer_log" | sed 's/^/  /'

consumer_value() { sed -n "s/^STORAGE-CONSUMER $1 //p" "$consumer_log" | head -1; }
if [ "$(consumer_value callback)" != "before-begin-returned" ]; then
    echo "FAIL the consumer's callback did not run before Begin returned" >&2
    exit 1
fi
if [ "$(consumer_value read)" != '"level=7 score=4200 name=Robert"' ]; then
    echo "FAIL the consumer did not read back what it wrote:" >&2
    echo "     $(consumer_value read)" >&2
    exit 1
fi
if [ "$(consumer_value emptied)" != "files=0 directories=0" ]; then
    echo "FAIL the consumer did not empty its container" >&2
    exit 1
fi
if [ -z "$(consumer_value done)" ]; then
    echo "FAIL the consumer did not reach the end of its session" >&2
    exit 1
fi
rmdir "$HOME/.local/share/CnaLispStorageConsumer" 2>/dev/null || true
echo "  log $consumer_log"

echo
echo "storage qualification passed"
echo "  STORAGE_NO_ROOT      a first application name CNA cannot build a"
echo "                       directory from was refused on this ABI, the root"
echo "                       stayed unnamed, IsConnected answered false, and"
echo "                       opening a container was refused"
echo "  STORAGE_SUITE        all eight kinds of storage evidence: the root, the"
echo "                       refusal that leaves it standing, a device selected"
echo "                       with no game, the container, the stream round trip,"
echo "                       both sets of overload shapes, the three-deep"
echo "                       ownership graph that refuses to cascade, and the"
echo "                       Disposing event"
echo "  STORAGE_PERSISTENCE  a save written by one process was found and read"
echo "                       back byte for byte by another"
echo "  STORAGE_CONSUMER     a complete save-and-load session through the public"
echo "                       API alone, with no GAME in the image"
echo
echo "  Not proved, and not claimed: durability. Bytes that cross a process"
echo "  boundary have reached the filesystem; they have not survived a power"
echo "  cut, a full disk, or a filesystem that lies about fsync. The strongest"
echo "  claim this evidence supports is that a save written through the public"
echo "  API is on the filesystem under a root the program named, is read back by"
echo "  a different process, and that the device/container/stream graph opens"
echo "  and closes in the order CNA requires."
