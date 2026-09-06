#!/bin/sh
# Audio qualification: prove both branches of the audio surface, in separate
# processes, on a machine with no speaker.
#
# **Why separate processes.** SDL's audio driver selection is process-global and
# latches when audio is first initialised, so the obvious shape --
#
#     probe available; setenv; probe unavailable
#
# inside one long-lived SBCL image does not work: the second probe answers the
# first one's driver. Each lane below is therefore its own process with its own
# environment, and that is the whole reason this script exists rather than a test.
#
# **What each lane proves, and what it does not.**
#
#   AUDIO_UNAVAILABLE            a driver that does not exist. CNA reports
#                                is_playback_available FALSE and every route that
#                                needs a device answers CNA_RESULT_NOT_SUPPORTED,
#                                which the binding raises as NO-AUDIO-HARDWARE-ERROR.
#                                Deterministic, needs no hardware, and is a
#                                *result* rather than a skipped test.
#
#   AUDIO_AVAILABLE_STATE_MACHINE  SDL's dummy driver. It still opens a device, so
#                                the whole play/pause/resume/stop state machine
#                                runs with no speaker attached. This is the lane
#                                that qualifies the available branch in CI.
#
#   AUDIO_DYNAMIC_UNAVAILABLE    the unavailable lane again, recording what the
#                                streaming constructor does there: it **succeeds**,
#                                because CNA's create route needs no device where
#                                SoundEffect's does. The refusal arrives at Play.
#                                Recorded rather than asserted away, because the two
#                                constructors genuinely differ.
#
#   AUDIO_DYNAMIC_STREAMING      the same lane and the same device, and a
#                                **different claim**. Generated PCM16 is submitted
#                                to a DynamicSoundEffectInstance, the pending
#                                buffer count is observed rising, and the native
#                                streaming state machine is observed consuming it
#                                while the game loop runs. A transport transition
#                                says nothing about whether a submitted buffer was
#                                ever taken, so this is required separately rather
#                                than read out of the line above.
#
# **A dummy audio device is not audible hardware, and no lane here is a claim
# that a sound was heard.** What is proved is that the values reached CNA, that
# CNA accepted them, and that the observable state changed where CNA exposes one.
# No test here or anywhere in this repository claims audible correctness; a
# future hardware qualification would be a different claim with different
# evidence.
#
# The ordinary environment is recorded as well, and **required to be neither**:
# whether the machine this runs on has a sound card is information, not a gate.
# A GitHub runner reports no playback device; a developer's laptop reports one.
# Making the release depend on which would make it depend on hardware.
#
#   CNA_NATIVE_LIBRARY=/abs/path/libcna_c_api.so tools/qualification/audio.sh
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

# A driver name no SDL build can have. Spelled out rather than something like
# "none", which SDL might one day accept as a real driver and quietly turn this
# lane into a second copy of the dummy one.
missing_driver=definitely-nonexistent-cna-test-driver

# A second kind of evidence out of a lane that has already run. `run_lane' checks
# the one kind that names the lane; this checks any other kind the lane has to
# have produced, against the log it left behind.
require_evidence() {
    lane=$1; kind=$2
    log="$root/build-probe/audio-$lane.log"
    if ! grep -q "^audio         : $kind -- " "$log"; then
        echo "FAIL lane $lane had to produce '$kind' evidence and did not:" >&2
        grep -E '^audio +: ' "$log" >&2 || echo "  (no audio line at all)" >&2
        exit 1
    fi
    echo "  also proved: $kind"
    echo
}

run_lane() {
    lane=$1; driver=$2; expected=$3
    log="$root/build-probe/audio-$lane.log"
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
    grep -E "^audio +: " "$log" | sed 's/^/  /' || true

    if [ -n "$expected" ]; then
        if ! grep -q "^audio         : $expected -- " "$log"; then
            echo "FAIL lane $lane had to reach the '$expected' branch and did not:" >&2
            grep -E '^audio +: ' "$log" >&2 || echo "  (no audio line at all)" >&2
            exit 1
        fi
        # And the other direction, which is what stops this passing for the wrong
        # reason: the unavailable lane must NOT have exercised the state machine,
        # and the dummy lane must NOT have fallen back to the unavailable branch.
        case "$expected" in
            unavailable)   forbidden=state-machine ;;
            state-machine) forbidden=unavailable ;;
            *)             forbidden= ;;
        esac
        if [ -n "$forbidden" ] && grep -q "^audio         : $forbidden -- " "$log"; then
            echo "FAIL lane $lane reached the '$forbidden' branch as well, so it is not" >&2
            echo "     qualifying what its name says." >&2
            exit 1
        fi
    fi
    echo "  log $log"
    echo
}

# 1. The unavailable branch, produced deterministically and with no hardware.
#    Two kinds again, and the second is a *different* fact rather than more of the
#    first: SoundEffect's constructor refuses without a device and
#    DynamicSoundEffectInstance's does not, so requiring only "unavailable" would
#    let the asymmetry go unrecorded.
run_lane unavailable "$missing_driver" unavailable
require_evidence unavailable dynamic-unavailable

# 2. The available branch, on a device with no speaker behind it. Two kinds of
#    evidence come out of this one lane and both are required: the transport's
#    state machine, and the streaming buffer queue. They are different claims --
#    a play/pause/resume/stop transition says nothing about whether a submitted
#    buffer was ever consumed -- so requiring only the first would let a broken
#    DynamicSoundEffectInstance pass behind SoundEffectInstance's evidence.
run_lane dummy dummy state-machine
require_evidence dummy dynamic-streaming

# 3. The ordinary environment, recorded and not required to be either.
echo "== lane ordinary: the environment as it is =="
ordinary_log="$root/build-probe/audio-ordinary.log"
"$here/with-virtual-screen.sh" "$sbcl" --non-interactive \
    --load "$HOME/quicklisp/setup.lisp" \
    --eval '(push (truename ".") asdf:*central-registry*)' \
    --eval '(asdf:test-system "cna-common-lisp")' > "$ordinary_log" 2>&1 || {
        echo "FAIL the suite failed in the ordinary environment; last lines:" >&2
        tail -40 "$ordinary_log" >&2
        exit 1
    }
grep -E "^(checks passed|failures|not run) " "$ordinary_log" | sed 's/^/  /'
grep -E "^audio +: " "$ordinary_log" | sed 's/^/  /' || true
if grep -q '^audio         : state-machine -- ' "$ordinary_log"; then
    echo "  this machine has a playback device"
else
    echo "  this machine has no playback device, which is not a failure"
fi
echo "  log $ordinary_log"

echo
echo "audio qualification passed"
echo "  AUDIO_UNAVAILABLE              a nonexistent driver: no device, and every"
echo "                                 route needing one refused with the"
echo "                                 XNA-visible NO-AUDIO-HARDWARE-ERROR"
echo "  AUDIO_DYNAMIC_UNAVAILABLE      the same driver: the streaming constructor"
echo "                                 succeeded anyway and took a buffer, and the"
echo "                                 refusal arrived at Play"
echo "  AUDIO_AVAILABLE_STATE_MACHINE  SDL's dummy driver: a device opened and the"
echo "                                 play/pause/resume/stop transitions were"
echo "                                 observed on it"
echo "  AUDIO_DYNAMIC_STREAMING        the same device: generated PCM16 was submitted"
echo "                                 to a DynamicSoundEffectInstance, the pending"
echo "                                 buffer count rose, and the native streaming"
echo "                                 state machine consumed it while frames ran"
echo
echo "  Not proved, and not claimed: that anything was audible. A dummy audio"
echo "  device is not a speaker, and no lane here listens to anything. The"
echo "  strongest claim the streaming lane supports is that generated PCM was"
echo "  accepted and consumed by the native streaming state machine -- not that"
echo "  a sound was heard."
