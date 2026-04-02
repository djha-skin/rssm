;;;; rssm/src/newsboat.lisp
;;;;
;;;; Newsboat format support for RSSM.
;;;;
;;;; The purpose of this file is to implement `backend:parse-feeds` and
;;;; `backend:render-feeds` for the newsboat format. Thus, no exports need be
;;;; made.
;;;;
;;;; A newsboat `urls` file consists of a series of lines. Each line has
;;;; precisely one URL at the beginning of the line followed by zero or more
;;;; space-separated tags. The tags may be prepended by `~`, as in
;;;; `~TitleOfFeed`, to indicate that they are "custom names" of the feed. The
;;;; tags may be prepended by `!` to indicate that within that tag group, the
;;;; feed is hidden. A single `!` without any other part of the tag name coming
;;;; after it indicates that the feed should be hidden everywhere. Finally, anbcy
;;;; of these tokens can be quoted using double quotes with
;;;; quotes-within-quotes backslach-escaped to allow for spaces within the
;;;; tokens.
;;;;
;;;; Knowing this, we should for `backend:render-feeds` simply put something like
;;;; `"<url>" "~<title>" "<folder>"` on each line.
;;;;
;;;; The `backend:parse-feeds` function is more complicated, since the format
;;;; is somewhat liberal.
;;;;

#+(or)
(progn
  (asdf:load-system "com.djhaskin.rssm"))
(defpackage #:com.djhaskin.rssm/newsboat
  (:use #:cl)
  (:import-from #:com.djhaskin.rssm/backend)
  ; Grap serapeum
  (:import-from #:serapeum)
  (:import-from #:quri
    #:make-uri
    #:string-prefix-p)
  (:local-nicknames (#:backend #:com.djhaskin.rssm/backend)
                    (#:s #:serapeum))
  (:export #:parse-feeds
           #:render-feeds))

(in-package #:com.djhaskin.rssm/newsboat)


#+(or)
(progn
  (with-input-from-string (s "\"query:folder:unread = \\\"yes\\\" and tags # \\\"tag1\\\"\"")
    (read-quoted s)))

(defun read-quoted (strm)
  "Reads a quoted string from the newsboat file.
  Assumes the leading quote has already been read."
  (assert (char= #\" (read-char strm))) ; Skip the opening quote
  (loop for c = (read-char strm) then (read-char strm)
        with in-escape = nil
        with result = (make-array 10 :fill-pointer 0 :adjustable t :element-type
                                 'character)
        do
        (cond (in-escape
               (setf in-escape nil)
               (vector-push-extend c result))
              ((char= c #\")
               (loop-finish))
              ((char= c #\\)
               (setf in-escape t))
              (:else
               (vector-push-extend c result)))
        finally (return (coerce result 'string))))

(defun render-quoted (strm)
  "Quotes a string for use in the newsboat URL file."
    (format strm "\"")
    (loop for c across str
          do
          (cond ((char= c #\")
                 (format out "\\\""))
                ((char= c #\\)
                 (format out "\\\\"))
                (:else
                 (format out "~a" c))))
    (format out "\""))

(defclass newsboat-tag ()
  ((hidden
    :initarg :hidden
    :accessor newsboat-tag-hidden
    :initform nil
    :documentation "Whether this tag is hidden.")
   (custom-name
    :initarg :title
    :accessor newsboat-tag-title
    :initform nil
    :documentation "Whether or not the tag is a custom name.")
   (value
    :initarg :value
    :accessor newsboat-tag-value
    :initform nil
    :documentation "The value of the tag.")))

(defclass newsboat-feed ()
  ((url
     :initarg :url
     :accessor newsboat-feed-url
     :initform nil
     :documentation "The URL of the RSS feed or virtual feed query.")
   (tags
     :initarg :tags
     :accessor newsboat-feed-tags
     :initform nil
     :documentation "The list of tags associated with this feed.")))

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

(defun token-to-tag (token)
    "
    Converts a newsboat URL file token into a newsboat-tag object.
    "
    (let ((hidden nil)
          (custom-name nil)
          (value nil)
          (next-spot 0))
      (when (or (char= (aref token next-spot) #\!)
                (char= (aref token next-spot) #\~))
        (if (char= (aref token 0) #\!)
            (setf hidden t)
            (setf custom-name t))
        (setf next-spot (1+ next-spot)))
      (when (or (char= (aref token next-spot) #\!)
                (char= (aref token next-spot) #\~))
        (if (char= (aref token 0) #\!)
            (setf hidden t)
            (setf custom-name t))
        (setf next-spot (1+ next-spot)))
      (setf value (subseq token next-spot))
      (make-instance 'newsboat-tag
                   :hidden hidden
                   :custom-name custom-name
                   :value value)))

(defun concrete-feed-p (feed)
  "
  Returns true if the feed is a virtual feed query, false otherwise.
  "

  (not (string-prefix-p "query:" (newsboat-feed-url feed))))

(defun newsboat-to-generic (feed)
  "
  Converts a newsboat-feed object into a generic feed object.
  "

  (make-instance 'backend:feed
                 :title (or (some (lambda (tag)
                                    (and (newsboat-tag-title tag)
                                         (newsboat-tag-value tag)))
                                  (newsboat-feed-tags feed))
                            nil)
                 :xml-url (newsboat-feed-url feed)
                 :folder (or (some (lambda (tag)
                                    (and
                                     (not (newsboat-tag-custom-name tag))
                                     (newsboat-tag-value tag)))
                                  (newsboat-feed-tags feed))
                            nil)))

(defun read-next-line (strm)
  "
  Reads the next line from the newsboat URL file, returning what it finds.
  "
  (let ((line-tokens
          (loop for token = (next-token strm) then (next-token strm)
                while token
                collect token)))
    (make-instance
      'newsboat-feed
       :url (quri:make-uri (car line-tokens))
       :tags (mapcar #'token-to-tag (cdr line-tokens)))))

(defmethod backend:parse-feeds ((fmt (eql :newsboat)) strm)
  (loop for newsfeed = (read-next-line strm)
        while newsfeed
        if (concrete-feed-p newsfeed)
        collect (newsboat-to-generic newsfeed)))

(defmethod backend:render-feeds ((fmt (eql :newsboat)) feeds strm)
    (loop for (folder . folder-feeds) in feeds
        do
        (format strm "\"query:~a:unread = \\\"yes\\\" and tags # \\\"~a\\\"\"~%"
                folder folder)
        (loop for feed in folder-feeds
            do
            (render-quoted strm (feed-xml-url feed))
            (format strm " ")
            (loop for 

            (format strm "~a" feed-xml-url)
            (when (feed-title feed)
              (format strm " \"~~~a\"" (feed-title feed)))
            (format strm " \"~a\"" (feed-folder feed)))))
