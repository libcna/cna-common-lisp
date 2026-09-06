#!/bin/sh
# Media qualification: prove both branches of the song-playback surface, in
# separate processes, on a machine with no sound card.
#
# **Why separate processes.** SDL's audio driver selection is process-global and
# latches when audio is first initialised, so one long-lived SBCL image cannot
# answer for two drivers. That is the constraint `audio.sh' and `microphone.sh'
# exist for, and this is a third script rather than more lanes inside either
# because **a song is not a sound effect and not a capture device**: playback of a
# song goes through `media_player.h' routes of its own, and a run that qualified
# the sound-effect transport says nothing about whether the media player's did.
#
# **What each lane proves, and what it does not.**
#
#   MEDIA_UNAVAILABLE     a driver that does not exist. A `Song' is created
#                         **anyway** -- CNA's constructor "checks only that the
#                         file exists; it does not open or decode it" -- and the
#                         refusal arrives at `Play', wrapped the way XNA wraps a
#                         failed `Play(Song)': `InvalidOperationException' with
#                         the mapped native failure as its inner exception. That
#                         asymmetry is the same one `DynamicSoundEffectInstance'
#                         already has with `SoundEffect', and it is asserted
#                         rather than skipped.
#
#   MEDIA_PLAYBACK        SDL's dummy driver, which opens a device with no
#                         speaker behind it, so the whole transport runs: the
#                         state machine plus **the three guards XNA has and CNA
#                         has not** -- `Pause' only when playing, `Resume' only
#                         when not, `Stop' only when not stopped -- each asserted
#                         as a no-op in the state it guards against.
#
#   MEDIA_PLAY_CLOCK      the same device, and a **different claim**. The play
#                         position advances inside a justified window around the
#                         wall clock while frames run, and **stands still while
#                         paused** -- which is the half that makes it a clock
#                         rather than a counter. A transport that transitions
#                         says nothing about whether anything is being played
#                         through, so this is required separately.
#
#   MEDIA_QUEUE           the same device: `Play' clears and enqueues,
#                         `ActiveSong' answers a **fresh** object equal to its
#                         entry -- XNA's own indexer ends with
#                         `newobj Song::.ctor' -- `MoveNext' and `MovePrevious'
#                         wrap at both ends in the *managed* layer, and the
#                         active-index setter clamps where the indexer refuses.
#
#   MEDIA_EVENTS          both **static** events. XNA raises them with
#                         `handler(null, args)', so the projected handlers take no
#                         arguments at all; CNA's two subscribe routes take **no
#                         game handle**, the only ones in this ABI that do not, so
#                         a subscription is legal before any game exists and that
#                         is asserted. Removing a handler releases the native
#                         registration and stops delivery.
#
# **A dummy audio device is not a speaker, and no lane here is a claim that music
# was heard.** What is proved is that the values reached CNA, that CNA accepted
# them, that the observable state changed where CNA exposes one, and that the
# play position advanced at something like real time. The strongest claim this
# evidence supports is:
#
#     the media player CNA drives over an SDL device with no speaker behind it
#     moves through XNA's transport states, advances its play position at
#     something like the wall clock, keeps its queue in XNA's order with XNA's
#     object identity, and raises both of its static events -- and CNA-Lisp
#     reproduces the XNA semantics over that.
#
# It is **not** a claim that music was audible, that the file was decoded, or
# that a physical output device works. A hardware qualification would be a
# different claim with different evidence.
#
# The ordinary environment is recorded as well, and **required to be neither**:
# whether the machine this runs on has a sound card is information, not a gate.
#
#   CNA_NATIVE_LIBRARY=/abs/path/libcna_c_api.so tools/qualification/media.sh
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

# A driver name no SDL build can have. The same one audio.sh and microphone.sh
# use, for the same reason: something like "none" might one day become real.
missing_driver=definitely-nonexistent-cna-test-driver

require_evidence() {
    lane=$1; kind=$2
    log="$root/build-probe/media-$lane.log"
    if ! grep -q "^media         : $kind -- " "$log"; then
        echo "FAIL lane $lane had to produce '$kind' evidence and did not:" >&2
        grep -E '^media +: ' "$log" >&2 || echo "  (no media line at all)" >&2
        exit 1
    fi
    echo "  also proved: $kind"
}

run_lane() {
    lane=$1; driver=$2; expected=$3
    log="$root/build-probe/media-$lane.log"
    echo "== lane $lane: SDL_AUDIODRIVER=${driver:-<unset>} =="
    if [ -n "$driver" ]; then
        SDL_AUDIODRIVER="$driver" "$here/with-virtual-screen.sh" "$sbcl" --non-interactive \
            --load "$HOME/quicklisp/setup.lisp" \
            --eval '(push (truename ".") asdf:*central-registry*)' \
            --eval '(asdf:test-system "cna-common-lisp")' > "$log" 2>&1 || {
                echo "FAIL the suite failed in lane $lane; last lines:" >&2
                tail -40 "$log" >&2
                exit 1
            }
    else
        "$here/with-virtual-screen.sh" "$sbcl" --non-interactive \
            --load "$HOME/quicklisp/setup.lisp" \
            --eval '(push (truename ".") asdf:*central-registry*)' \
            --eval '(asdf:test-system "cna-common-lisp")' > "$log" 2>&1 || {
                echo "FAIL the suite failed in lane $lane; last lines:" >&2
                tail -40 "$log" >&2
                exit 1
            }
    fi

    grep -E "^(checks passed|failures|not run) " "$log" | sed 's/^/  /'
    grep -E "^media +: " "$log" | sed 's/^/  /' || true

    if [ -n "$expected" ]; then
        if ! grep -q "^media         : $expected -- " "$log"; then
            echo "FAIL lane $lane had to reach the '$expected' branch and did not:" >&2
            grep -E '^media +: ' "$log" >&2 || echo "  (no media line at all)" >&2
            exit 1
        fi
        # And the other direction, which is what stops this passing for the wrong
        # reason.
        case "$expected" in
            unavailable) forbidden=playback ;;
            playback)    forbidden=unavailable ;;
            *)           forbidden= ;;
        esac
        if [ -n "$forbidden" ] && grep -q "^media         : $forbidden -- " "$log"; then
            echo "FAIL lane $lane reached the '$forbidden' branch as well, so it is not" >&2
            echo "     qualifying what its name says." >&2
            exit 1
        fi
    fi
    echo "  log $log"
    echo
}

# 1. The unavailable branch, produced deterministically and with no hardware.
run_lane unavailable "$missing_driver" unavailable

# 2. The available branch. Four kinds of evidence come out of this one lane and
#    all four are required, because they are four claims: the transport, the
#    clock, the queue and the events. Requiring only the first would let a broken
#    play clock pass behind the transport's evidence.
run_lane dummy dummy playback
require_evidence dummy play-clock
require_evidence dummy queue
require_evidence dummy events
echo

# 3. The public-only consumer, in its own process under the dummy driver.
#
#    **Independent evidence, and the audit is what makes it independent.** The
#    tests reach the internal package for the two native cross-checks; this
#    proves a complete playback session needs none of it.
echo "== lane consumer: the public API alone, under SDL_AUDIODRIVER=dummy =="
consumer="$root/examples/media-consumer.lisp"
consumer_log="$root/build-probe/media-consumer.log"

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
echo "  audited: no internal package, no CFFI, no handle, no result code,"
echo "           and no private %-symbol"

SDL_AUDIODRIVER=dummy "$here/with-virtual-screen.sh" "$sbcl" --non-interactive \
    --load "$HOME/quicklisp/setup.lisp" \
    --eval '(push (truename ".") asdf:*central-registry*)' \
    --eval '(asdf:load-system "cna-common-lisp")' \
    --load "$consumer" \
    --eval '(uiop:quit (cna-lisp-media-consumer:main))' > "$consumer_log" 2>&1 || {
        echo "FAIL the public-only consumer failed; last lines:" >&2
        tail -30 "$consumer_log" >&2
        exit 1
    }
grep '^MEDIA-CONSUMER ' "$consumer_log" | sed 's/^/  /'

consumer_value() {
    sed -n "s/^MEDIA-CONSUMER $1 //p" "$consumer_log" | head -1
}
if [ "$(consumer_value state-playing)" != "PLAYING" ]; then
    echo "FAIL the consumer never reached the PLAYING state" >&2
    exit 1
fi
if [ "$(consumer_value state-paused)" != "PAUSED" ]; then
    echo "FAIL the consumer's pause did not take -- if the state is STOPPED the" >&2
    echo "     song ran to its end, which makes the run's evidence timing-dependent" >&2
    exit 1
fi
if [ "$(consumer_value state-after)" != "STOPPED" ]; then
    echo "FAIL the consumer did not leave the player stopped" >&2
    exit 1
fi
consumer_ticks=$(consumer_value position)
if [ "${consumer_ticks:-0}" -lt 1 ]; then
    echo "FAIL the consumer observed no play position, so the public API did" >&2
    echo "     not reach the play clock" >&2
    exit 1
fi
if [ "$(consumer_value queue-count)" != "2" ]; then
    echo "FAIL the consumer's queue did not hold the two songs it enqueued" >&2
    exit 1
fi
if [ "$(consumer_value done)" = "" ]; then
    echo "FAIL the consumer did not reach the end of its session" >&2
    exit 1
fi
echo "  the public API alone played a song, advanced to $consumer_ticks ticks"
echo "  and left the player stopped"
echo "  log $consumer_log"
echo

# 4. The ordinary environment, recorded and not required to be either.
echo "== lane ordinary: the environment as it is =="
ordinary_log="$root/build-probe/media-ordinary.log"
"$here/with-virtual-screen.sh" "$sbcl" --non-interactive \
    --load "$HOME/quicklisp/setup.lisp" \
    --eval '(push (truename ".") asdf:*central-registry*)' \
    --eval '(asdf:test-system "cna-common-lisp")' > "$ordinary_log" 2>&1 || {
        echo "FAIL the suite failed in the ordinary environment; last lines:" >&2
        tail -40 "$ordinary_log" >&2
        exit 1
    }
grep -E "^(checks passed|failures|not run) " "$ordinary_log" | sed 's/^/  /'
grep -E "^media +: " "$ordinary_log" | sed 's/^/  /' || true
if grep -q '^media         : playback -- ' "$ordinary_log"; then
    echo "  this machine has a playback device"
else
    echo "  this machine has no playback device, which is not a failure"
fi
echo "  log $ordinary_log"

echo
echo "media qualification passed"
echo "  MEDIA_UNAVAILABLE   a nonexistent driver: a Song was created anyway and"
echo "                      the refusal arrived at Play, wrapped as XNA wraps it"
echo "  MEDIA_PLAYBACK      SDL's dummy driver: the transport moved through"
echo "                      Playing, Paused and Stopped, and each of XNA's three"
echo "                      guards was a no-op in the state it guards against"
echo "  MEDIA_PLAY_CLOCK    the same device: the play position advanced inside a"
echo "                      justified window and stood still while paused"
echo "  MEDIA_QUEUE         the same device: Play enqueued, ActiveSong answered a"
echo "                      fresh object equal to its entry, MoveNext and"
echo "                      MovePrevious wrapped, and the setter clamped where"
echo "                      the indexer refuses"
echo "  MEDIA_EVENTS        both static events reached handlers that take no"
echo "                      arguments, needed no game to subscribe, and stopped"
echo "                      when their handlers were removed"
echo
echo "  Not proved, and not claimed: that anything was audible. A dummy audio"
echo "  device is not a speaker and no lane here listens to anything. The"
echo "  strongest claim this evidence supports is that the media player CNA"
echo "  drives over a device with no speaker behind it moves through XNA's"
echo "  transport states, advances its play position at something like the wall"
echo "  clock, keeps its queue in XNA's order with XNA's object identity, and"
echo "  raises both of its static events -- not that music was heard, that the"
echo "  file was decoded, or that a physical output device works."
