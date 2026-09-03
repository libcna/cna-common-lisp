;;;; types.lisp --- CFFI type foundations for the CNA C ABI.
;;;;
;;;; The CNA C ABI uses only fixed-width scalars, so nothing here depends on a
;;;; platform's notion of `int` or `long`. The generated declarations use the
;;;; :uintN / :intN keywords directly; the names below exist so the rest of the
;;;; private layer can talk about ABI concepts rather than widths.

(in-package #:cna-lisp.internal.ffi)

(defctype cna-result :uint32
  "Fixed-width result code returned by every fallible CNA C API operation.")

(defctype cna-bool :uint8
  "Fixed-width Boolean representation used by the CNA C API.")

(defctype cna-handle :uint64
  "Opaque generation-checked CNA object handle.")

(declaim (inline cna-true-p cna-bool-of))

(defun cna-true-p (value)
  "True when VALUE is the CNA C ABI's true."
  (= value 1))

(defun cna-bool-of (generalized)
  "The CNA C ABI byte for a generalized Boolean."
  (if generalized 1 0))
