;;;; rssm/rsssavvy.lisp
;;;;
;;;; RSSSavvy JSON format support for RSSM.

(defpackage #:com.djhaskin.rssm/rsssavvy
  (:use #:cl)
  (:import-from #:com.djhaskin.cliff)
  (:import-from #:com.djhaskin.rssm/backend)
  (:use #:com.djhaskin.rssm/backend)
  (:local-nicknames (#:alex #:alexandria))
  (:export #:parse-rsssavvy-line
           #:parse-rsssavvy-string
           #:render-rsssavvy-line
           #:render-rsssavvy-string
           ;; Method definitions for generic functions
           #:parse-feeds
           #:render-feeds))

(in-package #:com.djhaskin.rssm/rsssavvy)

