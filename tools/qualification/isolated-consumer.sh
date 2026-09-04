#!/bin/sh
# Isolated consumer qualification.
#
# Build a deterministic source artifact of CNA-Lisp, extract it somewhere clean,
# and run the template against *that* -- with a source registry that names the
# artifact and the template and nothing else, and a fresh FASL cache.
#
# The point is what it rules out. A canary that passes because ASDF quietly found
# the developer's working tree, or an old FASL, or a globally installed copy,
# proves nothing about the artifact. So this script checks where CNA-Lisp was
# actually loaded from and fails if the answer is not the extraction directory.
#
# It also checks the three pixels the template reads, in both directions: under a
# rasterising renderer they must be the exact colours the template drew, and under
# one with no readback they must all say so. Printing them was not enough -- a
# consumer that had quietly stopped drawing would have printed whatever it found.
#
#   CNA_NATIVE_LIBRARY=/abs/path/libcna_c_api.so \
#     tools/qualification/isolated-consumer.sh [/path/to/cna-common-lisp-template]
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
template=${1:-$(cd "$root/../cna-common-lisp-template" 2>/dev/null && pwd || true)}
sbcl=${SBCL:-sbcl}
work="$root/build-consumer"

if [ -z "${CNA_NATIVE_LIBRARY:-}" ]; then
    echo "CNA_NATIVE_LIBRARY must name a qualified CNA C ABI shared library" >&2
    exit 2
fi
if [ -z "$template" ] || [ ! -f "$template/cna-common-lisp-template.asd" ]; then
    echo "usage: $0 /path/to/cna-common-lisp-template" >&2
    exit 2
fi

# A shared, stable working directory: the artifact and the isolated template copy
# are rebuilt in place rather than in a new directory per run.
rm -rf "$work/artifact" "$work/consumer" "$work/fasl"
mkdir -p "$work/artifact" "$work/consumer" "$work/fasl"

echo "== building the source artifact =="
git -C "$root" archive --format=tar HEAD | tar -x -C "$work/artifact"
artifact_files=$(find "$work/artifact" -type f | wc -l)
echo "   $artifact_files file(s) from $(git -C "$root" rev-parse --short HEAD)"

echo "== copying the template into a clean directory =="
if [ -d "$template/.git" ]; then
    git -C "$template" archive --format=tar HEAD | tar -x -C "$work/consumer"
else
    (cd "$template" && tar -cf - .) | tar -x -C "$work/consumer"
fi

# Nothing but the artifact and the isolated template copy is on the load path.
# The developer's working tree is deliberately absent from it.
CL_SOURCE_REGISTRY="(:source-registry :ignore-inherited-configuration (:directory \"$work/artifact/\") (:directory \"$work/consumer/\"))"
ASDF_OUTPUT_TRANSLATIONS="(:output-translations :ignore-inherited-configuration (t (\"$work/fasl/\" :implementation)))"
export CL_SOURCE_REGISTRY ASDF_OUTPUT_TRANSLATIONS

echo "== proving CNA-Lisp loads from the artifact, not from the checkout =="
"$sbcl" --script /dev/stdin <<LISP
(require :asdf)
(let ((setup (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (when (probe-file setup)
    (handler-bind ((warning #'muffle-warning)) (load setup))))
(asdf:load-system "cna-common-lisp")
(let* ((directory (namestring (asdf:system-source-directory "cna-common-lisp")))
       (artifact "$work/artifact/")
       (checkout "$root/"))
  (format t "~&   loaded from ~a~%" directory)
  (unless (search artifact directory)
    (format *error-output* "~&FAIL CNA-Lisp came from ~a, not from the artifact~%"
            directory)
    (uiop:quit 1))
  (when (and (search checkout directory) (not (search artifact directory)))
    (format *error-output* "~&FAIL CNA-Lisp came from the developer checkout~%")
    (uiop:quit 1)))
(format t "   ok~%")
LISP

for frames in 60 600; do
    echo "== template canary, $frames frames =="
    output=$("$sbcl" --script "$work/consumer/run.lisp" -- --frames "$frames" 2>&1) || true
    echo "$output" | grep '^CANARY ' || true
    if ! echo "$output" | grep -q '^CANARY result=pass$'; then
        echo "FAIL the $frames-frame canary did not pass" >&2
        echo "$output" >&2
        exit 1
    fi
    if ! echo "$output" | grep -q "^CANARY updates=$frames\$"; then
        echo "FAIL the $frames-frame canary did not deliver $frames updates" >&2
        exit 1
    fi
    if ! echo "$output" | grep -q "^CANARY draws=$frames\$"; then
        echo "FAIL the $frames-frame canary did not deliver $frames draws" >&2
        exit 1
    fi
    if ! echo "$output" | grep -q '^CANARY disposed=yes$'; then
        echo "FAIL the $frames-frame canary left something undisposed" >&2
        exit 1
    fi

    # The three pixels the consumer reads, asserted rather than printed. Which
    # branch is correct depends on the renderer, and *both* branches are checked:
    # a lane that only accepted "not-supported" would pass against a rasterising
    # renderer that had silently stopped drawing, and one that only accepted the
    # colours could not run under HEADLESS at all.
    renderer=$(echo "$output" | sed -n 's/^CANARY renderer=//p')
    case "$renderer" in
        SOFTWARE|OPENGL33|OPENGLES3|SDL_RENDERER|VULKAN|SDL_GPU|PORTABLEGL|OPENGL4)
            expect_pixel() {
                if ! echo "$output" | grep -q "^CANARY $1=$2\$"; then
                    echo "FAIL $renderer: the $frames-frame canary's $1 should be $2" >&2
                    echo "$output" | grep "^CANARY $1=" >&2
                    exit 1
                fi
            }
            # CornflowerBlue, the triangle's own vertex colour, and the colour
            # that exists nowhere in the frame but inside the render target.
            expect_pixel pixels 100,149,237,255
            expect_pixel triangle_pixel 255,128,0,255
            expect_pixel render_target_pixel 0,200,90,255
            # Text is asserted differently, and deliberately. The sample sits
            # inside a glyph of a real antialiased typeface, so its exact value
            # depends on the font file and would make this gate a hash of
            # DejaVu Sans Mono. What must be true is that a glyph reached the
            # pixel at all: it is not the CornflowerBlue that was cleared there.
            text_pixel=$(echo "$output" | sed -n 's/^CANARY text_pixel=//p')
            if [ -z "$text_pixel" ] || [ "$text_pixel" = "not-read" ]; then
                echo "FAIL $renderer: the $frames-frame canary read no text pixel" >&2
                exit 1
            fi
            if [ "$text_pixel" = "100,149,237,255" ]; then
                echo "FAIL $renderer: the $frames-frame canary's text pixel is still" \
                     "the clear colour, so the loaded SpriteFont drew nothing there" >&2
                exit 1
            fi
            # And the font really came from the content pipeline, with the glyph
            # count the descriptor declares.
            if ! echo "$output" | grep -q '^CANARY font=95 glyphs, line-spacing 19$'; then
                echo "FAIL the $frames-frame canary did not load the expected font" >&2
                echo "$output" | grep '^CANARY font=' >&2
                exit 1
            fi
            ;;
        *)
            for line in pixels triangle_pixel render_target_pixel text_pixel; do
                if ! echo "$output" | grep -q "^CANARY $line=not-supported\$"; then
                    echo "FAIL $renderer has no back-buffer readback, so the" \
                         "$frames-frame canary's $line should be not-supported" >&2
                    echo "$output" | grep "^CANARY $line=" >&2
                    exit 1
                fi
            done
            ;;
    esac
done

echo "== the template stays on the public API =="
"$work/consumer/tools/audit-public-only.sh"

echo
echo "isolated consumer qualification passed"
echo "  artifact  $work/artifact"
echo "  consumer  $work/consumer"
echo "  fasl      $work/fasl (fresh; no stale compilation was reused)"
