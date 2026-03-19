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

(define-test feed-creation
  "Test that a feed can be created with required xml-url."
  (let ((f (make-instance 'backend:feed :title "Test Feed" :xml-url "http://example.com/feed.xml")))
    (is equal "Test Feed" (backend:feed-title f))
    (is equal "http://example.com/feed.xml" (backend:feed-xml-url f))))

(define-test feed-error-without-xml-url
  "Test that creating a feed without xml-url signals an error."
  (fail (make-instance 'backend:feed :title "Test Feed")))
