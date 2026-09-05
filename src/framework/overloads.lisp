;;;; overloads.lisp --- keyword sets that name a CLR overload, and nothing else.
;;;;
;;;; A projection may narrow, but it may not *gain* a member. Where several CLR
;;;; overloads share one name, this binding gives them one generic function whose
;;;; supplied keywords select between them -- and a `&key' lambda list is then the
;;;; wrong shape for the job by construction:
;;;;
;;;;   * every keyword it names is optional, so a caller may supply any subset;
;;;;   * a default fills in what was left out, so that subset silently becomes a
;;;;     longer overload's argument list;
;;;;   * `&allow-other-keys' -- which CLOS congruence forces on a method whose
;;;;     generic function is shared with another class -- accepts keywords the
;;;;     method has never heard of, and ignores them.
;;;;
;;;; Each of those turns "the overloads XNA has" into "the overloads XNA has,
;;;; plus everything in between". `SoundEffect.Play' is the case that produced
;;;; this file: XNA has `Play()' and `Play(float, float, float)' and nothing
;;;; between, and a lambda list of `&key volume pitch pan' accepted six shapes
;;;; that are neither -- `:VOLUME' alone, `:PITCH' alone, and four more.
;;;;
;;;; **The structural verifier cannot catch this, and no longer claims to.** What
;;;; it proves about a `distinguished_by: keywords' collapse is that the declared
;;;; keyword sets *differ*, so that no two overloads vanish into each other. That
;;;; two declarations differ says nothing about what the running function accepts;
;;;; the declared sets for `Play' were correct while the method accepted six
;;;; shapes neither of them describes. Whether only the complete sets are accepted
;;;; is a property of the code, and this is where it is enforced.
;;;; `tools/api-compat/mapping-rules.json' says the same thing in the same words,
;;;; because a rule that overstates what checks it is a claim like any other.

(in-package #:microsoft.xna.framework)

(defun %overload-shape-name (keywords)
  "How one overload's keyword set is spelled in a refusal."
  (if (null keywords)
      "no keyword at all"
      (format nil "~{:~a~^ + ~}"
              (mapcar (lambda (k) (string-upcase (string k))) keywords))))

(defun %normalise-keyword-set (keywords)
  "KEYWORDS as a sorted set of lower-case names.

Duplicates are removed because a repeated initarg is legal Common Lisp and does
not change the shape: `(make-instance 'c :offset 0 :offset 2)' is a call with one
`:OFFSET', whose value is the first, and treating it as two would refuse a
program the language accepts."
  (sort (remove-duplicates
         (mapcar (lambda (k) (string-downcase (string k))) keywords)
         :test #'string=)
        #'string<))

(defun %check-overload-keywords (operation supplied overloads &key object-type)
  "Refuse a keyword set naming no overload, and answer the tag of the one it names.

OVERLOADS is an alist of `(TAG . KEYWORDS)': one entry per CLR overload the
generic function collapses, TAG naming it for the caller's own dispatch and
KEYWORDS being the **complete** set of keywords that overload is spelled with.
The list order is the order the shapes are offered in a refusal, so the shortest
belongs first.

SUPPLIED is the set the caller actually gave, as symbols or strings in any order.
It is compared as a *set*, and equality is the whole point: a subset of a legal
shape, a superset of one, and any mixture of two are each refused, because each
of them is a call the original cannot express. Filling the difference in with a
default would answer a question the caller did not ask -- which is exactly how
`(play effect :volume 0.5)' came to mean `Play(0.5f, 0.0f, 0.0f)', a call XNA has
no overload for.

Answers the matching entry's TAG, so a caller branches on the overload that was
selected rather than re-deriving it from supplied-p variables that have already
been thrown away."
  (let* ((given (%normalise-keyword-set supplied))
         (match (find-if (lambda (entry)
                           (equal given (%normalise-keyword-set (rest entry))))
                         overloads)))
    (unless match
      (error 'cna-usage-error
             :operation operation :object-type object-type
             :format-control
             "~a was given ~a, which names none of the original's ~d overload~:p. ~
              Each of those is a complete argument list rather than a bag of ~
              options, so a keyword may not be dropped from one or added to it: ~
              the shapes that exist are ~{~a~^; ~}."
             :format-arguments
             (list operation (%overload-shape-name supplied) (length overloads)
                   (mapcar (lambda (entry) (%overload-shape-name (rest entry)))
                           overloads))))
    (first match)))

(defun %supplied-keywords (&rest name-and-flag)
  "The keywords of NAME-AND-FLAG whose supplied-p flag is true, in order.

Spelled as pairs so that the call site reads as the lambda list it mirrors:

    (%supplied-keywords \"volume\" volume-p \"pitch\" pitch-p \"pan\" pan-p)"
  (loop for (name flag) on name-and-flag by #'cddr
        when flag collect name))
