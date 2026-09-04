;;;; package.lisp --- the private packages of CNA-Lisp.
;;;;
;;;; Every package defined here is an implementation detail. Their names say so
;;;; and tests/structure/public-surface.lisp proves that no symbol of theirs
;;;; reaches a public package.
;;;;
;;;; CNA-LISP.INTERNAL.FFI is the only package that knows the CNA C ABI exists.
;;;; Everything above it speaks in Lisp values and Lisp conditions.

(in-package #:cl-user)

(defpackage #:cna-lisp.internal.ffi
  (:documentation
   "Private CFFI declarations for the CNA C ABI. Nothing outside CNA-Lisp may
use this package; its contents are regenerated from the canonical CNA headers
by tools/native-abi/generate.py.")
  (:use #:cl #:cffi)
  (:export
   ;; the generated tables the runtime and the ABI gate read
   #:*native-struct-layouts*
   #:*bound-native-functions*
   #:*keys-table*
   #:*surface-format-table*
   ;; callbacks
   #:lifecycle-callback-pointer
   #:game-event-callback-pointer
   #:resource-disposing-callback-pointer
   #:*lifecycle-dispatcher*
   #:*game-event-dispatcher*
   #:*resource-disposing-dispatcher*
   #:content-lost-callback-pointer
   #:component-callback-pointers #:*component-dispatcher*
   #:component-event-callback-pointer #:*component-event-dispatcher*
   #:component-collection-callback-pointer #:*component-collection-dispatcher*
   #:*buffer-content-lost-dispatcher*
   #:*begin-draw-dispatcher*
   ;; constants the runtime reads by name
   #:+mouse-button-left+ #:+mouse-button-middle+ #:+mouse-button-right+
   #:+mouse-button-x1+ #:+mouse-button-x2+
   ;; type helpers
   #:cna-true-p #:cna-bool-of))

(defpackage #:cna-lisp.internal
  (:documentation
   "Private CNA-Lisp runtime: native library resolution, the ABI gate, result
translation, UTF-8 conversion, thread affinity, ownership and the callback
registry. Private; not part of the published API.")
  (:use #:cl)
  (:local-nicknames (#:ffi #:cna-lisp.internal.ffi))
  (:export
   ;; native library -------------------------------------------------------
   #:ensure-native-library #:native-library-path #:native-library-loaded-p
   #:check-qualified-host #:qualified-host-mismatch #:host-facts #:*host-facts*
   #:*native-library-path*
   #:ensure-shim-library #:shim-loaded-p #:shim-library-path
   #:shim-entry-point #:refuse-without-shim
   ;; ABI gate -------------------------------------------------------------
   #:ensure-abi-admitted #:admitted-abi-versions #:loaded-abi-version
   #:decode-abi-version #:encode-abi-version #:format-abi-version
   #:verify-struct-layouts
   ;; results --------------------------------------------------------------
   #:check-result #:result-name #:last-native-message #:last-error-category
   #:+result-success+ #:+result-callback+
   ;; utf8 -----------------------------------------------------------------
   #:string-to-utf8-octets #:utf8-octets-to-string #:with-utf8-view
   #:with-string-view-args #:count-then-copy-string
   ;; utf16 ----------------------------------------------------------------
   #:utf-16-code-unit #:string-code-units #:code-units-to-string
   #:high-surrogate-p #:low-surrogate-p
   ;; threads --------------------------------------------------------------
   #:current-thread-token #:same-thread-p #:check-owner-thread
   ;; ownership ------------------------------------------------------------
   #:native-object #:handle-of #:owner-of #:owner-generation-of
   #:owner-thread-of #:ownership-of #:disposed-state-of
   #:register-child #:unregister-child #:children-of
   #:check-live #:check-usable #:destroy-native #:invalidate
   #:next-generation #:active-game #:stale-p #:generation-of
   ;; callback registry ----------------------------------------------------
   #:register-callback-target #:unregister-callback-target
   #:callback-target #:callback-registry-count #:map-callback-registry
   #:in-callback-scope-p #:call-with-callback-scope
   #:with-contained-callback #:*pending-callback-condition*
   #:take-pending-callback-condition #:release-callback-error-buffer
   #:call-native-frame
   ;; floating point ---------------------------------------------------------
   #:with-binary32-semantics #:nan-p #:infinity-p #:negative-zero-p
   #:single-float-bits #:bits-single-float))

(defpackage #:cna-lisp.internal.framework
  (:documentation "Private tables and helpers for the Microsoft.Xna.Framework projection.")
  (:use #:cl)
  (:export #:*predefined-colors*))

(defpackage #:cna-lisp.internal.input
  (:documentation "Private tables and helpers for the Microsoft.Xna.Framework.Input projection.")
  (:use #:cl)
  (:export #:*keys-table*))

(defpackage #:cna-lisp.internal.abi
  (:documentation "Private ABI reporting helpers used by tools and tests only.")
  (:use #:cl)
  (:local-nicknames (#:ffi #:cna-lisp.internal.ffi)
                    (#:int #:cna-lisp.internal))
  (:export #:abi-report #:bound-function-names #:bound-struct-names))
