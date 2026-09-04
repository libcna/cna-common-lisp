;;;; runner.lisp --- what `asdf:test-system "cna-common-lisp"' runs.
;;;;
;;;; The summary distinguishes three outcomes, and the distinction is the point:
;;;; a native test that did not run because no library was named is reported as
;;;; NOT RUN, never as a pass.

(in-package #:cna-common-lisp.tests)

(defun run-all-tests ()
  "Run the whole suite. Signals an error when anything failed, so that
`asdf:test-system' fails."
  (format t "~&~%CNA-Lisp test suite~%")
  (format t "  SBCL ~a on ~a~%" (lisp-implementation-version) (machine-type))
  (if (native-library-requested-p)
      (format t "  native layer: CNA_NATIVE_LIBRARY=~a~%"
              (uiop:getenv "CNA_NATIVE_LIBRARY"))
      (format t "  native layer: NOT RUN (CNA_NATIVE_LIBRARY is not set)~%"))
  (format t "~%")
  (let* ((results (run 'all-tests))
         (passed (count-if (lambda (r) (typep r 'fiveam::test-passed)) results))
         (failed (remove-if-not (lambda (r) (typep r 'fiveam::test-failure)) results))
         (skipped (remove-if-not (lambda (r) (typep r 'fiveam::test-skipped)) results)))
    (explain! results)
    (format t "~&~%---- CNA-Lisp test summary ----~%")
    (format t "checks passed : ~d~%" passed)
    (format t "failures      : ~d~%" (length failed))
    (format t "not run       : ~d~%" (length skipped))
    (unless (native-library-requested-p)
      (format t "~%The native layer did not run. Nothing in this summary is evidence~%")
      (format t "about the CNA C ABI, the game loop, graphics, input or ownership.~%")
      (format t "Set CNA_NATIVE_LIBRARY to a qualified libcna_c_api.so and run again.~%"))
    ;; What the rasterization tests actually proved, one line per kind. A suite
    ;; that never reached a rasterising renderer has proved nothing about pixels,
    ;; and the only way to stop that being read as though it had is to say so.
    ;; The kinds are kept apart because they are different claims: Clear reaching
    ;; the back buffer says nothing about whether SpriteBatch rasterises, and
    ;; neither says anything about the primitive pipeline.
    (when (native-library-requested-p)
      (if *rasterization-evidence*
          (dolist (entry (reverse *rasterization-evidence*))
            (format t "~&rasterization : ~(~a~) -- ~a~%" (car entry) (cdr entry)))
          (format t "~&rasterization : NOT RUN -- no renderer was reached~%"))
      (unless (rasterization-proved-p :clear)
        (format t "Nothing above is evidence that anything reached actual pixels.~%")
        (format t "Run again against a CNA built with a rasterising renderer --~%")
        (format t "-DCNA_GRAPHICS_RENDERER=SOFTWARE needs no display -- for that.~%"))
      (when (rasterization-proved-p :clear)
        (unless (rasterization-proved-p :sprite)
          (format t "A clear reached the back buffer; no SpriteBatch draw was proved.~%"))
        (unless (rasterization-proved-p :primitive)
          (format t "No primitive draw was proved: the sprite path and the primitive ~
                     path~%are different paths through the renderer.~%"))))
    (format t "-------------------------------~%")
    (when failed
      (error "~d CNA-Lisp test failure~:p" (length failed)))
    t))
