;;;; keys.lisp --- Keys, KeyState and KeyboardState as pure values.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

(test keys-are-keywords-with-the-abi-values
  (is (= 27 (input:keys-value :escape)))
  (is (= 65 (input:keys-value :a)))
  (is (= 0 (input:keys-value :none)))
  (is (eq :escape (input:keys-from-value 27))))

(test keys-type-accepts-only-real-members
  (is (typep :escape 'input:keys))
  (is (not (typep :not-a-key 'input:keys)))
  (is (not (typep 27 'input:keys))))

(test keys-table-is-the-full-abi-family
  (is (= 160 (length (input:all-keys)))))

(test keys-value-refuses-an-unknown-member
  (signals xna:cna-usage-error (input:keys-value :not-a-key)))

(test key-state-members
  (is (= 0 (input:key-state-value :up)))
  (is (= 1 (input:key-state-value :down)))
  (is (eq :down (input:key-state-from-value 1))))

(test keyboard-state-is-a-value-with-no-lifetime
  (let ((state (input:make-keyboard-state '(:a :escape))))
    (is (input:is-key-down state :a))
    (is (input:is-key-down state :escape))
    (is (input:is-key-up state :b))
    (is (eq :down (input:get-key-state state :a)))
    (is (eq :up (input:get-key-state state :b)))))

(test keyboard-state-pressed-keys-are-in-value-order
  (let ((state (input:make-keyboard-state '(:escape :a :space))))
    (is (equal '(:escape :space :a) (input:get-pressed-keys state)))))

(test keyboard-state-duplicate-keys-contribute-once
  (let ((state (input:make-keyboard-state '(:a :a :a))))
    (is (equal '(:a) (input:get-pressed-keys state)))))

(test keyboard-state-copies-share-nothing
  (let* ((state (input:make-keyboard-state '(:a)))
         (copy (input:copy-keyboard-state state)))
    (is (input:keyboard-state-equal state copy))
    (is (not (eq (input::keyboard-state-words state)
                 (input::keyboard-state-words copy))))))

(test keyboard-state-equality
  (is (input:keyboard-state-equal (input:make-keyboard-state '(:a :b))
                                  (input:make-keyboard-state '(:b :a))))
  (is (not (input:keyboard-state-equal (input:make-keyboard-state '(:a))
                                       (input:make-keyboard-state '(:b))))))

(test enums-round-trip-through-their-values
  (dolist (member (gfx:all-sprite-sort-mode))
    (is (eq member (gfx:sprite-sort-mode-from-value
                    (gfx:sprite-sort-mode-value member)))))
  (dolist (member (gfx:all-surface-format))
    (is (eq member (gfx:surface-format-from-value
                    (gfx:surface-format-value member))))))

(test sprite-effects-is-a-flags-enum-over-lists
  (is (= 0 (gfx:sprite-effects-value :none)))
  (is (= 3 (gfx:sprite-effects-value '(:flip-horizontally :flip-vertically))))
  (is (equal '(:flip-horizontally :flip-vertically) (gfx:sprite-effects-from-value 3)))
  (is (equal '(:none) (gfx:sprite-effects-from-value 0))))

(test player-index-members
  (is (= 0 (xna:player-index-value :one)))
  (is (= 3 (xna:player-index-value :four)))
  (is (eq :two (xna:player-index-from-value 1))))
