(defpackage #:com.djhaskin.rssm/newsboat
  (:use #:cl)
  (:import-from #:com.djhaskin.cliff)
  (:import-from #:com.djhaskin.rssm/backend)
  (:use #:com.djhaskin.rssm/backend)
  (:local-nicknames (#:alex #:alexandria))
  (:export #:parse-newsboat-line
           #:parse-newsboat-string
           #:render-newsboat-line
           #:render-newsboat-string
           #:newsboat-tokenize-with-quotes
           #:parse-quoted-token
           #:parse-unquoted-token
           ;; Method definitions for generic functions
           #:parse-feeds
           #:render-feeds))

(in-package #:com.djhaskin.rssm/newsboat)

;;; Helpers for parsing

(defun string-empty-p (value)
  (or (null value)
      (string= value "")))

(defun trim-or-nil (value)
  (let ((trimmed (and value (string-trim '(#\Space #\Tab #\Newline) value))))
    (unless (string-empty-p trimmed)
      trimmed)))

(defun split-lines (text)
  (with-input-from-string (in text)
    (loop for line = (read-line in nil nil)
          while line
          collect line)))

(defun parse-quoted-token (text start)
  (let ((len (length text))
        (i (1+ start)))
    (with-output-to-string (out)
      (loop while (< i len)
            for ch = (char text i)
            do (cond
                 ((char= ch #\\)
                  (incf i)
                  (when (< i len)
                    (write-char (char text i) out)))
                 ((char= ch #\")
                  (return (values (get-output-stream-string out) (1+ i)
                                  t)))
                 (t
                  (write-char ch out)))
            do (incf i))
      (values (get-output-stream-string out) i t))))

(defun parse-unquoted-token (text start)
  (let ((len (length text))
        (i start))
    (loop while (< i len)
          for ch = (char text i)
          while (not (find ch '(#\Space #\Tab #\Newline #\Return)))
          do (incf i))
    (values (subseq text start i) i nil)))

(defun newsboat-tokenize-with-quotes (text)
  (let ((tokens '())
        (i 0)
        (len (length text)))
    (labels ((skip-space ()
               (loop while (and (< i len)
                                (find (char text i)
                                      '(#\Space #\Tab #\Newline #\Return)))
                     do (incf i))))
      (loop
        (skip-space)
        (when (>= i len)
          (return (nreverse tokens)))
        (multiple-value-bind (token new-i quoted)
            (if (char= (char text i) #\")
                (parse-quoted-token text i)
                (parse-unquoted-token text i))
          (setf i new-i)
          (push (cons token quoted) tokens))))))

;;; Parsing functions

(defun parse-newsboat-line (line feed-class)
  (let ((trimmed (trim-or-nil line)))
    (when (and trimmed
               (not (alex:starts-with-subseq "#" trimmed))
               (not (alex:starts-with-subseq "query:" trimmed)))
      (let* ((tokens (newsboat-tokenize-with-quotes trimmed))
             (url (and tokens (caar tokens)))
             (rest (cdr tokens))
             (title nil)
             (folder nil))
        (when rest
          (if (cdar rest)
              (progn
                (setf title (caar rest))
                (when (cdr rest)
                  (setf folder (caar (cdr rest)))))
              (setf folder (caar rest))))
        (when (trim-or-nil url)
          (make-instance feed-class
                         :xml-url (trim-or-nil url)
                         :title (trim-or-nil title)
                         :folder (trim-or-nil folder)))))))

(defun parse-newsboat-string (text feed-class)
  (loop for line in (split-lines text)
        for parsed = (parse-newsboat-line line feed-class)
        when parsed
          collect parsed))

;;; Rendering functions

(defun render-newsboat-line (feed xml-url-accessor title-accessor folder-accessor)
  (let ((url (funcall xml-url-accessor feed))
        (title (funcall title-accessor feed))
        (folder (funcall folder-accessor feed)))
    (with-output-to-string (out)
      (write-string url out)
      (when (trim-or-nil title)
        (format out " \"~a\"" (string-right-trim '(#\") title)))
      (when (trim-or-nil folder)
        (format out " ~a" folder)))))

(defun render-newsboat-string (feeds xml-url-accessor title-accessor folder-accessor)
  (format nil "~{~a~%~}"
          (mapcar (lambda (f)
                    (render-newsboat-line f xml-url-accessor title-accessor folder-accessor))
                  feeds)))

;;; Method definitions for generic functions

(defmethod parse-feeds ((format (eql :newsboat)) text &optional (feed-class 'feed))
  (parse-newsboat-string text feed-class))

(defmethod render-feeds ((format (eql :newsboat)) feeds
                         &key (xml-url-accessor #'feed-xml-url)
                           (title-accessor #'feed-title)
                           (folder-accessor #'feed-folder))
  (render-newsboat-string feeds xml-url-accessor title-accessor folder-accessor))
