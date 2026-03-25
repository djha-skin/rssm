;;;; tests/backend.lisp
;;;;
;;;; Unit tests for the backend package.
(defpackage #:com.djhaskin.rssm/tests/backend
  (:use #:cl)
  (:import-from
    #:org.shirakumo.parachute
    #:define-test
    #:true
    #:false
    #:fail
    #:is
    #:isnt
    #:is-values
    #:isnt-values
    #:of-type
    #:finish
    #:test)
  (:import-from
    #:com.djhaskin.rssm/backend)
  (:local-nicknames
    (#:parachute #:org.shirakumo.parachute)
    (#:backend #:com.djhaskin.rssm/backend)))


(in-package #:com.djhaskin.rssm/tests/backend)

(define-test backend-suite)

(define-test feed-creation
  :parent backend-suite
  (let ((f (make-instance 'backend:feed :title "Test Feed" :xml-url
                          "http://example.com/feed.xml")))
    (is equal "Test Feed" (backend:feed-title f))
    (is equal "http://example.com/feed.xml" (backend:feed-xml-url f))))

(defmethod backend:parse-feeds ((fmt (eql :test)) strm)
    "Test implementation of parse-feeds that always returns the same feed."
    (declare (ignore fmt))
    (let ((feed (make-instance 'backend:feed :title "Test Feed" :xml-url
                                 "http://example.com/feed.xml")))
        (list (cons "Test Folder" (list feed)))))


(deftest 

(define-test feed-error-without-xml-url
  "Test that creating a feed without xml-url signals an error."
  (fail (make-instance 'backend:feed :title "Test Feed")))
