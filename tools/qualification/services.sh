#!/bin/sh
# Game services and device selection, qualified by kind.
#
# **Seven kinds of evidence and they are seven claims**, for the same reason the
# audio, capture, media and storage lanes each keep theirs apart:
#
#   SERVICES_MANAGED      an arbitrary type-keyed container: user-defined service
#                         types CNA has no identity for were added, read back by
#                         identity, removed one at a time and re-added with a
#                         different provider -- with no native route involved.
#                         **This is the lane that says the container is XNA's and
#                         not a projection of CNA's two slots.**
#   SERVICES_CANONICAL    a GraphicsDeviceManager registered itself under both
#                         IGraphicsDeviceManager and IGraphicsDeviceService, both
#                         keys answered one object, and CNA's own
#                         cna_game_services_contains_ext agreed about both.
#   SERVICES_CONTENT      both canonical ContentManager constructors resolved a
#                         graphics device through the IServiceProvider protocol,
#                         and ServiceProvider answered the exact object each was
#                         given.
#   DEVICE_INFORMATION    GraphicsDeviceInformation answered a GraphicsAdapter
#                         rather than CNA's adapter index, and Clone, Equals and
#                         the Adapter setter's own defect matched the pinned IL.
#   PREPARING_DEVICE_SETTINGS
#                         a handler changed a discriminating setting and **the
#                         device CNA then made reflected the change**, with the
#                         no-handler and handler-removed passes asserted beside
#                         it. Not "a callback ran".
#   GDM_VIRTUAL_EVENTS    a subclass overriding a protected On* method saw the
#                         public event raised with CALL-NEXT-METHOD and
#                         suppressed without it.
#   SERVICES_CONSUMER     the whole flow through the two exported packages alone,
#                         audited mechanically for any reach into the internal
#                         package, CFFI, a handle, a result code or a private
#                         `%'-symbol -- and driving the manager through the
#                         *interface* it was retrieved under rather than through
#                         its concrete class.
#
# **No lane here claims that the device-selection virtuals influence device
# creation.** FindBestDevice, RankDevices and CanResetDevice answer XNA's
# semantics when called, and no admitted CNA ABI calls them: all three are
# `virtual' in CNA's own C++ with no call site in GraphicsDeviceManager.cpp, and
# none is exposed as a C route. The suite asserts that a real ApplyChanges and a
# real CreateDevice call none of them, which is why all three are reported
# partial rather than complete.
#
# This closure needs **no display, no GPU, no audio device and no content
# fixture**: everything it does is lifecycle and configuration.
#
#   CNA_NATIVE_LIBRARY=/abs/path/libcna_c_api.so tools/qualification/services.sh
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

lisp() {
    "$here/with-virtual-screen.sh" "$sbcl" --non-interactive \
        --load "$HOME/quicklisp/setup.lisp" \
        --eval '(push (truename ".") asdf:*central-registry*)' \
        --eval '(asdf:load-system "cna-common-lisp")' "$@"
}

# ---------------------------------------------------------------------------
# 1. The suite's own six kinds of evidence.
# ---------------------------------------------------------------------------
echo "== lane suite: the six kinds the suite records =="
suite_log="$root/build-probe/services-suite.log"

"$here/with-virtual-screen.sh" "$sbcl" --non-interactive \
    --load "$HOME/quicklisp/setup.lisp" \
    --eval '(push (truename ".") asdf:*central-registry*)' \
    --eval '(asdf:test-system "cna-common-lisp")' > "$suite_log" 2>&1 || {
        echo "FAIL the suite failed; last lines:" >&2
        tail -40 "$suite_log" >&2
        exit 1
    }
grep '^services      :' "$suite_log" | sed 's/^/  /'

for kind in managed canonical content device-information \
            preparing-device-settings virtual-events device-selection; do
    if ! grep -q "^services      : $kind " "$suite_log"; then
        echo "FAIL the suite recorded no '$kind' evidence. Each kind is required by" >&2
        echo "     name: reading one of these out of another is exactly what a single" >&2
        echo "     'device settings work' line would do." >&2
        exit 1
    fi
done
echo "  all seven kinds recorded"

# The mutation lane's own number, so that a run cannot report the kind without
# the discriminating value behind it.
if ! grep -q '^services      : preparing-device-settings .*1234x567' "$suite_log"; then
    echo "FAIL the device-settings lane did not report the mutated back buffer," >&2
    echo "     so nothing here says the handler's write reached the device." >&2
    exit 1
fi
echo "  the device-settings lane reported the mutated back buffer"

# ---------------------------------------------------------------------------
# 2. The public-only consumer.
# ---------------------------------------------------------------------------
echo "== lane consumer: the public API alone, driven through the interface =="
consumer="$root/examples/services-consumer.lisp"
consumer_log="$root/build-probe/services-consumer.log"

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
echo "           no private %-symbol"

lisp --load "$consumer" \
     --eval '(uiop:quit (cna-lisp-services-consumer:main))' > "$consumer_log" 2>&1 || {
        echo "FAIL the public-only consumer failed; last lines:" >&2
        tail -30 "$consumer_log" >&2
        exit 1
     }
grep '^SERVICES-CONSUMER ' "$consumer_log" | sed 's/^/  /'

consumer_value() { sed -n "s/^SERVICES-CONSUMER $1 //p" "$consumer_log" | head -1; }

check() {
    what=$1; expected=$2; actual=$(consumer_value "$what")
    if [ "$actual" != "$expected" ]; then
        echo "FAIL the consumer's '$what' line was:" >&2
        echo "       $actual" >&2
        echo "     and the lane requires:" >&2
        echo "       $expected" >&2
        exit 1
    fi
}
check container   "same-object"
check custom      "round-tripped score=4200"
check both-keys   "one-object"
check interface   "create=ok begin-draw=true end-draw=ok"
# The discriminating number: the handler asked for 1280x720 and the device took
# it. A consumer that only proved the callback ran would print calls=1 and a
# back buffer of whatever CNA proposed.
check settings    "calls=1 back-buffer=1280x720"
check content     'provider=same-object root="Content"'
check game-content "same-object"
check removed     "service=gone manager=kept custom=kept"
if [ -z "$(consumer_value done)" ]; then
    echo "FAIL the consumer did not reach the end of its session" >&2
    exit 1
fi
echo "  log $consumer_log"

echo
echo "services qualification passed"
echo "  SERVICES_MANAGED     an arbitrary type-keyed container: service types CNA"
echo "                       has no identity for were added, read back by"
echo "                       identity, removed and re-added, with no native route"
echo "                       involved at any point"
echo "  SERVICES_CANONICAL   the manager registered under both interface keys,"
echo "                       both answered one object, and CNA's own"
echo "                       cna_game_services_contains_ext agreed"
echo "  SERVICES_CONTENT     both canonical ContentManager constructors resolved"
echo "                       through the IServiceProvider protocol and preserved"
echo "                       the provider's identity"
echo "  DEVICE_INFORMATION   an adapter object rather than an index, and Clone,"
echo "                       Equals and the Adapter setter matched the pinned IL"
echo "  PREPARING_DEVICE_SETTINGS"
echo "                       a handler's write reached the device CNA made, with"
echo "                       the no-handler and handler-removed passes asserted"
echo "                       beside it"
echo "  GDM_VIRTUAL_EVENTS   a protected On* override raised the public event with"
echo "                       CALL-NEXT-METHOD and suppressed it without"
echo "  SERVICES_CONSUMER    the whole flow through the public API alone, with the"
echo "                       manager driven through the interface it was retrieved"
echo "                       under"
echo
echo "  Not proved, and not claimed: that FindBestDevice, RankDevices or"
echo "  CanResetDevice influences device creation. All three answer XNA's"
echo "  semantics when called and no admitted CNA ABI calls them, which the"
echo "  suite asserts directly and which is why all three are partial. Nothing"
echo "  here is a claim about a physical display either: this closure needs"
echo "  none, and the back-buffer sizes above are configuration rather than"
echo "  pixels."
