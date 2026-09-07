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
    ;; The storage surface, reported separately for a reason none of the others
    ;; have: it is the only one that needs no game, and it is the only one that
    ;; writes to the filesystem. Its eight levels are eight claims, and none of
    ;; them is about durability.
    (when (native-library-requested-p)
      (if *storage-evidence*
          (dolist (entry (reverse *storage-evidence*))
            (format t "~&storage       : ~(~a~) -- ~a~%" (car entry) (cdr entry)))
          (format t "~&storage       : NOT RUN -- no storage test recorded evidence~%"))
      (when (and (storage-proved-p :root) (not (storage-proved-p :no-root)))
        (format t "A storage root was named and the refusal of an unusable name~%")
        (format t "was not observed: those are two claims and this run supports~%")
        (format t "one.~%"))
      (when (and (storage-proved-p :container) (not (storage-proved-p :stream)))
        (format t "A container opened and no stream round-tripped: a container~%")
        (format t "that opens says nothing about whether bytes come back.~%"))
      (when (storage-proved-p :stream)
        (format t "No storage claim above is about durability. Bytes written,~%")
        (format t "closed, reopened and read back in one process are evidence~%")
        (format t "about the stream protocol and CNA's routes, and not that the~%")
        (format t "data survives a power cut, a full disk, or a filesystem that~%")
        (format t "lies about fsync.~%")))
    ;; The caller-owned GraphicsDevice. Eight levels and they are eight claims,
    ;; for the reason every surface above keeps its own apart -- and one more
    ;; reason of its own: the pixel claim is the only graphics evidence in this
    ;; repository that needs no game, and reading it out of the others would
    ;; lose exactly what makes it new.
    (when (native-library-requested-p)
      (if *owned-device-evidence*
          (dolist (entry (reverse *owned-device-evidence*))
            (format t "~&owned device  : ~(~a~) -- ~a~%" (car entry) (cdr entry)))
          (format t "~&owned device  : NOT RUN -- no owned-device test recorded evidence~%"))
      (when (and (owned-device-proved-p :create)
                 (not (owned-device-proved-p :coexistence)))
        (format t "A device was constructed and two were not proved independent:~%")
        (format t "those are two claims and this run supports one.~%"))
      (when (and (owned-device-proved-p :headless)
                 (not (owned-device-proved-p :software)))
        (format t "The owned-device pixel claim was NOT made: this renderer has no~%")
        (format t "honest back-buffer readback, so the standalone device proved its~%")
        (format t "lifecycle and its commands and nothing about pixels.~%"))
      (when (owned-device-proved-p :cross-device)
        (format t "No owned-device claim above says cross-device resource use is~%")
        (format t "refused. It is not -- by CNA, measured, or by XNA, read from the~%")
        (format t "pinned assembly -- and this binding does not invent the refusal.~%")))
    ;; Game services and device selection. Six levels and they are six claims,
    ;; for the reason the four device surfaces above each keep theirs apart.
    (when (native-library-requested-p)
      (if *services-evidence*
          (dolist (entry (reverse *services-evidence*))
            (format t "~&services      : ~(~a~) -- ~a~%" (car entry) (cdr entry)))
          (format t "~&services      : NOT RUN -- no services test recorded evidence~%"))
      (when (and (services-proved-p :managed) (not (services-proved-p :canonical)))
        (format t "An arbitrary service dictionary worked and the manager's own two~%")
        (format t "registrations were not observed: those are two claims and this~%")
        (format t "run supports one.~%"))
      (when (and (services-proved-p :virtual-events)
                 (not (services-proved-p :preparing-device-settings)))
        (format t "A protected raiser controlled a data-free event and the mutable~%")
        (format t "device-settings event was not observed: a seam that suppresses~%")
        (format t "says nothing about a seam that changes the device.~%"))
      (when (services-proved-p :device-selection)
        (format t "No services claim above says that FindBestDevice, RankDevices or~%")
        (format t "CanResetDevice influences device creation. They answer XNA's~%")
        (format t "semantics when called, and no admitted CNA ABI calls them: an~%")
        (format t "override changes nothing the framework does, which is why all~%")
        (format t "three are reported partial rather than complete.~%")))
    ;; Game's private device-event wiring. Seven levels and they are seven
    ;; claims, for the reason every surface above keeps its own apart -- and one
    ;; that is particular to this lane: none of these is a public XNA member, so
    ;; no compatibility cell can report them and the evidence lines are the only
    ;; record that the invariant holds. That the private handler *ran* says
    ;; nothing about whether it read the current `Game.Content'; that it read the
    ;; current one says nothing about whether a real loaded asset reached its
    ;; disposed state; and none of them says anything about a condition crossing
    ;; a C frame.
    (when (native-library-requested-p)
      (if *device-wiring-evidence*
          (dolist (entry (reverse *device-wiring-evidence*))
            (format t "~&device wiring : ~(~a~) -- ~a~%" (car entry) (cdr entry)))
          (format t "~&device wiring : NOT RUN -- no device-wiring test recorded evidence~%"))
      (when (and (device-wiring-proved-p :hook-installation)
                 (not (device-wiring-proved-p :content-unload)))
        (format t "The private subscriptions were installed and no asset was~%")
        (format t "proved released: a hook that is present says nothing about~%")
        (format t "whether anything happens when it fires.~%"))
      (when (and (device-wiring-proved-p :content-unload)
                 (not (device-wiring-proved-p :current-reference)))
        (format t "An asset was released and the CURRENT Game.Content was not~%")
        (format t "proved to be the one chosen: a handler that closed over the~%")
        (format t "manager it was installed with would pass the first and fail~%")
        (format t "the second.~%"))
      (when (device-wiring-proved-p :content-unload)
        (format t "No device-wiring claim above is about Game.UnloadContent.~%")
        (format t "CNA's native game already drives that callback at this exact~%")
        (format t "point -- measured -- so the binding supplies ContentManager.~%")
        (format t "Unload alone and the pair lands in XNA's order. Calling both~%")
        (format t "would run the program's overridable method twice.~%")))
    ;; The four shim-dependent setters. **One line per branch, and a run can
    ;; only produce one**: the shim is process-global, latched by the loader, so
    ;; one image cannot answer for two configurations. The lane runs two.
    (when (native-library-requested-p)
      (if *shim-policy-evidence*
          (dolist (entry (reverse *shim-policy-evidence*))
            (format t "~&shim policy   : ~(~a~) -- ~a~%" (car entry) (cdr entry)))
          (format t "~&shim policy   : NOT RUN -- no shim-policy test recorded evidence~%"))
      (when *shim-policy-evidence*
        (format t "All four are reported partial for exactly this reason: a~%")
        (format t "released CNA-Lisp does not ship the shim, so an ordinary~%")
        (format t "installation cannot reach any of the four setters. See~%")
        (format t "docs/compatibility.md on what complete means across~%")
        (format t "configurations.~%")))
    (format t "-------------------------------~%")
    (when failed
      (error "~d CNA-Lisp test failure~:p" (length failed)))
    t))
