(defpackage #:com.djhaskin.rssm/tests
  (:use #:cl #:parachute)
  (:local-nicknames (#:rssm #:com.djhaskin.rssm)))

(in-package #:com.djhaskin.rssm/tests)

(define-test rssm-tests
  :parent parachute:test-suite)

(define-test basic-sanity-test
  :parent rssm-tests
  (true t "Basic sanity test"))
