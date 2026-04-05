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
;;;; after it indicates that the feed should be hidden everywhere. Finally, any
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
  (:import-from #:serapeum)
  (:local-nicknames (#:backend #:com.djhaskin.rssm/backend)
                    (#:util #:serapeum/bundle))
  (:export #:newsboat-feed
              #:newsboat-tag
              #:newsboat-tag-hidden
              #:newsboat-tag-title
              #:newsboat-tag-value
              #:newsboat-feed-url
              #:newsboat-feed-tags
              #:concrete-feed-p
              #:newsboat-to-generic))

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

#+(or)
(progn
  (with-output-to-string (s)
    (render-quoted s "This is a \"test\" string with \\ backslashes."))
  (with-output-to-string (s)
    (render-quoted s "SimpleString"))
  (with-output-to-string (s)
    (render-quoted s "String with a backslash at the end\\"))
  (with-output-to-string (s)
    (render-quoted s "String with a quote at the end\""))
  (with-output-to-string (s)
    (render-quoted s "")))

(defun render-quoted (strm str)
  "Quotes a string for use in the newsboat URL file."
  (write-char #\" strm)
  (loop for c across str
        do
        (cond ((char= c #\")
               (write-char #\\ strm)
               (write-char #\" strm))
              ((char= c #\\)
               (write-char #\\ strm)
               (write-char #\\ strm))
              (t
               (write-char c strm))))
  (write-char #\" strm))

(defclass newsboat-tag ()
  ((hidden
    :initarg :hidden
    :accessor newsboat-tag-hidden
    :initform nil
    :type boolean
    :documentation "Whether this tag is hidden.")
   (custom-name
    :initarg :title
    :accessor newsboat-tag-title
    :type boolean
    :initform nil
    :documentation "Whether or not the tag is a custom name.")
   (value
    :initarg :value
    :accessor newsboat-tag-value
    :initform (error "Need to provide a value for newsboat-tag")
    :type string
    :documentation "The value of the tag. May or may not be the empty string.")))

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
     :type list
     :documentation "The list of tags associated with this feed.")))


;;; Spot-check bookmark

(defun next-token (strm)
  "Reads the next token from the newsboat URL file line.
  Returns NIL at end-of-line or end-of-file."
  (let ((c (read-char strm nil :eof)))
    (cond ((or (eql c :eof)
               (char= c #\Newline))
           nil)
          ((char= c #\Space)
           (next-token strm))
          ((char= c #\")
           (unread-char c strm)
           (read-quoted strm))
          (t
           (loop with chars = (make-array 16
                                :fill-pointer 1
                                :adjustable t
                                :element-type 'character
                                :initial-element c)
                 for next = (read-char strm nil :eof)
                 while (and (not (eql next :eof))
                            (not (char= next #\Newline))
                            (not (char= next #\Space)))
                 do (vector-push-extend next chars)
                 finally
                 (when (and (not (eql next :eof))
                            (char= next #\Newline))
                   (unread-char next strm))
                 (return (coerce chars 'string)))))))

(defun token-to-tag (token)
  "Converts a newsboat URL file token into a newsboat-tag object.
  Prefix characters:
    ~  marks the tag as a custom feed title
    !  marks the tag as hidden
  Both prefixes may appear in either order before the value."
  (let ((hidden nil)
        (custom-name nil)
        (next-spot 0)
        (len (length token)))
    (when (and (< next-spot len)
               (or (char= (aref token next-spot) #\!)
                   (char= (aref token next-spot) #\~)))
      (if (char= (aref token next-spot) #\!)
          (setf hidden t)
          (setf custom-name t))
      (setf next-spot (1+ next-spot)))
    (when (and (< next-spot len)
               (or (char= (aref token next-spot) #\!)
                   (char= (aref token next-spot) #\~)))
      (if (char= (aref token next-spot) #\!)
          (setf hidden t)
          (setf custom-name t))
      (setf next-spot (1+ next-spot)))
    (make-instance 'newsboat-tag
                   :hidden hidden
                   :title custom-name
                   :value (subseq token next-spot))))

(defun concrete-feed-p (feed)
  "Returns true if the feed is a real feed, not a virtual query."
  (let ((url (newsboat-feed-url feed)))
    (not (util:string-prefix-p "query:" url))))

(defun newsboat-to-generic (feed)
  "
  Converts a newsboat-feed object into a generic feed object.
  "

  (make-instance 'backend:feed
                 :title (or (some
                              (lambda (tag)
                                (and (newsboat-tag-title tag)
                                     (newsboat-tag-value tag)))
                              (newsboat-feed-tags feed))
                            nil)
                 :xml-url (newsboat-feed-url feed)
                 :folder (or (some
                               (lambda (tag)
                                 (and
                                  (not (newsboat-tag-title tag))
                                  (not (eql
                                        (length (newsboat-tag-value tag))
                                        0))
                                  (newsboat-tag-value tag)))
                               (newsboat-feed-tags feed))
                            nil)))

(defun read-next-line (strm)
  "
  Reads the next line from the newsboat URL file, returning what it finds.
  "
  (util:if-let ((line-tokens
                 (loop for token = (next-token strm)
                         then (next-token strm)
                       while token
                       collect token)))
    (make-instance
      'newsboat-feed
       :url (car line-tokens)
       :tags (mapcar #'token-to-tag (cdr line-tokens)))))

(defmethod backend:parse-feeds ((fmt (eql :newsboat)) strm)
  (loop with feeds = (make-hash-table :test 'equal)
        for newsfeed = (read-next-line strm)
        while newsfeed
        if (concrete-feed-p newsfeed)
        do
        (let* ((backend-feed (newsboat-to-generic newsfeed))
               (folder (backend:feed-folder backend-feed)))
          (pushnew backend-feed (gethash folder feeds)))
        finally
        (return feeds)))

(defmethod backend:render-feeds ((fmt (eql :newsboat)) feeds strm)
  (loop for folder being the hash-keys of feeds
        using (hash-value folder-feeds)
        do
        (format strm "\"query:~a:unread = \\\"yes\\\" and tags # \\\"~a\\\"\"~%"
                folder folder)
        (loop for feed in folder-feeds
            do
            (render-quoted strm (backend:feed-xml-url feed))
            (format strm " ")
            (when (backend:feed-title feed)
              (format strm " \"~~~a\"" (backend:feed-title feed)))
            (format strm " \"~a\"~%" (backend:feed-folder feed)))))
