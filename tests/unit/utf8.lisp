;;;; utf8.lisp --- exact UTF-8 conversion.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

(test utf8-round-trips-non-ascii
  (dolist (string '("" "ascii" "Ünïcödé" "спайк" "日本語" "é" "✓ — ✗"))
    (is (string= string (int:utf8-octets-to-string (int:string-to-utf8-octets string)))
        "~s did not survive a UTF-8 round trip" string)))

(test utf8-byte-counts-are-exact
  ;; The ABI counts bytes, never characters, and never a terminator.
  (is (= 0 (length (int:string-to-utf8-octets ""))))
  (is (= 5 (length (int:string-to-utf8-octets "ascii"))))
  (is (= 2 (length (int:string-to-utf8-octets "é"))))
  (is (= 3 (length (int:string-to-utf8-octets "日"))))
  (is (= 4 (length (int:string-to-utf8-octets (string (code-char #x1F600)))))))

(test utf8-view-passes-a-valid-pointer-for-an-empty-string
  ;; A zero-length view must still carry a pointer CNA can dereference-check.
  (int:with-utf8-view (data length "")
    (is (= 0 length))
    (is (not (cffi:null-pointer-p data)))))

(test utf8-view-writes-the-exact-bytes
  (let ((expected (int:string-to-utf8-octets "Ünïcödé")))
    (int:with-utf8-view (data length "Ünïcödé")
      (is (= length (length expected)))
      (dotimes (i length)
        (is (= (aref expected i) (cffi:mem-aref data :uint8 i)))))))

(test utf8-view-carries-an-embedded-nul-rather-than-truncating
  ;; The view is pointer-plus-length, so an embedded NUL is data, not a
  ;; terminator. CNA is what refuses it; the conversion must not silently cut.
  (let ((string (format nil "a~ab" (code-char 0))))
    (int:with-utf8-view (data length string)
      (is (= 3 length))
      (is (= 0 (cffi:mem-aref data :uint8 1))))))
