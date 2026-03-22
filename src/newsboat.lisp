;;;; rssm/src/newsboat.lisp
;;;;
;;;; Newsboat format support for RSSM.

(defpackage #:com.djhaskin.rssm/newsboat
  (:use #:cl)
  (:import-from #:com.djhaskin.cliff)
  (:import-from #:com.djhaskin.rssm/backend)
  (:import-from #:cl-ppcre)
  (:import-from #:str)
  (:use #:com.djhaskin.rssm/backend)
  (:local-nicknames (#:alex #:alexandria
                     #:com.djhaskin.rssm/backend #:backend))
  (:export #:parse-feeds-file
           #:render-feeds-file))

(in-package #:com.djhaskin.rssm/newsboat)

(defun read-quoted (strm)
  "Reads a quoted string from the newsboat file.
  Assumes the leading quote has already been read."
  (loop for c = (read-char strm) then (read-char strm)
        for in-escape = nil
        for result = (make-array 10 :fill-pointer t :adjustable t :element-type
                                 'character)
        while (not (char= c #\"))
        do
        (cond (in-escape
               (setf in-escape nil)
               (vector-push-extend c result))
              ((char= c #\\)
               (setf in-escape t))
              (:else
               (vector-push-extend c result)))
        return (coerce result 'string)))

(defun next-token (strm)
  "
  Reads the next 'thing' in the newsboat URL file.
  "
  (let ((c (read-char strm nil :eof)))
    (cond ((or
             (eql c :eof)
             (char= c #\Newline))
             nil)
          ((char= c #\")
           (read-quoted strm))
          (:else
           (loop for c = c then (read-char strm nil :eof)
                 while (and
                         (not (eql c :eof))
                         (not (char= c #\Newline))
                         (not (char= c #\Space)))
                 collect c into chars
                 finally (return (coerce chars 'string)))))))

(defun read-next-line (strm)
  "
  Reads the next line from the newsboat URL file, returning what it finds.
  "

  (let ((line-tokens
          (loop for token = (next-token strm) then (next-token strm)
                while token
                collect token))
        (first-token (car line-tokens)))
    (or
      (cl-ppcre:register-groups-bind
        (folder-name folder-tag)
        ("^query:([^:}+):unread = \"yes\" and tags +[#] +\"([^\"]+)\"$"
         first-token)
        (declare (ignore folder-name))
        (assert (eql (length line-tokens) 1))
        (values :folder folder-tag))
      (cl-ppcre:register-groups-bind
        (xml-url)
        ("^(https?://\S+)$"
         first-token)
        (assert (eql (length line-tokens) 3))
        (assert (char= (aref (cdar line-tokens) 0) #\~))
        (let ((title (subseq (cdar line-tokens) 1))
              (folder-tag (cddar line-tokens)))
          (values :feed (make-instance 'feed :url xml-url :title title :folder folder-tag))))
      (values :unrecognized line-tokens))))

(defmethod backend:parse-feeds ((fmt (eql :newsboat)) strm)
    (let ((feeds nil)
        (loop for (kind . data) = (read-next-line strm)
            while kind
            do
            (cond ((eq type :folder)
                     (setf (assoc data feeds) nil))
                    ((eq type :feed)
                     (backend:add-feed feeds data))
                    (:else
                     (warn "Unrecognized line in newsboat URL file: ~a" data))))
        feeds)))

(defmethod backend:render-feeds ((fmt (eql :newsboat)) feeds strm)
    (loop for (folder . folder-feeds) in feeds
        do
        (format strm "\"query:~a:unread = \\\"yes\\\" and tags # \\\"~a\\\"\"~%"
                folder folder)
        (loop for feed in folder-feeds
            do
            (format strm "~a" feed-xml-url)
            (when (feed-title feed)
              (format strm " \"~~~a\"" (feed-title feed)))
            (format strm " \"~a\"" (feed-folder feed)))))
