;;;; wave.lisp --- the RIFF/WAVE shape SoundEffect.FromStream accepts, and no other.
;;;;
;;;; **This exists because CNA's decoder is wider than XNA's.**
;;;; `cna_sound_effect_create_from_encoded_ext' says so in its own header --
;;;; "whatever the audio backend can decode is accepted, which is more than the
;;;; raw PCM the other creation routes take" -- and SDL decodes a good deal.
;;;; `SoundEffect.FromStream' does not: the pinned assembly hands the stream to a
;;;; private `WavFile' whose parser accepts **one** shape, and a projection that
;;;; accepted an Ogg because the backend could decode one would be inventing a
;;;; member. So the bytes are checked here, before CNA sees them.
;;;;
;;;; Everything below is `WavFile' in the pinned assembly, in the order it reads:
;;;; `WavFile..ctor', `ParseWavHeader', `ReadChunk', `ParseFormat' and
;;;; `ParseData'. The exception each refusal names is the one that reaches a
;;;; caller of `FromStream', which is **not** always the one the parser raises:
;;;;
;;;;   ParseWavHeader runs outside the chunk loop, so its InvalidOperationException
;;;;   propagates.
;;;;
;;;;   ReadChunk runs inside `try { ReadChunk(); } catch (object) { break; }', so
;;;;   every failure below the header merely *ends* the loop. What the caller sees
;;;;   is the check that follows it -- `if (format == null || buffer == null)
;;;;   throw new ArgumentException(InvalidWaveStream)'.
;;;;
;;;; That is why a stream that is not RIFF/WAVE is one exception and a stream
;;;; whose `fmt ' chunk says MP3 is a different one, and why both are worth a
;;;; test: they are two different observable behaviours of one member.
;;;;
;;;; **What this does not do.** It is not a decoder and must not become one. It
;;;; establishes that the bytes are a wave file of a shape XNA accepts and then
;;;; hands the original bytes to CNA, which decodes them. Nothing here converts
;;;; samples, and no fixture in this repository is a recording.

(in-package #:microsoft.xna.framework.audio)

;;; --- reading the little-endian fields a RIFF file is made of ---------------

(defun %octets-tag (octets index)
  "The four bytes at INDEX as a string, or NIL when the vector is too short.

A RIFF chunk identifier is four ASCII bytes. The pinned parser reads them as a
big-endian `int32' and compares against a constant built the same way, which is
the same comparison as comparing the four bytes in order."
  (when (<= (+ index 4) (length octets))
    (map 'string #'code-char (subseq octets index (+ index 4)))))

(defun %octets-u32 (octets index)
  "The little-endian unsigned 32-bit integer at INDEX, or NIL when out of range."
  (when (<= (+ index 4) (length octets))
    (logior (aref octets index)
            (ash (aref octets (+ index 1)) 8)
            (ash (aref octets (+ index 2)) 16)
            (ash (aref octets (+ index 3)) 24))))

(defun %octets-u16 (octets index)
  "The little-endian unsigned 16-bit integer at INDEX, or NIL when out of range."
  (when (<= (+ index 2) (length octets))
    (logior (aref octets index) (ash (aref octets (+ index 1)) 8))))

;;; --- the two refusals, named for the exception each becomes ----------------

(defun %refuse-wave-header (operation control &rest arguments)
  "`ParseWavHeader''s InvalidOperationException, which propagates out of FromStream."
  (error 'xna:cna-usage-error
         :operation operation :object-type 'sound-effect
         :format-control
         (concatenate 'string control
                      " XNA's WavFile parses the RIFF header before its chunk loop, so ~
                       this one throws InvalidOperationException rather than the ~
                       ArgumentException a bad chunk gives.")
         :format-arguments arguments))

(defun %refuse-wave-stream (operation control &rest arguments)
  "The `ArgumentException(InvalidWaveStream)' every failure below the header becomes.

XNA does not report *which* chunk was wrong: the chunk loop swallows the parser's
own exception and the caller is told only that no usable format and data were
found. The reason is kept here because a refusal a program cannot act on is worse
than XNA's, and the exception class -- which is the part a handler dispatches on
-- is XNA's exactly."
  (error 'xna:cna-argument-error
         :operation operation :parameter-name "stream" :object-type 'sound-effect
         :format-control
         (concatenate 'string control
                      " XNA's WavFile ends its chunk loop on any failure below the ~
                       header and then refuses the stream with ArgumentException ~
                       because it found no usable format and data.")
         :format-arguments arguments))

;;; --- the format contract, transcribed from ParseFormat ---------------------

(defconstant +wave-format-pcm+ 1
  "`WAVE_FORMAT_PCM'. `ParseFormat' refuses every other FormatTag, which is what
makes FromStream a PCM member and not a general decode.")

(defun %check-wave-format (operation raw)
  "`ParseFormat''s six tests, in its order, over the `fmt ' chunk's bytes.

    FormatTag != 1                       -> refused: PCM only
    Channels not 1 or 2                  -> refused
    SampleRate < 8000 or > 48000         -> refused, the same bounds the constructors use
    BitsPerSample not 8 or 16            -> refused
    BlockAlign != Channels * Bits / 8    -> refused

Answers (values format-tag channels sample-rate bits-per-sample block-align)."
  (when (< (length raw) 16)
    ;; "if (size < 16) throw" -- a WAVEFORMAT shorter than its own fixed part.
    (%refuse-wave-stream operation
                         "the fmt chunk holds ~d byte(s); a WAVEFORMAT's fixed part is 16."
                         (length raw)))
  (let ((format-tag (%octets-u16 raw 0))
        (channels (%octets-u16 raw 2))
        (sample-rate (%octets-u32 raw 4))
        (block-align (%octets-u16 raw 12))
        (bits (%octets-u16 raw 14)))
    (unless (= format-tag +wave-format-pcm+)
      (%refuse-wave-stream
       operation
       "the fmt chunk declares WAVE format tag ~d. FromStream accepts ~d -- ~
        uncompressed PCM -- and nothing else: XNA's WavFile refuses every other ~
        tag, so an ADPCM, an IEEE-float or an extensible wave is not a stream ~
        this member reads, whatever the audio backend behind CNA could decode."
       format-tag +wave-format-pcm+))
    (unless (member channels '(1 2))
      (%refuse-wave-stream operation
                           "the fmt chunk declares ~d channel(s); XNA accepts mono and stereo."
                           channels))
    (unless (<= +minimum-sample-rate+ sample-rate +maximum-sample-rate+)
      (%refuse-wave-stream
       operation
       "the fmt chunk declares ~d Hz; XNA accepts [~d, ~d], the same bounds its ~
        constructors take."
       sample-rate +minimum-sample-rate+ +maximum-sample-rate+))
    (unless (member bits '(8 16))
      (%refuse-wave-stream operation
                           "the fmt chunk declares ~d bit(s) per sample; XNA accepts 8 and 16."
                           bits))
    (unless (= block-align (floor (* channels bits) 8))
      (%refuse-wave-stream
       operation
       "the fmt chunk declares a block alignment of ~d, and ~d channel(s) of ~d ~
        bit(s) is ~d. XNA cross-checks the two and refuses a header that ~
        contradicts itself."
       block-align channels bits (floor (* channels bits) 8)))
    (values format-tag channels sample-rate bits block-align)))

;;; --- the whole file, transcribed from WavFile..ctor ------------------------

(defun %check-wave-stream (octets operation)
  "Refuse every byte sequence `WavFile' refuses, and answer the format it found.

OCTETS is the whole stream, which is what `%READ-STREAM-OCTETS' answers and what
XNA's `BinaryReader' reads. **The RIFF size field is checked against that
length**, because `ParseWavHeader' compares against `BaseStream.Length - 8' and
refuses a file whose declared size does not match -- one of the two reasons a
stream that looks like a wave file is still not one XNA reads.

Answers (values channels sample-rate bits-per-sample data-length)."
  ;; `WavFile..ctor': "source == null || source.Length == 0" is ArgumentNullException,
  ;; and it is the *first* thing checked -- before the header, so an empty stream is
  ;; a null-argument failure rather than a malformed-wave one.
  (when (zerop (length octets))
    (error 'xna:cna-argument-error
           :operation operation :parameter-name "stream" :object-type 'sound-effect
           :format-control
           "the stream held no bytes. XNA's WavFile tests the stream's length ~
            before reading anything and throws ArgumentNullException for a length ~
            of zero, so an empty stream never reaches its parser."))
  ;; `ParseWavHeader', outside the chunk loop: three tests, one exception.
  (let ((riff (%octets-tag octets 0))
        (declared (%octets-u32 octets 4))
        (wave (%octets-tag octets 8)))
    (unless (equal riff "RIFF")
      (%refuse-wave-header operation
                           "the stream does not begin with a RIFF chunk~@[ -- it begins ~s~]."
                           (and riff (substitute #\. #\Nul riff))))
    (unless (and declared (= declared (- (length octets) 8)))
      (%refuse-wave-header
       operation
       "the RIFF chunk declares ~@[~d~] byte(s) and the stream holds ~d after the ~
        eight-byte chunk header. XNA compares the two exactly."
       declared (- (length octets) 8)))
    (unless (equal wave "WAVE")
      (%refuse-wave-header operation
                           "the RIFF form is ~@[~s~] rather than WAVE."
                           (and wave (substitute #\. #\Nul wave)))))
  ;; The chunk loop. `ReadChunk' is called inside a catch-everything that ends the
  ;; loop, so a truncated or malformed chunk is not itself the failure: reaching
  ;; the end with no format or no data is.
  (let ((position 12)
        (length (length octets))
        (format nil)
        (data-length nil))
    (loop
      (when (>= position length) (return))
      ;; "if (position % 2 > 0) throw" -- a chunk may only start on an even offset.
      (when (oddp position) (return))
      (let ((id (%octets-tag octets position))
            (size (%octets-u32 octets (+ position 4))))
        (when (or (null id) (null size)) (return))
        (let ((body (+ position 8)))
          (cond
            ((equal id "fmt ")
             ;; A second fmt chunk overwrites the first, as the parser's field does.
             (when (> (+ body size) length) (return))
             (setf format (multiple-value-list
                           (%check-wave-format operation (subseq octets body (+ body size))))))
            ((equal id "data")
             ;; "if (format == null) throw" -- data before fmt ends the loop, which
             ;; is why chunk *order* is part of the contract and not a convention.
             (when (null format) (return))
             (let ((block-align (fifth format)))
               ;; "if (size < BlockAlign) throw" -- a data chunk shorter than one frame.
               (when (< size block-align) (return))
               ;; "buffer = ReadBytes(size - size % BlockAlign)" and then the tail;
               ;; a short read leaves buffer null, which is the truncated-data case.
               (when (> (+ body size) length) (return))
               (setf data-length (- size (mod size block-align)))))
            (t
             ;; smpl, wsmp and everything else: read past and keep going. XNA keeps
             ;; the two loop chunks for its loop region and discards the rest.
             (when (> (+ body size) length) (return))))
          ;; "if (position % 2 > 0) reader.ReadByte()" -- the odd-length pad byte.
          (setf position (+ body size (if (oddp size) 1 0))))))
    (unless (and format data-length)
      (%refuse-wave-stream
       operation
       "the stream carries ~:[no fmt chunk~;a fmt chunk~] and ~:[no data chunk~;a ~
        data chunk~], and XNA needs both -- a data chunk before the fmt chunk that ~
        describes it counts as neither, because its parser reads the two in order."
       format data-length))
    (destructuring-bind (format-tag channels sample-rate bits block-align) format
      (declare (ignore format-tag block-align))
      (values channels sample-rate bits data-length))))
