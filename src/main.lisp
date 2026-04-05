;;;; src/main.lisp
;;;;
;;;; CLI entry point for RSSM using CLIFF.

(defpackage #:com.djhaskin.rssm
  (:use #:cl)
  (:import-from #:com.djhaskin.cliff #:execute-program)
  (:import-from #:com.djhaskin.rssm/backend)
  (:import-from #:com.djhaskin.rssm/newsboat)
  (:import-from #:com.djhaskin.rssm/opml)
  (:import-from #:com.djhaskin.rssm/rsssavvy)
  (:use #:com.djhaskin.rssm/backend)
  (:local-nicknames (#:alex #:alexandria)
                    (#:cliff #:com.djhaskin.cliff)
                    (#:cliff/errors #:com.djhaskin.cliff/errors))
  (:export #:main #:convert-command #:execute-program))

(in-package #:com.djhaskin.rssm)

;;; Format Keyword Mapping

(defun format-keyword (str)
  "Convert format string to keyword symbol."
  (let ((normalized (string-downcase str)))
    (cond
      ((string= normalized "newsboat") :newsboat)
      ((or (string= normalized "json") (string= normalized "rsssavvy")) :rsssavvy)
      ((or (string= normalized "opml") (string= normalized "xml")) :opml)
      (t (error 'cliff/errors:exit-error
                :status :cl-usage-error
                :map-members `((:invalid-format . ,normalized)))))))

;;; Source Type Handling

(defun get-source-content (source source-type)
  "Get the content of the source based on source-type."
  (declare (type string source))
  (cond
    ((string= source-type "string") source)
    ((string= source-type "file")
     (let ((path (uiop:parse-native-namestring source)))
       (if (probe-file path)
           (with-open-file (strm path :external-format :utf-8)
             (let ((content (make-string (file-length strm))))
               (read-sequence content strm)
               content))
           (error 'cliff/errors:exit-error
                  :status :no-input-error
                  :map-members `((:file-not-found . ,source))))))
    (t (error 'cliff/errors:exit-error
              :status :cl-usage-error
              :map-members `((:invalid-source-type . ,source-type))))))

;;; Convert Command

(defun convert-command (options)
  "Execute the convert subcommand.
  Takes options hash table, returns result hash table."
  (let* ((source-format-str (gethash :source-format options))
         (dest-format-str (gethash :dest-format options))
         (source-type (or (gethash :source-type options) "string"))
         (source (gethash :source options))
         (output-path (gethash :output options))
         (status :successful)
         (message nil))

    ;; Validate required options
    (unless source-format-str
      (error 'cliff/errors:exit-error
             :status :cl-usage-error
             :map-members `((:missing-option . :source-format))))
    (unless dest-format-str
      (error 'cliff/errors:exit-error
             :status :cl-usage-error
             :map-members `((:missing-option . :dest-format))))
    (unless source
      (error 'cliff/errors:exit-error
             :status :cl-usage-error
             :map-members `((:missing-option . :source))))

    ;; Parse formats
    (let* ((source-format (format-keyword source-format-str))
           (dest-format (format-keyword dest-format-str))
           (source-content (get-source-content source source-type))
           (feeds nil)
           (output nil))

      ;; Parse source
      (handler-case
          (progn
            (setf feeds (parse-feeds-string source-format source-content)))
        (error (e)
          (setf status :data-format-error)
          (setf message (format nil "Failed to parse source: ~A" e))))

      ;; Render to destination if parsing succeeded
      (when (eql status :successful)
        (handler-case
            (progn
              (setf output (render-feeds-string dest-format feeds)))
          (error (e)
            (setf status :data-format-error)
            (setf message (format nil "Failed to render output: ~A" e)))))

      ;; Write output to destination (file or stdout)
      (when output
        (cond
          ((or (null output-path) (string= output-path "-"))
           ;; Write to stdout
           (write-string output *standard-output*))
          ((string= output-path "")
           ;; Empty path means stdout
           (write-string output *standard-output*))
          (t
           ;; Write to file
           (with-open-file (strm output-path
                                  :direction :output
                                  :if-exists :supersede
                                  :if-does-not-exist :create
                                  :external-format :utf-8)
             (write-string output strm)))))

      ;; Output result
      (let ((result (make-hash-table :test #'equal)))
        (setf (gethash :status result) status)
        (when output
          (setf (gethash :output result) output))
        (when message
          (setf (gethash :message result) message))
        (setf (gethash :source-format result) source-format-str)
        (setf (gethash :dest-format result) dest-format-str)
        (setf (gethash :feeds-count result) (loop for v being the hash-values of feeds
                                                  summing (length v)))
        result))))

;;; Help Documentation

(defparameter *convert-help*
  (format
    nil
    "~@{~@?~}"
    "Convert RSS feeds between different formats.~%"
    "~%"
    "Supported formats:~%"
    "  newsboat  - Newsboat URLs file format~%"
    "  json      - RSSSavvy JSON format~%"
    "  opml      - OPML XML format~%"
    "~%"
    "Options for convert command:~%"
    "  source-format (string) - Format of the input (newsboat/json/opml)~%"
    "  dest-format (string)    - Format of the output (newsboat/json/opml)~%"
    "  source (string)        - Input data or file path~%"
    "  source-type (string)   - Type of source: \"string\" (default) or \"file\"~%"
    "  output (string)        - Output file path (optional, stdout if not set)~%"))

;;; Main Entry Point

(defun main (argv)
  "Main entry point for the RSSM CLI."
  (sb-ext:exit
    :code
    (nth-value
      0
      (cliff:execute-program
        "rssm"
        :cli-arguments argv
        :defaults '((:source-type "string"))
        :cli-aliases
        '(("-h" . "help")
          ("--help" . "help")
          ("-s" . "--add-source-format")
          ("--source-format" . "--add-source-format")
          ("-d" . "--add-dest-format")
          ("--dest-format" . "--add-dest-format")
          ("-i" . "--add-source")
          ("--input" . "--add-source")
          ("-o" . "--set-output")
          ("--output" . "--set-output"))
        :setup (lambda (opts)
                 ;; Convert list arguments to single values where appropriate
                 (flet ((unwrap (key)
                          (let ((val (gethash key opts)))
                            (when (and (listp val) (null (cdr val)))
                              (setf (gethash key opts) (car val))))))
                   (unwrap :source-format)
                   (unwrap :dest-format)
                   (unwrap :source-type)
                   (unwrap :source)
                   (unwrap :output))
                 opts)
        :subcommand-functions
        (list (cons '("convert") #'convert-command))
        :subcommand-helps
        (list (cons '("convert") *convert-help*))
        :default-function
        (lambda (opts)
          (declare (ignore opts))
          (let ((result (make-hash-table :test #'equal)))
            (setf (gethash :status result) :successful)
            (setf (gethash :version result) "0.1.0")
            (setf (gethash :message result)
                  "Use 'rssm help convert' for conversion options")
            result))
        :default-func-help
        (format
          nil
          "~@{~@?~}"
          "RSSM - RSS Manager~%"
          "~%"
          "A tool for managing RSS feeds across Newsboat, RSSSavvy, and OPML formats.~%"
          "~%"
          "Usage:~%"
          "  rssm [options] [subcommand]~%"
          "~%"
          "Subcommands:~%"
          "  convert - Convert feeds between formats~%"
          "~%"
          "Use 'rssm help [subcommand]' for more information on a subcommand.~%")
        :suppress-final-output t))))