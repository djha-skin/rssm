;;;; rssm/src/newsboat.lisp
;;;;
;;;; Newsboat format support for RSSM.

(defpackage #:com.djhaskin.rssm/newsboat
  (:use #:cl)
  (:import-from #:com.djhaskin.cliff)
  (:import-from #:com.djhaskin.rssm/backend)
  (:use #:com.djhaskin.rssm/backend)
  (:local-nicknames (#:alex #:alexandria))
  (:export #:parse-newsboat-line
           #:parse-newsboat-string
           #:render-newsboat-line
           #:render-newsboat-string
           #:newsboat-tokenize-with-quotes
           #:parse-quoted-token
           #:parse-unquoted-token
           #:parse-feeds
           #:render-feeds))

(in-package #:com.djhaskin.rssm/newsboat)

