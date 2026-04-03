;;;; rssm/backend.lisp
;;;;
;;;; Backend package: feed CLOS class and generic functions
;;;; for parsing and rendering different feed file formats.

(defpackage #:com.djhaskin.rssm/backend
  (:use #:cl)
  (:export
    #:feed
    #:feed-title
    #:feed-xml-url
    #:feed-home-page-url
    #:feed-folder
    #:parse-feeds
    #:parse-feeds-file
    #:parse-feeds-string
    #:render-feeds
    #:render-feeds-file
    #:render-feeds-string))

(in-package #:com.djhaskin.rssm/backend)

;;; Data Model

(defclass feed ()
  ((title
    :initarg :title
    :accessor feed-title
    :initform nil
    :documentation "The title of the RSS feed.")
   (xml-url
    :initarg :xml-url
    :accessor feed-xml-url
    :initform (error "Must provide xml-url")
    :documentation "The URL of the RSS/Atom feed.")
   (folder
    :initarg :folder
    :accessor feed-folder
    :initform nil
    :documentation
    "The one-level-deep folder where the feed resides.")))

;;; Generic Functions for Parsing

(defgeneric parse-feeds (fmt strm)
  (:documentation "
    Parse feeds from a stream STRM in the given format FMT,
    a keyword symbol. Returns a hash table whose keys are folder
    name strings and whose values are lists of FEED objects.
    "))

(defun parse-feeds-file (fmt path)
  "Parse feeds from PATH in the given format FMT."
  (with-open-file (strm path
                        :direction :input
                        :external-format :utf-8
                        :if-does-not-exist :error)
    (parse-feeds fmt strm)))

(defun parse-feeds-string (fmt text)
  "Parse feeds from TEXT in the given format FMT."
  (with-input-from-string (strm text)
    (parse-feeds fmt strm)))

;;; Generic Functions for Rendering

(defgeneric render-feeds (fmt feeds strm)
  (:documentation "
    Render FEEDS to stream STRM in format FMT.
    FEEDS is a hash table of folder-name -> list-of-feed.
    FMT is a keyword symbol.  Returns nothing.
    "))

(defun render-feeds-file (fmt feeds path)
  "Render FEEDS to a file at PATH in format FMT."
  (with-open-file (strm path
                        :direction :output
                        :external-format :utf-8
                        :if-exists :supersede)
    (render-feeds fmt feeds strm)))

(defun render-feeds-string (fmt feeds)
  "Render FEEDS to a string in format FMT."
  (with-output-to-string (strm)
    (render-feeds fmt feeds strm)))
