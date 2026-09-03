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

Signals CNA-NATIVE-LIBRARY-ERROR naming the exact path attempted when the
variable is unset, is not absolute, does not name an existing regular file, or
cannot be loaded. Returns the truename of the loaded library."
  (or *native-library-path*
      (let* ((requested (%resolve-requested-path))
             (path (pathname requested)))
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
