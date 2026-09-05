#!/bin/sh
# Run a command on a virtual screen, when there is a real one worth keeping off.
#
#   tools/qualification/with-virtual-screen.sh sbcl --non-interactive ...
#
# **Why this exists.** CNA's SDL3 platform initialises the host's windowing stack
# even under the HEADLESS renderer -- the GTK warnings in a test log are it doing
# so -- and the suite creates and destroys a game hundreds of times. On a
# developer's machine that is hundreds of window-system round trips against the
# desktop the developer is using. Running on an Xvfb display keeps every one of
# them off it.
#
# **What it deliberately does not do.** It does not *require* Xvfb, because the
# `Native` workflow runs with **no DISPLAY at all** and that is a property worth
# keeping: the SOFTWARE renderer is a CPU rasteriser and needs no display, and a
# lane that quietly grew a dependency on one would stop proving that. So:
#
#   DISPLAY set, xvfb-run present   -> run on a fresh Xvfb display
#   DISPLAY unset                   -> run unchanged; there is nothing to keep off
#   xvfb-run absent                 -> run unchanged, and say so once
#   CNA_LISP_NO_XVFB set            -> run unchanged, for looking at the windows
#
# The screen is 1280x800x24 because a window-system round trip does not care and
# a renderer that asks for a default size gets a plausible one.
set -eu

if [ "$#" -eq 0 ]; then
    echo "usage: with-virtual-screen.sh COMMAND [ARGUMENT...]" >&2
    exit 2
fi

if [ -n "${CNA_LISP_NO_XVFB:-}" ]; then
    exec "$@"
fi

if [ -z "${DISPLAY:-}" ]; then
    # No display to keep off: this is how CI runs, and the renderers that matter
    # there need none.
    exec "$@"
fi

if ! command -v xvfb-run >/dev/null 2>&1; then
    echo "note: xvfb-run is not installed; running against DISPLAY=$DISPLAY." >&2
    echo "      Install xvfb to keep the suite's windows off your own screen." >&2
    exec "$@"
fi

# -a picks a free server number rather than colliding with one already running.
exec xvfb-run -a --server-args="-screen 0 1280x800x24" "$@"
