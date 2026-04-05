;;;; rssm/tests/opml.lisp
;;;;
;;;; Unit tests for the OPML format support.
;;;;
;;;; Tests cover parsing, rendering, and round-trip behaviour for
;;;; `parse-feeds :opml` and `render-feeds :opml`.

(defpackage #:com.djhaskin.rssm/tests/opml
  (:use #:cl)
  (:import-from
    #:org.shirakumo.parachute
    #:define-test
    #:true
    #:false
    #:fail
    #:is
    #:isnt
    #:of-type
    #:finish)
  (:import-from #:com.djhaskin.rssm/opml)
  (:import-from #:com.djhaskin.rssm/backend)
  (:local-nicknames
    (#:parachute #:org.shirakumo.parachute)
    (#:opml     #:com.djhaskin.rssm/opml)
    (#:backend  #:com.djhaskin.rssm/backend)
    (#:plump    #:org.shirakumo.plump)))

(in-package #:com.djhaskin.rssm/tests/opml)

;;; -------------------------------------------------------
;;; Helpers
;;; -------------------------------------------------------

(defun parse-opml-string (text)
  "Parse OPML text via `backend:parse-feeds-string`."
  (backend:parse-feeds-string :opml text))

(defun render-opml-string (feeds)
  "Render feeds via `backend:render-feeds-string`."
  (backend:render-feeds-string :opml feeds))

(defun make-feed (xml-url &key title folder)
  "Construct a backend:feed."
  (make-instance 'backend:feed
                 :xml-url xml-url
                 :title   title
                 :folder  folder))

(defun ht (&rest pairs)
  "Build a hash table from alternating key-value pairs."
  (loop with ht = (make-hash-table :test #'equal)
        for (k v) on pairs by #'cddr
        do (setf (gethash k ht) v)
        finally (return ht)))

;;; -------------------------------------------------------
;;; Top-level suite
;;; -------------------------------------------------------

(define-test opml-suite)

;;; -------------------------------------------------------
;;; parse-opml-element
;;; -------------------------------------------------------

(define-test poe-simple-feed
  :parent opml-suite
  "parse-opml-element extracts a single feed outline."
  (let* ((doc (plump:parse
               "<outline xmlUrl=\"http://x.com/rss\"
                       title=\"Feed\" text=\"Feed\"/>"))
         (outline (first (plump:children doc)))
         (feed (opml:parse-opml-element outline)))
    (true (typep feed 'backend:feed))
    (is equal "http://x.com/rss" (backend:feed-xml-url feed))
    (is equal "Feed" (backend:feed-title feed))
    (false (backend:feed-folder feed))))

(define-test poe-feed-with-folder
  :parent opml-suite
  "parse-opml-element passes through the folder name."
  (let* ((doc (plump:parse
               "<outline xmlUrl=\"http://x.com/rss\"
                       title=\"F\" text=\"F\"/>"))
         (outline (first (plump:children doc)))
         (feed (opml:parse-opml-element outline "tech")))
    (is equal "tech" (backend:feed-folder feed))))

(define-test poe-folder-with-feeds
  :parent opml-suite
  "parse-opml-element on a folder returns a list of child feeds."
  (let* ((xml
          "<outline text=\"News\" title=\"News\">
             <outline xmlUrl=\"http://a.com/rss\"
                      title=\"A\" text=\"A\"/>
             <outline xmlUrl=\"http://b.com/rss\"
                      title=\"B\" text=\"B\"/>
           </outline>")
         (doc (plump:parse xml))
         (outline (first (plump:children doc)))
         (feeds (opml:parse-opml-element outline)))
    (is = 2 (length feeds))
    (is equal "http://a.com/rss"
        (backend:feed-xml-url (first feeds)))
    (is equal "http://b.com/rss"
        (backend:feed-xml-url (second feeds)))
    (is equal "News" (backend:feed-folder (first feeds)))))

(define-test poe-unknown-title-falls-back-to-text
  :parent opml-suite
  "When no title attribute, parse-opml-element uses text."
  (let* ((doc (plump:parse
               "<outline xmlUrl=\"http://x.com/rss\"
                       text=\"My Feed\"/>"))
         (outline (first (plump:children doc)))
         (feed (opml:parse-opml-element outline)))
    (is equal "My Feed" (backend:feed-title feed))))

;;; -------------------------------------------------------
;;; outline-feed-p / outline-folder-p
;;; -------------------------------------------------------

(define-test outline-feed-p-with-xmlurl
  :parent opml-suite
  "An outline with xmlUrl is a feed."
  (let* ((doc (plump:parse
               "<outline xmlUrl=\"http://x.com/rss\" />"))
         (node (first (plump:children doc))))
    (true (opml::outline-feed-p node))))

(define-test outline-feed-p-without-xmlurl
  :parent opml-suite
  "An outline without xmlUrl is not a feed."
  (let* ((doc (plump:parse
               "<outline text=\"Folder\" />"))
         (node (first (plump:children doc))))
    (false (opml::outline-feed-p node))))

(define-test outline-folder-p-with-children
  :parent opml-suite
  "An outline with children and no xmlUrl is a folder."
  (let* ((doc (plump:parse
               "<outline text=\"F\">
                  <outline xmlUrl=\"http://x.com/rss\" />
                </outline>"))
         (node (first (plump:children doc))))
    (true (opml::outline-folder-p node))))

(define-test outline-folder-p-self-closing
  :parent opml-suite
  "A self-closing outline is not a folder."
  (let* ((doc (plump:parse
               "<outline xmlUrl=\"http://x.com/rss\" />"))
         (node (first (plump:children doc))))
    (false (opml::outline-folder-p node))))

;;; -------------------------------------------------------
;;; backend:parse-feeds :opml
;;; -------------------------------------------------------

(define-test parse-feeds-single-feed-no-folder
  :parent opml-suite
  "A single top-level feed lands under the NIL folder key."
  (let* ((xml
          "<?xml version=\"1.0\"?>
<opml version=\"2.0\"><body>
<outline xmlUrl=\"http://x.com/rss\"
         title=\"X\" text=\"X\"/>
</body></opml>")
         (feeds (parse-opml-string xml)))
    (is = 1 (length (gethash nil feeds)))
    (is equal "http://x.com/rss"
        (backend:feed-xml-url (first (gethash nil feeds))))
    (is equal "X"
        (backend:feed-title (first (gethash nil feeds))))))

(define-test parse-feeds-folder-with-feeds
  :parent opml-suite
  "Feeds inside a folder outline land under that folder key."
  (let* ((xml
          "<?xml version=\"1.0\"?>
<opml version=\"2.0\"><body>
<outline text=\"Tech\" title=\"Tech\">
  <outline xmlUrl=\"http://a.com\" title=\"A\" text=\"A\"/>
  <outline xmlUrl=\"http://b.com\" title=\"B\" text=\"B\"/>
</outline>
</body></opml>")
         (feeds (parse-opml-string xml)))
    (is = 2 (length (gethash "Tech" feeds)))))

(define-test parse-feeds-mixed-top-and-folder
  :parent opml-suite
  "Top-level feeds go to NIL folder; nested go to named folder."
  (let* ((xml
          "<?xml version=\"1.0\"?>
<opml version=\"2.0\"><body>
<outline xmlUrl=\"http://top.com\" title=\"Top\" text=\"Top\"/>
<outline text=\"News\" title=\"News\">
  <outline xmlUrl=\"http://n.com\" title=\"N\" text=\"N\"/>
</outline>
</body></opml>")
         (feeds (parse-opml-string xml)))
    (is = 1 (length (gethash nil feeds)))
    (is = 1 (length (gethash "News" feeds)))))

(define-test parse-feeds-returns-backend-feed
  :parent opml-suite
  "Values in the hash are lists of backend:feed instances."
  (let* ((xml
          "<?xml version=\"1.0\"?>
<opml version=\"2.0\"><body>
<outline xmlUrl=\"http://x.com\" title=\"X\" text=\"X\"/>
</body></opml>")
         (feeds (parse-opml-string xml))
         (feed
          (first (gethash nil feeds))))
    (of-type backend:feed feed)))

(define-test parse-feeds-empty-body
  :parent opml-suite
  "An OPML with an empty body returns an empty hash table."
  (let* ((xml
          "<?xml version=\"1.0\"?>
<opml version=\"2.0\"><body></body></opml>")
         (feeds (parse-opml-string xml)))
    (is = 0 (hash-table-count feeds))))

;;; -------------------------------------------------------
;;; backend:render-feeds :opml
;;; -------------------------------------------------------

(define-test render-feeds-produces-opml-header
  :parent opml-suite
  "render-feeds starts with the XML declaration and opml tag."
  (let* ((f (make-feed "http://x.com" :folder "tech"))
         (tbl (ht "tech" (list f)))
         (out (render-opml-string tbl)))
    (true (search "<?xml" out))
    (true (search "<opml" out))
    (true (search "<body>" out))
    (true (search "</opml>" out))))

(define-test render-feeds-folder-outline
  :parent opml-suite
  "Feeds with a folder produce a folder <outline> wrapper."
  (let* ((f (make-feed "http://x.com" :folder "tech"))
         (tbl (ht "tech" (list f)))
         (out (render-opml-string tbl)))
    (true (search "text=\"tech\"" out))
    (true (search "<outline" out))))

(define-test render-feeds-nil-folder-feeds-at-top
  :parent opml-suite
  "Feeds with NIL folder are rendered without a folder wrapper."
  (let* ((f (make-feed "http://x.com"))
         (tbl (ht nil (list f)))
         (out (render-opml-string tbl)))
    (true (search "http://x.com" out))
    ;; No folder wrapper around it
    (false (search "text=\"NIL\"" out))))

(define-test render-feeds-feed-xmlurl-present
  :parent opml-suite
  "The feed xmlUrl is included in the rendered output."
  (let* ((f (make-feed "http://example.com/feed.xml"
                       :title "Example"))
         (tbl (ht "news" (list f)))
         (out (render-opml-string tbl)))
    (true (search "http://example.com/feed.xml" out))))

(define-test render-feeds-multiple-folders
  :parent opml-suite
  "Multiple folder groups each produce their own <outline>."
  (let* ((f1 (make-feed "http://a.com" :folder "Tech"))
         (f2 (make-feed "http://b.com" :folder "News"))
         (tbl (ht "Tech" (list f1) "News" (list f2)))
         (out (render-opml-string tbl)))
    (is = 2
        (count "text=\"Tech\"" out
               :test #'string=
               :start 0))
    (is = 2
        (count "text=\"News\"" out
               :test #'string=
               :start 0))))

;;; -------------------------------------------------------
;;; render-opml-feed (internal)
;;; -------------------------------------------------------

(define-test rof-basic-feed
  :parent opml-suite
  "render-opml-feed outputs an outline with rss type."
  (let* ((f (make-feed "http://x.com" :title "My Feed"))
         (out (with-output-to-string (s)
                (opml::render-opml-feed f s))))
    (true (search "type=\"rss\"" out))
    (true (search "My Feed" out))
    (true (search "http://x.com" out))))

(define-test rof-unknown-title
  :parent opml-suite
  "render-opml-feed uses \"Unknown\" when title is NIL."
  (let* ((f (make-feed "http://x.com"))
         (out (with-output-to-string (s)
                (opml::render-opml-feed f s))))
    (true (search "Unknown" out))))

;;; -------------------------------------------------------
;;; render-opml-folder (internal)
;;; -------------------------------------------------------

(define-test rof-folder-wrapper
  :parent opml-suite
  "render-opml-folder wraps feeds inside an outline."
  (let* ((f (make-feed "http://x.com"))
         (out (with-output-to-string (s)
                (opml::render-opml-folder
                 "Tech" (list f) s))))
    (true (search "<outline text=\"Tech\"" out))
    (true (search "http://x.com" out))
    (true (search "</outline>" out))))

;;; -------------------------------------------------------
;;; make-opml-document
;;; -------------------------------------------------------

(define-test mod-proper-xml
  :parent opml-suite
  "make-opml-document returns well-formed XML with head and body."
  (let* ((f (make-feed "http://x.com" :folder "F"))
         (tbl (ht "F" (list f)))
         (xml (opml:make-opml-document tbl)))
    (true (search "<?xml" xml))
    (true (search "<head>" xml))
    (true (search "<body>" xml))
    (true (search "</opml>" xml))))

;;; -------------------------------------------------------
;;; Round-trip: parse -> render -> parse
;;; -------------------------------------------------------

(define-test roundtrip-folder-preservation
  :parent opml-suite
  "Render then re-parse preserves folder -> feed mapping."
  (let* ((xml
          "<?xml version=\"1.0\"?>
<opml version=\"2.0\"><body>
<outline text=\"Tech\" title=\"Tech\">
  <outline xmlUrl=\"http://a.com\" title=\"A\" text=\"A\"/>
</outline>
</body></opml>")
         (feeds1 (parse-opml-string xml))
         (rendered (render-opml-string feeds1)))
    ;; Verify the rendered string still contains the folder data
    (true (search "Tech" rendered))
    (true (search "http://a.com" rendered))))

(define-test roundtrip-feed-count
  :parent opml-suite
  "Round-trip preserves the total number of feeds."
  (let* ((xml
          "<?xml version=\"1.0\"?>
<opml version=\"2.0\"><body>
<outline text=\"T\" title=\"T\">
  <outline xmlUrl=\"http://a.com\" title=\"A\" text=\"A\"/>
  <outline xmlUrl=\"http://b.com\" title=\"B\" text=\"B\"/>
</outline>
<outline xmlUrl=\"http://c.com\" title=\"C\" text=\"C\"/>
</body></opml>")
         (feeds1 (parse-opml-string xml))
         (total1 (loop for v being the hash-values of feeds1
                       sum (length v)))
         (rendered (render-opml-string feeds1))
         (feeds2 (parse-opml-string rendered))
         (total2 (loop for v being the hash-values of feeds2
                       sum (length v))))
    (is = total1 total2)))
