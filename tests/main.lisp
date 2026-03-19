;;;; tests/main.lisp
;;;;
;;;; Unit tests for RSSM packages.


(defpackage #:com.djhaskin.rssm/tests
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
    #:com.djhaskin.rssm)
  (:local-nicknames
    (#:parachute #:org.shirakumo.parachute)
    (#:rssm #:com.djhaskin.rssm)))


(in-package #:com.djhaskin.rssm/tests)
