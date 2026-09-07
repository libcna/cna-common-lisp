#!/bin/sh
# Game's private device-event wiring, qualified by kind.
#
# **This lane qualifies a member that does not exist.** `Game::HookDeviceEvents'
# and the four handlers it installs are private in the pinned assembly, so not
# one of them is a row in the compatibility report and no scoreboard number moves
# when they work. The evidence lines below are the only record that the invariant
# holds, which is exactly why each is required by name rather than read out of
# another.
#
#   GAME_DEVICE_HOOK_INSTALLATION
#                       a constructed game had hooked nothing and a game that had
#                       run held **four** private subscriptions, on the same
#                       GraphicsDeviceManager object that Game.Services answers
#                       for IGraphicsDeviceService. Not a second event source.
#   GAME_DEVICE_CONTENT_UNLOAD
#                       a real SpriteFont **and the atlas it keeps alive** were
#                       loaded through Game.Content, and both reached their
#                       disposed state -- with the cache and the disposal list
#                       emptied -- when the graphics device manager was disposed.
#                       Not "UNLOAD was called".
#   GAME_DEVICE_CONTENT_CURRENT_REFERENCE
#                       with Game.Content reassigned from A to B, the event
#                       unloaded **B** and left A's font and atlas untouched. A
#                       handler that had closed over the manager it was installed
#                       with passes the line above and fails this one.
#   GAME_DEVICE_EVENT_ORDER
#                       a handler added before Initialize ran first, the
#                       framework's private listener second, and a handler added
#                       after Initialize third. Subscription order in one
#                       multicast list -- not "internal first" chosen because it
#                       sounded safer.
#   GAME_DEVICE_UNLOAD_FAILURE_CONTAINMENT
#                       an asset whose disposal signalled inside the
#                       device-driven unload did not unwind through the C frame,
#                       the later assets were still released, both collections
#                       were still emptied, and the original condition reached
#                       Lisp once.
#   GAME_DEVICE_PRIVATE_SUBSCRIPTION
#                       a program's own add/remove pair left the four private
#                       subscriptions in place, and Game disposal gave them back.
#   GAME_DEVICE_TEARDOWN
#                       the game was destroyed cleanly after the unload.
#
# **Nothing here claims Game.UnloadContent is called by this binding.** CNA's
# native game already drives that callback at exactly this point -- measured, and
# recorded in src/runtime/game-device-events.lisp -- so the binding supplies
# `ContentManager.Unload' alone and the pair lands in XNA's order. Calling both
# would run the program's overridable method twice for one device disposal.
#
# **Every admitted ABI is run.** Identical event headers across 0.21.0, 0.22.0
# and 0.23.0 are surface evidence only; the Storage closure established that, and
# this lane behaves accordingly rather than inferring the older two from 0.23.
#
#   tools/qualification/game-device-events.sh
#
# CNA_NATIVE_LIBRARY selects a single library instead of the admitted three.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
sbcl=${SBCL:-sbcl}

mkdir -p "$root/build-probe"
cd "$root"

# The kinds the suite must record, by the name the runner prints.
kinds='hook-installation content-unload current-reference event-order failure-containment private-subscription unhook teardown'

run_one () {
    label=$1
    library=$2
    log="$root/build-probe/game-device-events-$label.log"

    if [ ! -f "$library" ]; then
        echo "FAIL $label: $library does not exist" >&2
        return 1
    fi

    echo "== $label: $library =="
    CNA_NATIVE_LIBRARY="$library" \
    CNA_LISP_VALUEPROBE="${CNA_LISP_VALUEPROBE:-$root/build-probe/libcna-lisp-valueprobe.so}" \
    "$here/with-virtual-screen.sh" "$sbcl" --non-interactive \
        --load "$HOME/quicklisp/setup.lisp" \
        --eval '(push (truename ".") asdf:*central-registry*)' \
        --eval '(asdf:test-system "cna-common-lisp")' > "$log" 2>&1 || {
            echo "FAIL $label: the suite failed; last lines:" >&2
            tail -40 "$log" >&2
            return 1
        }

    # The ABI the run actually loaded, so a lane cannot report a version it did
    # not exercise.
    grep '^abi           :' "$log" | sed 's/^/  /' || true
    grep '^device wiring :' "$log" | sed 's/^/  /'

    missing=0
    for kind in $kinds; do
        if ! grep -q "^device wiring : $kind " "$log"; then
            echo "FAIL $label: the suite recorded no '$kind' evidence. Each kind" >&2
            echo "     is required by name: reading one of these out of another is" >&2
            echo "     what a single 'the wiring works' line would do." >&2
            missing=1
        fi
    done
    [ "$missing" -eq 0 ] || return 1
    echo "  all 8 kinds recorded"
    echo
}

failures=0

if [ -n "${CNA_NATIVE_LIBRARY:-}" ]; then
    run_one "requested" "$CNA_NATIVE_LIBRARY" || failures=$((failures + 1))
else
    for version in 0.21.0 0.22.0 0.23.0; do
        run_one "$version" "$HOME/deps/cna-c-abi-$version/libcna_c_api.so" \
            || failures=$((failures + 1))
    done
fi

if [ "$failures" -ne 0 ]; then
    echo "FAIL $failures lane(s) failed" >&2
    exit 1
fi

cat <<'EOF'
== what this run proved ==
  GAME_DEVICE_HOOK_INSTALLATION          four private subscriptions, installed by
                                         Initialize, on the service object
                                         Game.Services already answers
  GAME_DEVICE_CONTENT_UNLOAD             a real font and its atlas released, and
                                         both collections emptied, by the device
                                         event
  GAME_DEVICE_CONTENT_CURRENT_REFERENCE  the CURRENT Game.Content was the one
                                         unloaded, and the replaced one was left
                                         alone
  GAME_DEVICE_EVENT_ORDER                subscription order, with the framework's
                                         listener where Initialize put it
  GAME_DEVICE_UNLOAD_FAILURE_CONTAINMENT a signalling disposal crossed no C frame
                                         and was delivered once
  GAME_DEVICE_PRIVATE_SUBSCRIPTION       a program's -= cannot remove the
                                         framework's subscription
  GAME_DEVICE_TEARDOWN                   the game still destroyed cleanly

  Not proved, and not claimed: that this binding calls Game.UnloadContent.
  CNA's native game drives that callback itself at the same point, and the
  binding deliberately does not double it. Nor is anything here a claim about
  content *reload* after a later device re-creation: CNA drives no load-content
  for that, XNA's DeviceCreated handler would, and that is a separate hole
  recorded in docs/limitations.md rather than one this lane closes.
EOF
