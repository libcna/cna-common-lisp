#!/bin/sh
# Microphone qualification: prove both branches of the capture surface, in
# separate processes, on a machine with no microphone.
#
# **Why separate processes.** SDL's audio driver selection is process-global and
# latches when audio is first initialised, so one long-lived SBCL image cannot
# answer for two drivers. This is the same constraint `audio.sh' exists for, and
# capture is a separate lane rather than two more kinds inside that one because
# **playback and capture are different devices behind different CNA routes**: a
# machine may have a speaker and no microphone or a microphone and no speaker,
# and a script that read one out of the other would let either be reported as the
# other.
#
# **What each lane proves, and what it does not.**
#
#   MICROPHONE_UNAVAILABLE       a driver that does not exist. CNA enumerates no
#                                capture device, `Microphone.All' answers the
#                                empty list and `Microphone.Default' answers NIL.
#                                `audio.h' calls a count of zero "an ordinary
#                                answer", so this is a *result* and not a skipped
#                                test -- and it is what a machine with no
#                                microphone really does.
#
#   MICROPHONE_ENUMERATION       SDL's dummy driver, which enumerates capture
#                                devices. Their **object identity** is what this
#                                lane is for: `All[i]' is the same object on every
#                                query, the returned list is fresh so a caller
#                                cannot reach the cache through it, and `Default'
#                                is EQ to an entry in `All' rather than a second
#                                object with equal slots. Also the four stored
#                                properties, and the .NET type name CNA reports
#                                for the type.
#
#   MICROPHONE_CAPTURE_STATE_MACHINE
#                                the same devices: `Start', `Stop' and `State',
#                                including what a **repeated** call of either
#                                does. XNA's IL contains no idempotence rule to
#                                reproduce -- both members are the bare native
#                                call -- so this measures CNA's answer through
#                                XNA's shape rather than inferring one.
#
#   MICROPHONE_CAPTURE_DATA      the same devices: `GetData' wrote captured PCM16
#                                into **exactly the range it reported** and left
#                                every byte outside that range unchanged, and the
#                                byte count advanced at the rate the device's own
#                                `SampleRate' implies. A short read is success,
#                                including a read of zero bytes.
#
#   MICROPHONE_BUFFER_READY      the same devices, and a **different claim**. The
#                                BufferReady event arrived, its sender was EQ to
#                                the object `All' and `Default' hand out, removing
#                                the handler released the native registration and
#                                stopped delivery, and the callback registry
#                                returned to its baseline. That a stream advances
#                                says nothing about the event that announces it,
#                                so this is required separately rather than read
#                                out of the line above.
#
# **A dummy capture device is not a microphone, and no lane here is a claim that
# a sound was captured.** Every byte SDL's dummy backend produces is zero. The
# strongest claim this script's evidence supports is:
#
#     the native capture device enumerated by the SDL dummy backend advances its
#     PCM16 capture stream at the reported sample rate, and CNA-Lisp reproduces
#     the XNA state, buffer and event semantics over that stream.
#
# It is **not** a claim that microphone audio is correct, that speech was
# captured, or that a physical microphone works. A hardware qualification would
# be a different claim with different evidence.
#
# The ordinary environment is recorded as well, and **required to be neither**:
# whether the machine this runs on has a capture device is information, not a
# gate. A GitHub runner has none; a developer's laptop has several.
#
#   CNA_NATIVE_LIBRARY=/abs/path/libcna_c_api.so tools/qualification/microphone.sh
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

# A driver name no SDL build can have, spelled out rather than something like
# "none" which SDL might one day accept and quietly turn this lane into a second
# copy of the dummy one. The same name audio.sh uses, for the same reason.
missing_driver=definitely-nonexistent-cna-test-driver

require_evidence() {
    lane=$1; kind=$2
    log="$root/build-probe/microphone-$lane.log"
    if ! grep -q "^microphone    : $kind -- " "$log"; then
        echo "FAIL lane $lane had to produce '$kind' evidence and did not:" >&2
        grep -E '^microphone +: ' "$log" >&2 || echo "  (no microphone line at all)" >&2
        exit 1
    fi
    echo "  also proved: $kind"
}

run_lane() {
    lane=$1; driver=$2; expected=$3
    log="$root/build-probe/microphone-$lane.log"
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
    grep -E "^microphone +: " "$log" | sed 's/^/  /' || true

    if [ -n "$expected" ]; then
        if ! grep -q "^microphone    : $expected -- " "$log"; then
            echo "FAIL lane $lane had to reach the '$expected' branch and did not:" >&2
            grep -E '^microphone +: ' "$log" >&2 || echo "  (no microphone line at all)" >&2
            exit 1
        fi
        # And the other direction, which is what stops this passing for the wrong
        # reason: the unavailable lane must not have enumerated a device, and the
        # dummy lane must not have fallen back to the unavailable branch.
        case "$expected" in
            unavailable) forbidden=enumeration ;;
            enumeration) forbidden=unavailable ;;
            *)           forbidden= ;;
        esac
        if [ -n "$forbidden" ] && grep -q "^microphone    : $forbidden -- " "$log"; then
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
#    all four are required, because they are four claims: that devices enumerate
#    with the right identity, that the capture state machine moves, that PCM
#    arrives in exactly the range GetData reports, and that the event announcing
#    it reaches the right object. Requiring only the first would let a broken
#    GetData pass behind the enumeration's evidence.
run_lane dummy dummy enumeration
require_evidence dummy capture-state-machine
require_evidence dummy capture-data
require_evidence dummy buffer-ready
echo

# 3. The ordinary environment, recorded and not required to be either.
echo "== lane ordinary: the environment as it is =="
ordinary_log="$root/build-probe/microphone-ordinary.log"
"$here/with-virtual-screen.sh" "$sbcl" --non-interactive \
    --load "$HOME/quicklisp/setup.lisp" \
    --eval '(push (truename ".") asdf:*central-registry*)' \
    --eval '(asdf:test-system "cna-common-lisp")' > "$ordinary_log" 2>&1 || {
        echo "FAIL the suite failed in the ordinary environment; last lines:" >&2
        tail -40 "$ordinary_log" >&2
        exit 1
    }
grep -E "^(checks passed|failures|not run) " "$ordinary_log" | sed 's/^/  /'
grep -E "^microphone +: " "$ordinary_log" | sed 's/^/  /' || true
if grep -q '^microphone    : enumeration -- ' "$ordinary_log"; then
    echo "  this machine has a capture device"
else
    echo "  this machine has no capture device, which is not a failure"
fi
echo "  log $ordinary_log"

# 4. The public-only consumer, in its own process under the dummy driver.
#
#    **Independent evidence, and the audit is what makes it independent.** The
#    tests reach two private symbols -- a device index, to cross-check CNA's own
#    routes, and a cache reset, so one image can observe a first enumeration
#    twice -- and both are legitimate for a test and unavailable to a program.
#    This proves neither is *needed*: a complete capture session runs through the
#    two exported packages alone. The audit below is mechanical rather than a
#    reading, because a claim about what a file uses that nobody re-checks is a
#    claim that rots.
echo "== lane consumer: the public API alone, under SDL_AUDIODRIVER=dummy =="
consumer="$root/examples/microphone-consumer.lisp"
consumer_log="$root/build-probe/microphone-consumer.log"

# Each pattern is an extended regexp matched against the file with its comment
# lines removed, so that this file's own prose about what it must not use cannot
# trip it. The private-symbol pattern looks for a `%' that begins a token --
# `(%foo', ` %foo', `::%foo' -- rather than any `%' at all, because `~%' is a
# format directive and matching it made this audit fire on its own report line.
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
    --eval '(uiop:quit (cna-lisp-microphone-consumer:main))' > "$consumer_log" 2>&1 || {
        echo "FAIL the public-only consumer failed; last lines:" >&2
        tail -30 "$consumer_log" >&2
        exit 1
    }
grep '^MICROPHONE-CONSUMER ' "$consumer_log" | sed 's/^/  /'

# What the consumer had to prove, checked rather than printed. A consumer that
# had quietly stopped capturing would still have printed a line for each key.
consumer_value() {
    sed -n "s/^MICROPHONE-CONSUMER $1 //p" "$consumer_log" | head -1
}
consumer_count=$(consumer_value count)
if [ "${consumer_count:-0}" -lt 1 ]; then
    echo "FAIL the consumer enumerated no capture device under the dummy driver" >&2
    exit 1
fi
if [ "$(consumer_value default-in-all)" != "yes" ]; then
    echo "FAIL the consumer's Default was not one of the objects All answered" >&2
    exit 1
fi
if [ "$(consumer_value state-after)" != "STOPPED" ]; then
    echo "FAIL the consumer did not leave the device stopped" >&2
    exit 1
fi
consumer_bytes=$(consumer_value bytes)
if [ "${consumer_bytes:-0}" -lt 1 ]; then
    echo "FAIL the consumer captured no bytes, so the public API did not reach" >&2
    echo "     the capture stream" >&2
    exit 1
fi
if [ "$(consumer_value done)" = "" ]; then
    echo "FAIL the consumer did not reach the end of its session" >&2
    exit 1
fi
echo "  the public API alone enumerated $consumer_count device(s), captured"
echo "  $consumer_bytes byte(s) and left the device stopped"
echo "  log $consumer_log"
echo

echo
echo "microphone qualification passed"
echo "  MICROPHONE_UNAVAILABLE            a nonexistent driver: no capture device"
echo "                                    enumerated, All answered the empty list"
echo "                                    and Default answered NIL"
echo "  MICROPHONE_ENUMERATION            SDL's dummy driver: devices enumerated,"
echo "                                    All answered the same objects on every"
echo "                                    query, and Default was EQ to one of them"
echo "  MICROPHONE_CAPTURE_STATE_MACHINE  the same devices: Start, Stop and State"
echo "                                    transitioned, and a repeated call of"
echo "                                    either was accepted without moving it"
echo "  MICROPHONE_CAPTURE_DATA           the same devices: GetData wrote captured"
echo "                                    PCM16 into exactly the range it reported,"
echo "                                    left every byte outside it unchanged, and"
echo "                                    advanced at the reported sample rate"
echo "  MICROPHONE_BUFFER_READY           the same devices: BufferReady arrived with"
echo "                                    the right sender, removing the handler"
echo "                                    released the registration and stopped"
echo "                                    delivery, and the registry came back"
echo
echo "  Not proved, and not claimed: that anything was captured. SDL's dummy"
echo "  capture backend produces silence -- every byte zero -- and no lane here"
echo "  listens to anything. The strongest claim this evidence supports is that"
echo "  the native capture device enumerated by the SDL dummy backend advances its"
echo "  PCM16 capture stream at the reported sample rate, and that CNA-Lisp"
echo "  reproduces the XNA state, buffer and event semantics over that stream."
echo "  It is not a claim that microphone audio is correct, that speech was"
echo "  captured, or that a physical microphone works."
