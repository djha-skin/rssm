;;;; rssm/src/opml.lisp
;;;;
;;;; OPML package for parsing and rendering OPML feed files using plump.

(defpackage #:com.djhaskin.rssm/opml
  (:use #:cl)
  (:import-from #:com.djhaskin.cliff)
  (:import-from #:com.djhaskin.rssm/backend)
  (:use #:com.djhaskin.rssm/backend)
  (:local-nicknames (#:alex #:alexandria)
                    (#:plump #:org.shirakumo.plump))
  (:export #:parse-opml-element
           #:render-opml-element
           #:parse-feeds
           #:render-feeds))

(in-package #:com.djhaskin.rssm/opml)

