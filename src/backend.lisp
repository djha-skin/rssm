;;;; rssm/backend.lisp
;;;;
;;;; Backend package containing the feed CLOS class and generic functions
;;;; for parsing and rendering different feed file froms.

(defpackage #:com.djhaskin.rssm/backend
  (:use #:cl)
  (:local-nicknames (#:alex #:alexandria))
  (:export #:feed
           #:feed-title
           #:feed-xml-url
           #:feed-home-page-url
           #:feed-folder
           #:parse-feeds
           #:render-feeds
           #:parse-feed-file
           #:render-feed-file))

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
   (home-page-url
    :initarg :home-page-url
    :accessor feed-home-page-url
    :initform nil
    :documentation "The URL of the blog associated with the feed.")
   (folder
    :initarg :folder
    :accessor feed-folder
    :initform nil
    :documentation "The one-level-deep folder where the feed resides.")))

;;; Generic Functions for Parsing

(defgeneric parse-feeds (from text &optional feed-class)
  (:documentation "Parse feeds from a string in the given from."))

(defgeneric parse-feed-file (from path &optional feed-class)
  (:documentation "Parse feeds from a file in the given from."))

;;; Generic Functions for Rendering

(defgeneric render-feeds (to feeds
                               &key xml-url-accessor
                                     title-accessor
                                     folder-accessor)
  (:documentation "Render feeds to a string in the given from."))

(defgeneric render-feed-file (to feeds path
                                   &key xml-url-accessor
                                         title-accessor
                                         folder-accessor)
  (:documentation "Render feeds to a file in the given from."))
