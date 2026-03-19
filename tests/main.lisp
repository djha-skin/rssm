;;;; tests/main.lisp
;;;;
;;;; Unit tests for RSSM packages.

(defpackage #:com.djhaskin.rssm/tests
  (:use #:cl #:parachute)
  (:local-nicknames (#:rssm #:com.djhaskin.rssm)
                    (#:backend #:com.djhaskin.rssm/backend)
                    (#:opml #:com.djhaskin.rssm/opml))
  (:import-from #:com.djhaskin.rssm/backend
                #:feed #:feed-title #:feed-xml-url #:feed-home-page-url #:feed-folder))

(in-package #:com.djhaskin.rssm/tests)
