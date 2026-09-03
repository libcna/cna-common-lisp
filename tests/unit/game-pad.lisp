;;;; game-pad.lisp --- the GamePad value types, without a native library.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

(test the-buttons-flags-enum-matches-the-contract
  ;; The values are XNA's, not a renumbering: a saved input binding is a set of
  ;; these integers and it has to keep meaning the same thing.
  (is (= #x1000 (input:buttons-value :a)))
  (is (= #x8000 (input:buttons-value :y)))
  (is (= #x1 (input:buttons-value :dpad-up)))
  (is (= #x40000000 (input:buttons-value :left-thumbstick-right)))
  (is (= #x800000 (input:buttons-value :left-trigger)))
  ;; A flags enum combines, and a list is the representation.
  (is (= #x3000 (input:buttons-value '(:a :b))))
  (is (equal '(:a) (input:buttons-from-value #x1000)))
  (is (equal '(:dpad-up :a) (input:buttons-from-value #x1001)))
  (is (= 25 (length (input:all-buttons))))
  ;; The two masks in the source are literals, because a DEFCONSTANT needs its
  ;; value at compile time. They are recomputed from the enum table here, so a
  ;; literal that disagrees with the members it claims to name cannot survive.
  (is (= (input:buttons-value '(:a :b :x :y :back :start :left-shoulder
                                :right-shoulder :left-stick :right-stick :big-button))
         input::+game-pad-button-mask+))
  (is (= (input:buttons-value '(:dpad-up :dpad-down :dpad-left :dpad-right))
         input::+game-pad-dpad-mask+))
  (signals xna:cna-usage-error (input:buttons-value :turbo)))

(test the-gamepad-type-values-are-xnas-and-not-the-abis
  ;; CNA numbers the pad types consecutively and XNA does not: BigButtonPad is
  ;; 0x300 in the contract and 9 in the C ABI. The projection answers the
  ;; contract's number, which is the whole reason the two tables are separate.
  (is (= 0 (input:game-pad-type-value :unknown)))
  (is (= 1 (input:game-pad-type-value :game-pad)))
  (is (= 8 (input:game-pad-type-value :drum-kit)))
  (is (= #x300 (input:game-pad-type-value :big-button-pad)))
  (is (eq :big-button-pad (input:game-pad-type-from-value #x300)))
  (is (= 9 (car (rassoc :big-button-pad input::*game-pad-type-from-abi*)))
      "and the ABI table still says 9, so the boundary has something to translate"))

(test game-pad-buttons-and-dpad-are-bit-sets
  (let ((buttons (input:make-game-pad-buttons '(:a :start :left-shoulder))))
    (is (eq :pressed (input:game-pad-buttons-a buttons)))
    (is (eq :pressed (input:game-pad-buttons-start buttons)))
    (is (eq :pressed (input:game-pad-buttons-left-shoulder buttons)))
    (is (eq :released (input:game-pad-buttons-b buttons)))
    (is (eq :released (input:game-pad-buttons-big-button buttons)))
    (is (input:game-pad-buttons-equal
         buttons (input:make-game-pad-buttons '(:start :a :left-shoulder)))
        "the order the members are listed in does not matter")
    (is (not (input:game-pad-buttons-equal buttons (input:make-game-pad-buttons))))
    ;; A member GamePadButtons has no field for is dropped, not stored.
    (is (input:game-pad-buttons-equal (input:make-game-pad-buttons '(:a :dpad-up))
                                      (input:make-game-pad-buttons '(:a)))))
  ;; The DPad constructor's argument order is up, down, left, right.
  (let ((dpad (input:make-game-pad-dpad :pressed :released :released :pressed)))
    (is (eq :pressed (input:game-pad-dpad-up dpad)))
    (is (eq :released (input:game-pad-dpad-down dpad)))
    (is (eq :released (input:game-pad-dpad-left dpad)))
    (is (eq :pressed (input:game-pad-dpad-right dpad))))
  (signals type-error (input:make-game-pad-dpad :maybe)))

(test a-gamepad-state-is-built-from-four-value-types
  (let* ((state (input:make-game-pad-state
                 :thumb-sticks (input:make-game-pad-thumb-sticks
                                (xna:make-vector2 0.5 -0.25)
                                (xna:make-vector2 0.0 1.0))
                 :triggers (input:make-game-pad-triggers 0.75 0.0)
                 :buttons (input:make-game-pad-buttons '(:a :y))
                 :dpad (input:make-game-pad-dpad :released :pressed))))
    (is (input:game-pad-state-is-connected state)
        "a constructed state is connected; only a capture answers otherwise")
    (is (= 0 (input:game-pad-state-packet-number state)))
    (is (eq :pressed (input:game-pad-buttons-a (input:game-pad-state-buttons state))))
    (is (eq :released (input:game-pad-buttons-b (input:game-pad-state-buttons state))))
    (is (eq :pressed (input:game-pad-dpad-down (input:game-pad-state-dpad state))))
    (is (= 0.75f0 (input:game-pad-triggers-left (input:game-pad-state-triggers state))))
    (is (= 0.5f0 (xna:vector2-x (input:game-pad-thumb-sticks-left
                                 (input:game-pad-state-thumb-sticks state)))))
    ;; IsButtonDown takes one member or a set of them, and a set asks whether
    ;; every one of them is down.
    (is (input:game-pad-state-is-button-down state :a))
    (is (input:game-pad-state-is-button-down state '(:a :y)))
    (is (not (input:game-pad-state-is-button-down state '(:a :b))))
    (is (input:game-pad-state-is-button-up state :b))
    (is (not (input:game-pad-state-is-button-up state :a)))
    ;; The state's word carries both, but the two accessors are masked apart:
    ;; XNA's GamePadButtons is eleven fields and cannot hold a directional bit,
    ;; so comparing two states' Buttons must compare buttons.
    (is (input:game-pad-state-is-button-down state :dpad-down))
    (is (input:game-pad-buttons-equal
         (input:game-pad-state-buttons state)
         (input:game-pad-state-buttons
          (input:make-game-pad-state :buttons (input:make-game-pad-buttons '(:a :y))
                                     :dpad (input:make-game-pad-dpad))))
        "the same buttons with a different dpad are the same GamePadButtons")
    (is (eq :released (input:game-pad-dpad-up (input:game-pad-state-dpad state)))))
  (let ((defaults (input:make-game-pad-state)))
    (is (eq :released (input:game-pad-buttons-a (input:game-pad-state-buttons defaults))))
    (is (= 0.0f0 (input:game-pad-triggers-right
                  (input:game-pad-state-triggers defaults))))))

(test the-second-gamepad-state-constructor-is-a-separate-name
  (let ((state (input:make-game-pad-state-from-values
                (xna:make-vector2 1.0 0.0) (xna:make-vector2 0.0 -1.0)
                0.25 0.5 '(:b :dpad-left))))
    (is (input:game-pad-state-is-connected state))
    (is (eq :pressed (input:game-pad-buttons-b (input:game-pad-state-buttons state))))
    (is (eq :pressed (input:game-pad-dpad-left (input:game-pad-state-dpad state))))
    (is (= 0.25f0 (input:game-pad-triggers-left (input:game-pad-state-triggers state))))
    (is (= -1.0f0 (xna:vector2-y (input:game-pad-thumb-sticks-right
                                  (input:game-pad-state-thumb-sticks state)))))))

(test gamepad-value-types-compare-and-copy-as-values
  (let* ((sticks (input:make-game-pad-thumb-sticks (xna:make-vector2 1.0 2.0)
                                                   (xna:make-vector2 3.0 4.0)))
         (copy (input:copy-game-pad-thumb-sticks sticks)))
    (is (input:game-pad-thumb-sticks-equal sticks copy))
    (is (not (input:game-pad-thumb-sticks-equal
              sticks (input:make-game-pad-thumb-sticks (xna:make-vector2 1.0 2.0)))))
    ;; The constructor copies its vectors, so mutating the argument afterwards
    ;; cannot reach into the value.
    (let* ((vector (xna:make-vector2 9.0 9.0))
           (held (input:make-game-pad-thumb-sticks vector)))
      (setf (xna:vector2-x vector) 0.0)
      (is (= 9.0f0 (xna:vector2-x (input:game-pad-thumb-sticks-left held))))))
  (is (input:game-pad-triggers-equal (input:make-game-pad-triggers 0.5 0.5)
                                     (input:make-game-pad-triggers 0.5 0.5)))
  (is (input:game-pad-state-equal (input:make-game-pad-state)
                                  (input:make-game-pad-state))))
