;;;; keys.lisp --- Microsoft.Xna.Framework.Input.Keys and KeyState.
;;;;
;;;; Keys is projected the way every enum in CNA-Lisp is projected: a keyword per
;;;; member, a Common Lisp type over them, and conversions to and from the exact
;;;; numeric values. The 160 members and their values come from the CNA C ABI's
;;;; own key identities, generated rather than transcribed.

(in-package #:microsoft.xna.framework.input)

(defparameter *keys-table* (copy-alist cna-lisp.internal.ffi:*keys-table*)
  "Keyword name and exact value of every Keys member.")

(deftype keys ()
  "Microsoft.Xna.Framework.Input.Keys, as a keyword."
  '(satisfies keysp))

(defun keysp (object)
  (and (keywordp object) (assoc object *keys-table*) t))

(defun all-keys ()
  "Every Keys member, as keywords, in value order."
  (mapcar #'car *keys-table*))

(defun keys-value (key)
  "The exact value of a Keys member."
  (or (cdr (assoc key *keys-table*))
      (error 'microsoft.xna.framework:cna-usage-error
             :operation "keys-value"
             :format-control "~s is not a Keys member."
             :format-arguments (list key))))

(defun keys-from-value (value)
  "The Keys member a value names."
  (or (car (rassoc value *keys-table*))
      (error 'microsoft.xna.framework:cna-usage-error
             :operation "keys-from-value"
             :format-control "~d is not a Keys value."
             :format-arguments (list value))))

(defparameter *key-state-table* '((:up . 0) (:down . 1)))

(deftype key-state ()
  "Microsoft.Xna.Framework.Input.KeyState."
  '(member :up :down))

(defun key-state-value (state)
  (or (cdr (assoc state *key-state-table*))
      (error 'microsoft.xna.framework:cna-usage-error
             :operation "key-state-value"
             :format-control "~s is not a KeyState member."
             :format-arguments (list state))))

(defun key-state-from-value (value)
  (or (car (rassoc value *key-state-table*))
      (error 'microsoft.xna.framework:cna-usage-error
             :operation "key-state-from-value"
             :format-control "~d is not a KeyState value."
             :format-arguments (list value))))
