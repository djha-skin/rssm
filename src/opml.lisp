;;;; rssm/src/opml.lisp
;;;;
;;;; OPML format support for RSSM.
;;;;
;;;; The purpose of this file is to implement `backend:parse-feeds` and
;;;; `backend:render-feeds` for the OPML XML format using Plump.
;;;;
;;;; An OPML 2.0 feed list has a <body> containing <outline> elements.
;;;; Outlines with an `xmlUrl` attribute are feeds. Outlines without
;;;; `xmlUrl` that contain children act as folders.
;;;;
;;;; A single-level folder structure is maintained: top-level outlines
;;;; with `xmlUrl` have no folder (NIL), while nested feeds inherit
;;;; the folder name from their parent outline's `text` or `title`.

#+(or)
(progn
  (asdf:load-system "com.djhaskin.rssm"))

(defpackage #:com.djhaskin.rssm/opml
  (:use #:cl)
  (:import-from #:com.djhaskin.rssm/backend)
  (:local-nicknames (#:backend #:com.djhaskin.rssm/backend)
                    (#:plump #:org.shirakumo.plump))
  (:export #:parse-opml-element
           #:render-opml-element
           #:parse-feeds
           #:render-feeds
           #:make-opml-document))

(in-package #:com.djhaskin.rssm/opml)

;;; Helpers

(defun outline-feed-p (node)
  "Return true if a node is a feed outline (has xmlUrl)."
  (and (string-equal (plump:tag-name node) "outline")
       (plump:attribute node "xmlUrl")))

(defun outline-folder-p (node)
  "Return true if a node is a folder outline (no xmlUrl, has children
   outlines)."
  (and (string-equal (plump:tag-name node) "outline")
       (not (plump:attribute node "xmlUrl"))
       (plusp (length (plump:children node)))))


;;; Parsing

(defun parse-opml-element (node &optional folder-name)
  "Parse a single <outline> element into a backend:feed or NIL.
   If the node is a feed, return a feed object. If it is a folder,
   recurse into its children with the folder name set."
  (cond ((outline-feed-p node)
         (make-instance 'backend:feed
                        :xml-url (plump:attribute node "xmlUrl")
                        :title   (or (plump:attribute node "title")
                                     (plump:attribute node "text"))
                        :folder  folder-name))
        ((outline-folder-p node)
         (let ((fname (or (plump:attribute node "text")
                          (plump:attribute node "title"))))
           (loop for child across (plump:children node)
                 when (outline-feed-p child)
                   collect (parse-opml-element child fname))))
        (t nil)))


;;; Rendering

(defun render-opml-feed (feed strm)
  "Render a single backend:feed as an OPML <outline> element."
  (let ((title (or (backend:feed-title feed) "Unknown")))
    (format strm
            "          <outline type=\"rss\" ~
text=\"~A\" title=\"~A\" ~
xmlUrl=\"~A\" htmlUrl=\"\"/>~%"
            title title (backend:feed-xml-url feed))))

(defun render-opml-folder (folder-name feeds strm)
  "Render a folder group: an <outline> wrapping feed children."
  (format strm "        <outline text=\"~A\" title=\"~A\">~%"
          folder-name folder-name)
  (loop for feed in feeds
        do (render-opml-feed feed strm))
  (format strm "        </outline>~%"))


(defun make-opml-document (feeds)
  "Build a full OPML XML string from a hash table of feeds."
  (with-output-to-string (strm)
    (format strm "<?xml version=\"1.0\" encoding=\"UTF-8\"?>~%")
    (format strm "<opml version=\"2.0\">~%")
    (format strm "  <head>~%")
    (format strm "    <title>Exported from RSSM</title>~%")
    (format strm "  </head>~%")
    (format strm "  <body>~%")
    (loop for folder being the hash-keys of feeds
          using (hash-value folder-feeds)
          if folder
            do (render-opml-folder folder folder-feeds strm)
          else
            do (loop for feed in folder-feeds
                     do (render-opml-feed feed strm)))
    (format strm "  </body>~%")
    (format strm "</opml>~%")))


;;; Backend methods

(defun find-body (document)
  "Find the <body> element by walking the document tree."
  (loop for child across (plump:children document)
        thereis (and (string-equal (plump:tag-name child) "body")
                     child)
        thereis (when (plump:element-p child)
                  (find-body child))))

(defmethod backend:parse-feeds ((fmt (eql :opml)) strm)
  (let* ((document (plump:parse strm))
         (body (find-body document))
         (feeds (make-hash-table :test #'equal)))
    (when body
      (loop for child across (plump:children body)
            when (string-equal (plump:tag-name child) "outline")
              do (let ((result (parse-opml-element child)))
                   (cond ((typep result 'backend:feed)
                          (let ((folder
                                 (backend:feed-folder result)))
                            (push result
                                  (gethash folder feeds))))
                         ((listp result)
                          (loop for feed in result
                                do (let ((folder
                                           (backend:feed-folder feed)))
                                     (push feed
                                           (gethash folder
                                                    feeds)))))))))
    feeds))


(defmethod backend:render-feeds ((fmt (eql :opml)) feeds strm)
  (write-string (make-opml-document feeds) strm))
