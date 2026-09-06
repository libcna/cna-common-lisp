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
    ;; Which pixel proofs are *obtainable* here is not the same question as
    ;; which ones this run produced, and one of them depends on the loaded ABI
    ;; rather than on the renderer: `Load<Model>' refuses on CNA 0.21.0, so the
    ;; `model' proof cannot exist there however well the rasteriser works. The
    ;; lane needs to be told, or it demands a proof no library can produce and
    ;; the whole lane fails on an admitted ABI -- which is what it did.
    (when (native-library-requested-p)
      (if (model-loading-available-p)
          (format t "~&model loading : available -- the `model' pixel proof is ~
                     obtainable on this ABI and this lane requires it~%")
          (format t "~&model loading : refused by this ABI (~a) -- ~
                     cna_model_destroy on a content-loaded model is a null ~
                     dereference there, so Load<Model> refuses and the `model' ~
                     pixel proof cannot be produced. The refusal itself is ~
                     asserted by the suite, which is a result and not a skip~%"
                  (int:format-abi-version (int:loaded-abi-version)))))
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
    ;; What the audio tests actually proved, and which branch they took. A run
    ;; on a machine with no sound card qualifies the **unavailable** branch and
    ;; nothing else; saying so is what stops that being read as though the state
    ;; machine had been exercised. Neither branch is a claim that a sound was
    ;; heard, and the line says so once rather than each test saying it.
    (when (native-library-requested-p)
      (if *audio-evidence*
          (dolist (entry (reverse *audio-evidence*))
            (format t "~&audio         : ~(~a~) -- ~a~%" (car entry) (cdr entry)))
          (format t "~&audio         : NOT RUN -- no audio test recorded evidence~%"))
      (when (and (audio-proved-p :unavailable) (not (audio-proved-p :state-machine)))
        (format t "No playback device opened, so the audio state machine was not~%")
        (format t "exercised. The unavailable branch is qualified; the available one~%")
        (format t "is not. SDL_AUDIODRIVER=dummy opens a device without a speaker.~%"))
      (when (and (audio-proved-p :state-machine)
                 (not (audio-proved-p :dynamic-streaming)))
        (format t "The transport was exercised and the streaming buffer queue was~%")
        (format t "not: those are two claims and this run supports only the first.~%"))
      (when (audio-proved-p :state-machine)
        (format t "No audio claim above is about audible output: a dummy or real~%")
        (format t "device accepting a state transition is not a sound being heard,~%")
        (format t "and a buffer the mixer consumed is not a buffer anyone heard.~%")))
    (format t "-------------------------------~%")
    (when failed
      (error "~d CNA-Lisp test failure~:p" (length failed)))
    t))
