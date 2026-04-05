;;;; rssm/tests/rsssavvy.lisp
;;;;
;;;; Unit tests for the RSSSavvy JSON format support.
;;;;
;;;; Tests cover parsing, rendering, and round-trip behaviour for
;;;; `parse-feeds :rsssavvy` and `render-feeds :rsssavvy`.

(defpackage #:com.djhaskin.rssm/tests/rsssavvy
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
  (:import-from #:com.djhaskin.rssm/rsssavvy)
  (:import-from #:com.djhaskin.rssm/backend)
  (:local-nicknames
    (#:parachute #:org.shirakumo.parachute)
    (#:rsssavvy #:com.djhaskin.rssm/rsssavvy)
    (#:backend  #:com.djhaskin.rssm/backend)))

(in-package #:com.djhaskin.rssm/tests/rsssavvy)

;;; -------------------------------------------------------
;;; Helpers
;;; -------------------------------------------------------

(defun parse-json-string (text)
  "Parse RSSSavvy JSON text via `backend:parse-feeds-string`."
  (backend:parse-feeds-string :rsssavvy text))

(defun render-json-string (feeds)
  "Render feeds via `backend:render-feeds-string`."
  (backend:render-feeds-string :rsssavvy feeds))

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

(defun make-group-ht (title filters)
  "Create a group hash-table as NRDL would return it."
  (ht "title" title
      "icon" ""
      "id" (random #x7FFFFFFF)
      "filters" (coerce filters 'vector)))

;;; -------------------------------------------------------
;;; Top-level suite
;;; -------------------------------------------------------

(define-test rsssavvy-suite)

;;; -------------------------------------------------------
;;; filter-to-url
;;; -------------------------------------------------------

(define-test filter-to-url-basic
  :parent rsssavvy-suite
  "filter-to-url extracts URL from 'RS <url>' filter string."
  (is equal "http://example.com/feed"
      (rsssavvy:filter-to-url "RS http://example.com/feed")))

(define-test filter-to-url-no-rs-prefix
  :parent rsssavvy-suite
  "filter-to-url returns NIL for strings without RS prefix."
  (false (rsssavvy:filter-to-url "http://example.com/feed"))
  (false (rsssavvy:filter-to-url "something else")))

(define-test filter-to-url-empty-after-prefix
  :parent rsssavvy-suite
  "filter-to-url returns NIL for 'RS' with no URL."
  (false (rsssavvy:filter-to-url "RS "))
  (false (rsssavvy:filter-to-url "RS")))

(define-test filter-to-url-non-string
  :parent rsssavvy-suite
  "filter-to-url returns NIL for non-string input."
  (false (rsssavvy:filter-to-url nil))
  (false (rsssavvy:filter-to-url 123)))

;;; -------------------------------------------------------
;;; rsssavvy-group-to-folder
;;; -------------------------------------------------------

(define-test group-to-folder
  :parent rsssavvy-suite
  "rsssavvy-group-to-folder extracts title from group object."
  (let ((group (ht "title" "DevOps"
                   "filters" (vector "RS http://x.com"))))
    (is equal "DevOps" (rsssavvy:rsssavvy-group-to-folder group))))

(define-test group-to-folder-missing-title
  :parent rsssavvy-suite
  "rsssavvy-group-to-folder returns NIL when title is missing."
  (let ((group (ht "filters" (vector))))
    (false (rsssavvy:rsssavvy-group-to-folder group))))

;;; -------------------------------------------------------
;;; rsssavvy-group-filters
;;; -------------------------------------------------------

(define-test group-filters
  :parent rsssavvy-suite
  "rsssavvy-group-filters extracts filters list from group."
  (let ((group (ht "title" "Tech"
                   "filters" '("RS http://a.com"
                                      "RS http://b.com"))))
    (is = 2 (length (rsssavvy:rsssavvy-group-filters group)))))

;;; -------------------------------------------------------
;;; rsssavvy-folder-of-url
;;; -------------------------------------------------------

(define-test folder-of-url-found
  :parent rsssavvy-suite
  "rsssavvy-folder-of-url finds folder for matching URL."
  (let ((groups (list
                  (ht "title" "DevOps"
                      "filters" '("RS http://x.com"
                                         "RS http://y.com")))))
    (is equal "DevOps"
        (rsssavvy:rsssavvy-folder-of-url "http://x.com" groups))))

(define-test folder-of-url-not-found
  :parent rsssavvy-suite
  "rsssavvy-folder-of-url returns NIL when URL not in any group."
  (let ((groups (list
                  (ht "title" "DevOps"
                      "filters" '("RS http://x.com")))))
    (false (rsssavvy:rsssavvy-folder-of-url "http://other.com" groups))))

(define-test folder-of-url-empty-groups
  :parent rsssavvy-suite
  "rsssavvy-folder-of-url returns NIL for empty groups list."
  (false (rsssavvy:rsssavvy-folder-of-url "http://x.com" nil)))

;;; -------------------------------------------------------
;;; backend:parse-feeds :rsssavvy
;;; -------------------------------------------------------

(define-test parse-feeds-empty-json
  :parent rsssavvy-suite
  "parse-feeds handles empty rssfeeds array."
  (let* ((json "{\"rssfeeds\": [], \"groups\": []}")
         (feeds (parse-json-string json)))
    (is = 0 (hash-table-count feeds))))

(define-test parse-feeds-single-feed-no-group
  :parent rsssavvy-suite
  "A feed with no matching group goes to NIL folder."
  (let* ((json "{\"rssfeeds\": [{\"title\": \"My Feed\",
                                     \"url\": \"http://x.com/feed\",
                                     \"icon\": \"\"}],
                   \"groups\": []}")
         (feeds (parse-json-string json)))
    (is = 1 (length (gethash nil feeds)))
    (is equal "http://x.com/feed"
        (backend:feed-xml-url (first (gethash nil feeds))))))

(define-test parse-feeds-single-feed-with-group
  :parent rsssavvy-suite
  "A feed matching a group filter goes to that folder."
  (let* ((json "{\"rssfeeds\": [{\"title\": \"Dev Blog\",
                                     \"url\": \"http://dev.com/rss\",
                                     \"icon\": \"\"}],
                   \"groups\": [{\"title\": \"Dev\",
                                \"filters\": [\"RS http://dev.com/rss\"]}]}")
         (feeds (parse-json-string json)))
    (is = 1 (length (gethash "Dev" feeds)))
    (is equal "Dev" (backend:feed-folder (first (gethash "Dev" feeds))))))

(define-test parse-feeds-title-extraction
  :parent rsssavvy-suite
  "parse-feeds extracts the title from each feed."
  (let* ((json "{\"rssfeeds\": [{\"title\": \"My Cool Feed\",
                                     \"url\": \"http://x.com/rss\",
                                     \"icon\": \"\"}],
                   \"groups\": []}")
         (feeds (parse-json-string json))
         (feed (first (gethash nil feeds))))
    (is equal "My Cool Feed" (backend:feed-title feed))))

(define-test parse-feeds-multiple-feeds-multiple-folders
  :parent rsssavvy-suite
  "parse-feeds correctly assigns feeds to multiple folders."
  (let* ((json "{
  \"rssfeeds\": [
    {\"title\": \"Feed A\", \"url\": \"http://a.com/rss\", \"icon\": \"\"},
    {\"title\": \"Feed B\", \"url\": \"http://b.com/rss\", \"icon\": \"\"},
    {\"title\": \"Feed C\", \"url\": \"http://c.com/rss\", \"icon\": \"\"}
  ],
  \"groups\": [
    {\"title\": \"Tech\",
     \"filters\": [\"RS http://a.com/rss\", \"RS http://b.com/rss\"]},
    {\"title\": \"News\",
     \"filters\": [\"RS http://c.com/rss\"]}
  ]
}")
         (feeds (parse-json-string json)))
    (is = 2 (length (gethash "Tech" feeds)))
    (is = 1 (length (gethash "News" feeds)))))

(define-test parse-feeds-feed-with-no-matching-group
  :parent rsssavvy-suite
  "Feeds not in any group filter land in the NIL folder."
  (let* ((json "{
  \"rssfeeds\": [
    {\"title\": \"Ungrouped\", \"url\": \"http://orphan.com/rss\",
     \"icon\": \"\"}
  ],
  \"groups\": [
    {\"title\": \"Tech\", \"filters\": [\"RS http://other.com/rss\"]}
  ]
}")
         (feeds (parse-json-string json)))
    (is = 1 (length (gethash nil feeds)))))

(define-test parse-feeds-returns-backend-feed
  :parent rsssavvy-suite
  "Parsed values are backend:feed instances."
  (let* ((json "{\"rssfeeds\": [{\"title\": \"X\",
                                     \"url\": \"http://x.com\",
                                     \"icon\": \"\"}],
                   \"groups\": []}")
         (feeds (parse-json-string json))
         (feed (first (gethash nil feeds))))
    (of-type backend:feed feed)))

;;; -------------------------------------------------------
;;; backend:render-feeds :rsssavvy
;;; -------------------------------------------------------

(define-test render-feeds-produces-valid-json
  :parent rsssavvy-suite
  "render-feeds produces valid JSON with expected keys."
  (let* ((f (make-feed "http://x.com" :folder "tech"))
         (tbl (ht "tech" (list f)))
         (out (render-json-string tbl)))
    (true (search "\"rssfeeds\"" out))
    (true (search "\"groups\"" out))
    (true (search "\"userid\"" out))))

(define-test render-feeds-includes-url
  :parent rsssavvy-suite
  "The feed URL appears in rendered JSON."
  (let* ((f (make-feed "http://example.com/feed.xml"
                       :title "Example Feed"))
         (tbl (ht nil (list f)))
         (out (render-json-string tbl)))
    (true (search "http://example.com/feed.xml" out))))

(define-test render-feeds-includes-title
  :parent rsssavvy-suite
  "The feed title appears in rendered JSON."
  (let* ((f (make-feed "http://x.com" :title "My Title"))
         (tbl (ht nil (list f)))
         (out (render-json-string tbl)))
    (true (search "My Title" out))))

(define-test render-feeds-group-filters
  :parent rsssavvy-suite
  "Feeds with folders produce groups with RS filters."
  (let* ((f (make-feed "http://x.com" :folder "News"))
         (tbl (ht "News" (list f)))
         (out (render-json-string tbl)))
    (true (search "News" out))
    (true (search "RS http://x.com" out))))

(define-test render-feeds-nil-folder-excluded
  :parent rsssavvy-suite
  "NIL folder feeds don't produce a group entry."
  (let* ((f (make-feed "http://x.com" :title "Ungrouped"))
         (tbl (ht nil (list f)))
         (out (render-json-string tbl)))
    (true (search "http://x.com" out))
    (false (search "\"title\": null" out))))

;;; -------------------------------------------------------
;;; Round-trip: parse -> render -> parse
;;; -------------------------------------------------------

(define-test roundtrip-single-feed
  :parent rsssavvy-suite
  "Parse then render then re-parse preserves feed data."
  (let* ((json "{\"rssfeeds\": [{\"title\": \"Test\",
                                     \"url\": \"http://test.com/rss\",
                                     \"icon\": \"\"}],
                   \"groups\": []}")
         (feeds1 (parse-json-string json))
         (rendered (render-json-string feeds1))
         (feeds2 (parse-json-string rendered)))
    (is = 1 (hash-table-count feeds2))
    (is equal "http://test.com/rss"
        (backend:feed-xml-url
         (first (gethash nil feeds2))))))

(define-test roundtrip-folders-preserved
  :parent rsssavvy-suite
  "Parse-render-parse preserves folder assignments."
  (let* ((json "{
  \"rssfeeds\": [
    {\"title\": \"A\", \"url\": \"http://a.com/rss\", \"icon\": \"\"},
    {\"title\": \"B\", \"url\": \"http://b.com/rss\", \"icon\": \"\"}
  ],
  \"groups\": [
    {\"title\": \"Tech\", \"filters\": [\"RS http://a.com/rss\"]}
  ]
}")
         (feeds1 (parse-json-string json))
         (rendered (render-json-string feeds1))
         (feeds2 (parse-json-string rendered)))
    (is = 1 (length (gethash "Tech" feeds2)))
    (is = 1 (length (gethash nil feeds2)))))

(define-test roundtrip-feed-count
  :parent rsssavvy-suite
  "Round-trip preserves total number of feeds."
  (let* ((json "{
  \"rssfeeds\": [
    {\"title\": \"A\", \"url\": \"http://a.com\", \"icon\": \"\"},
    {\"title\": \"B\", \"url\": \"http://b.com\", \"icon\": \"\"},
    {\"title\": \"C\", \"url\": \"http://c.com\", \"icon\": \"\"}
  ],
  \"groups\": [
    {\"title\": \"T\", \"filters\": [\"RS http://a.com\", \"RS http://b.com\"]}
  ]
}")
         (feeds1 (parse-json-string json))
         (total1 (loop for v being the hash-values of feeds1
                       sum (length v)))
         (rendered (render-json-string feeds1))
         (feeds2 (parse-json-string rendered))
         (total2 (loop for v being the hash-values of feeds2
                       sum (length v))))
    (is = total1 total2)))

;;; -------------------------------------------------------
;;; Integration with example file
;;; -------------------------------------------------------

(define-test parse-real-example
  :parent rsssavvy-suite
  "parse-feeds can handle a real RSSSavvy export file."
  (let* ((json "{
  \"rssfeeds\": [
    {\"title\": \"Example\", \"url\": \"http://ex.com/feed\", \"icon\": \"\"}
  ],
  \"groups\": [
    {\"title\": \"Test\", \"filters\": [\"RS http://ex.com/feed\"]}
  ]
}")
         (feeds (parse-json-string json)))
    (true feeds)
    (is = 1 (hash-table-count feeds))))
