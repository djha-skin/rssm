;;;; rssm/backend.lisp
;;;;
;;;; Backend package containing the feed CLOS class and generic functions
;;;; for parsing and rendering different feed file formats.

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

(defgeneric parse-feeds (format text &optional (feed-class feed))
  (:documentation "Parse feeds from a string in the given format.")
  (:argument-list (format text &optional (feed-class 'feed))))

(defgeneric parse-feed-file (format path &optional (feed-class feed))
  (:documentation "Parse feeds from a file in the given format.")
  (:argument-list (format path &optional (feed-class 'feed))))

;;; Generic Functions for Rendering

(defgeneric render-feeds (format feeds
                               &key (xml-url-accessor #'feed-xml-url)
                                 (title-accessor #'feed-title)
                                 (folder-accessor #'feed-folder))
  (:documentation "Render feeds to a string in the given format.")
  (:argument-list (format feeds
                          &key (xml-url-accessor #'feed-xml-url)
                            (title-accessor #'feed-title)
                            (folder-accessor #'feed-folder))))

(defgeneric render-feed-file (format feeds path
                                   &key (xml-url-accessor #'feed-xml-url)
                                     (title-accessor #'feed-title)
                                     (folder-accessor #'feed-folder))
  (:documentation "Render feeds to a file in the given format.")
  (:argument-list (format feeds path
                          &key (xml-url-accessor #'feed-xml-url)
                            (title-accessor #'feed-title)
                            (folder-accessor #'feed-folder))))

;;; Default methods that signal errors for unimplemented formats

(defmethod parse-feeds ((format keyword) text &optional (feed-class 'feed))
  (error "No parse-feeds method for format ~A" format))

(defmethod parse-feed-file ((format keyword) path &optional (feed-class 'feed))
  (error "No parse-feed-file method for format ~A" format))

(defmethod render-feeds ((format keyword) feeds
                         &key (xml-url-accessor #'feed-xml-url)
                           (title-accessor #'feed-title)
                           (folder-accessor #'feed-folder))
  (error "No render-feeds method for format ~A" format))

(defmethod render-feed-file ((format keyword) feeds path
                             &key (xml-url-accessor #'feed-xml-url)
                               (title-accessor #'feed-title)
                               (folder-accessor #'feed-folder))
  (error "No render-feed-file method for format ~A" format))
