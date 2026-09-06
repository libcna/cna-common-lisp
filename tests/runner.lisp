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
    ;; The capture surface, reported **separately from playback**, because they
    ;; are different devices behind different CNA routes: a run with a playback
    ;; device may enumerate no microphone and a run with a microphone may have no
    ;; speaker, and one line covering both would let either be read as the other.
    ;; Its five levels are five claims for the reason the audio ones are four.
    (when (native-library-requested-p)
      (if *microphone-evidence*
          (dolist (entry (reverse *microphone-evidence*))
            (format t "~&microphone    : ~(~a~) -- ~a~%" (car entry) (cdr entry)))
          (format t "~&microphone    : NOT RUN -- no microphone test recorded evidence~%"))
      (when (and (microphone-proved-p :unavailable)
                 (not (microphone-proved-p :enumeration)))
        (format t "No capture device was enumerated, so only the unavailable branch~%")
        (format t "is qualified. SDL_AUDIODRIVER=dummy enumerates capture devices~%")
        (format t "that advance a stream of silence, which is what the other lanes~%")
        (format t "need.~%"))
      (when (microphone-proved-p :capture-idle)
        (format t "Capture devices enumerated and this environment's driver~%")
        (format t "delivered no PCM from any of them. That is an ordinary~%")
        (format t "environment, not a failure -- GetData answered zero and wrote~%")
        (format t "nothing, which is asserted -- but the capture-data and~%")
        (format t "buffer-ready claims are NOT supported by this run.~%")
        (format t "SDL_AUDIODRIVER=dummy enumerates capture devices that do~%")
        (format t "advance a stream of silence, which is what those lanes need.~%"))
      (when (and (microphone-proved-p :enumeration)
                 (not (microphone-proved-p :capture-data))
                 (not (microphone-proved-p :capture-idle)))
        (format t "Capture devices enumerated and no PCM was read from one: those~%")
        (format t "are two claims and this run supports only the first.~%"))
      (when (and (microphone-proved-p :capture-data)
                 (not (microphone-proved-p :buffer-ready)))
        (format t "PCM arrived and the BufferReady event was not observed: a stream~%")
        (format t "that advances says nothing about the event that announces it.~%"))
      ;; Where CNA and the pinned XNA behaviour were measured to disagree. Each
      ;; line is a decision as well as a measurement: the public answer is XNA's,
      ;; and printing CNA's beside it is what keeps the divergence a fact rather
      ;; than a comment nobody re-checks.
      (when *microphone-divergences*
        (format t "~&microphone    : xna-over-cna -- ~d measured disagreement~:p, ~
                   and the public answer is XNA's in each~%"
                (length *microphone-divergences*))
        (dolist (line (reverse *microphone-divergences*))
          (format t "                  * ~a~%" line)))
      (when (microphone-proved-p :capture-data)
        (format t "No microphone claim above is about acoustics. No captured byte~%")
        (format t "was inspected: what was proved is that the capture device this~%")
        (format t "run's SDL driver enumerated advances its PCM16 stream at the~%")
        (format t "sample rate it reports, and that CNA-Lisp reproduces XNA's~%")
        (format t "state, buffer and event semantics over that stream. Nothing~%")
        (format t "here says a sound was captured or that a physical microphone~%")
        (format t "works. tools/qualification/microphone.sh runs this under SDL's~%")
        (format t "dummy driver, whose capture devices produce silence.~%")))
    ;; The media surface, reported separately again, and for the third time for
    ;; the same reason: playback of a *song* goes through routes of its own, and a
    ;; run that qualified the sound-effect transport says nothing about whether
    ;; the media player's did. Its five levels are five claims.
    (when (native-library-requested-p)
      (if *media-evidence*
          (dolist (entry (reverse *media-evidence*))
            (format t "~&media         : ~(~a~) -- ~a~%" (car entry) (cdr entry)))
          (format t "~&media         : NOT RUN -- no media test recorded evidence~%"))
      (when (and (media-proved-p :unavailable) (not (media-proved-p :playback)))
        (format t "No playback device opened, so the media transport was not~%")
        (format t "exercised. The unavailable branch is qualified -- a song was~%")
        (format t "created anyway and the refusal arrived at Play -- and the~%")
        (format t "available one is not. SDL_AUDIODRIVER=dummy opens a device~%")
        (format t "without a speaker.~%"))
      (when (and (media-proved-p :playback) (not (media-proved-p :play-clock)))
        (format t "The media transport transitioned and the play clock was not~%")
        (format t "observed: those are two claims and this run supports one.~%"))
      (when (media-proved-p :playback)
        (format t "No media claim above is about audible output. A dummy device~%")
        (format t "accepting a transport transition is not music being heard, and~%")
        (format t "a play position that advances is a clock rather than a sound.~%")))
    (format t "-------------------------------~%")
    (when failed
      (error "~d CNA-Lisp test failure~:p" (length failed)))
    t))
