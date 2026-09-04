;;;; native-library.lisp --- the one place CNA-Lisp resolves its native library.
;;;;
;;;; There is exactly one resolver, and it is deliberately unhelpful: it loads
;;;; the library the environment names and nothing else. It does not search
;;;; sibling development checkouts, does not look inside build directories, and
;;;; does not pick up a CNA that happens to be on the loader path. A binding
;;;; that guesses which native library it is talking to cannot make any of the
;;;; ABI claims this one makes.

(in-package #:cna-lisp.internal)

(defvar *native-library-path* nil
  "Absolute path of the CNA C ABI shared library this image loaded, or NIL.")

(defvar *native-library-handle* nil)

(defparameter +native-library-environment-variable+ "CNA_NATIVE_LIBRARY"
  "The environment variable that names the CNA C ABI shared library to load.")

(defun native-library-loaded-p ()
  "True once a CNA native library has been loaded into this image."
  (and *native-library-handle* t))

(defun native-library-path ()
  "The absolute path of the loaded CNA native library, or NIL."
  *native-library-path*)

(defparameter +qualified-host+
  '(:machine "X86-64" :software "Linux" :implementation "SBCL")
  "The one host the flattened foreign layer is correct for.

Not a preference and not a support policy: a *correctness* precondition. The
whole by-value story in docs/native-abi.md is the System V AMD64 ABI's rule, and
the generator flattened every by-value aggregate according to it -- CNA_Vector3
travels as a :double and a :float because that is what SysV does with two SSE
eightbytes. The Microsoft x64 ABI does not do that: a 12-byte aggregate goes by
*reference* there. Calling a CNA route through the SysV flattening on Windows
x64 would not be an unqualified configuration, it would be the wrong calling
convention -- arguments in the wrong registers, silently.

So the refusal is at the native boundary and nowhere earlier. Pure managed
CNA-Lisp -- the math types, the bounding volumes, the Curve family, the packed
vectors -- is ordinary ANSI Common Lisp and loads and runs anywhere; it is
opening the foreign layer that is refused.")

(defvar *host-facts* nil
  "NIL to ask the running image, or a plist overriding it.

Rebinding this is how the refusal below is tested: there is no honest way to run
this suite on a Windows x64 image, and faking the answer is better than faking
the *function* -- an encapsulation of MACHINE-TYPE is at the mercy of whether the
compiler folded the call.")

(defun host-facts ()
  "What this image is, as :MACHINE, :SOFTWARE and :IMPLEMENTATION."
  (or *host-facts*
      (list :machine (machine-type)
            :software (software-type)
            :implementation (lisp-implementation-type))))

(defun qualified-host-mismatch ()
  "Which part of the host disagrees with the qualified one, or NIL."
  (let* ((facts (host-facts))
         (machine (string-upcase (or (getf facts :machine) "")))
         (software (string-upcase (or (getf facts :software) "")))
         (implementation (string-upcase (or (getf facts :implementation) ""))))
    (cond ((not (search "X86-64" machine))
           (format nil "the machine is ~a, not x86-64" (machine-type)))
          ((not (search "LINUX" software))
           (format nil "the operating system is ~a, not Linux" (software-type)))
          ((not (search "SBCL" implementation))
           (format nil "the implementation is ~a, not SBCL"
                   (lisp-implementation-type)))
          (t nil))))

(defun check-qualified-host (operation)
  "Refuse to open the native boundary on a host the flattening is not correct for."
  (let ((mismatch (qualified-host-mismatch)))
    (when mismatch
      (error 'microsoft.xna.framework:cna-not-supported-error
             :operation operation
             :format-control
             "CNA-Lisp's foreign layer is qualified for SBCL on Linux x86-64 only, and ~
              ~a. This is refused rather than attempted because the refusal is about ~
              *correctness*, not support: every by-value aggregate in the bound surface ~
              is flattened according to the System V AMD64 ABI -- a CNA_Vector3 travels ~
              as a double and a float because that is what SysV does with two SSE ~
              eightbytes -- and another host ABI passes those arguments somewhere else. ~
              Calling through the wrong convention would put arguments in the wrong ~
              registers and report nothing. Everything in CNA-Lisp that touches no ~
              native route runs here unaffected; see docs/native-abi.md."
             :format-arguments (list mismatch))))
  t)

(defun %resolve-requested-path ()
  (let ((raw (uiop:getenv +native-library-environment-variable+)))
    (when (or (null raw) (string= raw ""))
      (error 'microsoft.xna.framework:cna-native-library-error
             :operation "resolve-native-library"
             :native-library-path nil
             :format-control
             "~a is not set. CNA-Lisp loads exactly the CNA C ABI shared library that ~
              variable names and searches nowhere else; set it to the absolute path of a ~
              qualified libcna_c_api.so."
             :format-arguments (list +native-library-environment-variable+)))
    raw))

(defun ensure-native-library ()
  "Load the CNA C ABI shared library named by CNA_NATIVE_LIBRARY.

Refuses with CNA-NOT-SUPPORTED-ERROR on a host the foreign layer is not qualified
for, before anything is loaded -- see CHECK-QUALIFIED-HOST, which is about the
calling convention and not about support. Then signals CNA-NATIVE-LIBRARY-ERROR
naming the exact path attempted when the variable is unset, is not absolute, does
not name an existing regular file, or cannot be loaded. Returns the truename of
the loaded library."
  (or *native-library-path*
      (let* ((ignored (check-qualified-host "load-native-library"))
             (requested (%resolve-requested-path))
             (path (pathname requested)))
        (declare (ignore ignored))
        (unless (uiop:absolute-pathname-p path)
          (error 'microsoft.xna.framework:cna-native-library-error
                 :operation "resolve-native-library"
                 :native-library-path requested
                 :format-control
                 "~a must be an absolute path; ~s is relative. CNA-Lisp refuses to resolve ~
                  it against the current directory, because which library got loaded would ~
                  then depend on where the process was started."
                 :format-arguments (list +native-library-environment-variable+ requested)))
        (let ((truename (probe-file path)))
          (unless truename
            (error 'microsoft.xna.framework:cna-native-library-error
                   :operation "resolve-native-library"
                   :native-library-path requested
                   :format-control "~a names ~s, which does not exist."
                   :format-arguments (list +native-library-environment-variable+ requested)))
          (when (uiop:directory-pathname-p truename)
            (error 'microsoft.xna.framework:cna-native-library-error
                   :operation "resolve-native-library"
                   :native-library-path requested
                   :format-control "~a names ~s, which is a directory, not a shared library."
                   :format-arguments (list +native-library-environment-variable+ requested)))
          (handler-case
              (setf *native-library-handle*
                    (cffi:load-foreign-library (namestring truename)))
            (error (condition)
              (error 'microsoft.xna.framework:cna-native-library-error
                     :operation "load-native-library"
                     :native-library-path (namestring truename)
                     :format-control "cannot load ~s: ~a"
                     :format-arguments (list (namestring truename) condition))))
          (setf *native-library-path* (namestring truename))))))


;;; --- the optional private shim ---------------------------------------------
;;;
;;; A handful of CNA routes take an aggregate by value that the System V AMD64
;;; ABI classifies MEMORY, which CFFI cannot pass without cffi-libffi. The
;;; generator proves that refusal and emits the smallest thing that gets past it:
;;; a wrapper that takes the aggregate by pointer and the real route by function
;;; pointer, and does nothing but the one ABI transition.
;;;
;;; It is optional on purpose. A released CNA-Lisp must load with no C toolchain,
;;; so the shim is not shipped prebuilt; CNA_LISP_SHIM names a build of it, and
;;; the members that need it refuse with an actionable condition when it is
;;; absent. Nothing else in the binding depends on it.

(defvar *shim-library-path* nil
  "Absolute path of the loaded private shim, or NIL.")

(defvar *shim-library-handle* nil)

(defparameter +shim-library-environment-variable+ "CNA_LISP_SHIM")

(defun shim-loaded-p ()
  "True once the optional private shim has been loaded."
  (and *shim-library-handle* t))

(defun shim-library-path ()
  *shim-library-path*)

(defun ensure-shim-library ()
  "Load the private shim if CNA_LISP_SHIM names one. Answers T when it is loaded.

Never signals for a missing variable: the shim is optional, and its absence is
reported by the member that needed it, not by the loader."
  (or (shim-loaded-p)
      (let ((requested (uiop:getenv +shim-library-environment-variable+)))
        (when (and requested (string/= requested ""))
          (let ((truename (probe-file (pathname requested))))
            (unless truename
              (error 'microsoft.xna.framework:cna-native-library-error
                     :operation "load-shim-library"
                     :native-library-path requested
                     :format-control "~a names ~s, which does not exist."
                     :format-arguments (list +shim-library-environment-variable+ requested)))
            (handler-case
                (setf *shim-library-handle*
                      (cffi:load-foreign-library (namestring truename))
                      *shim-library-path* (namestring truename))
              (error (condition)
                (error 'microsoft.xna.framework:cna-native-library-error
                       :operation "load-shim-library"
                       :native-library-path (namestring truename)
                       :format-control "cannot load the shim ~s: ~a"
                       :format-arguments (list (namestring truename) condition))))
            t)))))

(defun shim-entry-point (shim-name)
  "The shim wrapper named SHIM-NAME, or NIL when the shim is not available."
  (ensure-shim-library)
  (and (shim-loaded-p) (ignore-errors (cffi:foreign-symbol-pointer shim-name))))

(defun refuse-without-shim (operation shim-name reason)
  (error 'microsoft.xna.framework:cna-not-supported-error
         :operation operation
         :format-control
         "~a needs the optional private CNA-Lisp shim, which is not loaded.~%~
          Why it needs one: ~a~%~
          Build it with `tools/native-abi/verify.sh <cna-header-root>' and point ~
          ~a at the resulting build-probe/libcna-lisp-shim.so. Everything else in ~
          CNA-Lisp works without it. (Wanted the entry point ~a.)"
         :format-arguments (list operation reason
                                 +shim-library-environment-variable+ shim-name)))
