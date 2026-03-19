;;;; tests/backend.lisp
;;;;
;;;; Unit tests for the backend package.

(defpackage #:com.djhaskin.rssm/tests/backend
  (:use #:cl #:parachute)
  (:local-nicknames (#:backend #:com.djhaskin.rssm/backend))
  (:import-from #:com.djhaskin.rssm/backend
                #:feed #:feed-title #:feed-xml-url #:feed-home-page-url #:feed-folder))

(in-package #:com.djhaskin.rssm/tests/backend)

(deftest feed-creation
  "Test that a feed can be created with required xml-url."
  (let ((f (make-instance 'feed :title "Test Feed" :xml-url "http://example.com/feed.xml")))
    (is.equal "Test Feed" (feed-title f))
    (is.equal "http://example.com/feed.xml" (feed-xml-url f))))

(deftest feed-error-without-xml-url
  "Test that creating a feed without xml-url signals an error."
  (is.error 'error (make-instance 'feed :title "Test Feed")))
