;;;; tests/newsboat.lisp
;;;;
;;;; Unit tests for the newsboat format support.

(defpackage #:com.djhaskin.rssm/tests/newsboat
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
    #:com.djhaskin.rssm/newsboat)
  (:import-from
    #:com.djhaskin.rssm/backend)
  (:local-nicknames
    (#:parachute #:org.shirakumo.parachute)
    (#:newsboat #:com.djhaskin.rssm/newsboat)
    (#:backend #:com.djhaskin.rssm/backend)))

(in-package #:com.djhaskin.rssm/tests/newsboat)

;;; ============================================================================
;;; Tokenization Tests
;;; ============================================================================

(define-test tokenize-simple-line
  "Test tokenization of a simple line without quotes."
  (let ((tokens (newsboat:newsboat-tokenize-with-quotes "http://example.com/feed.xml")))
    (is equal 1 (length tokens))
    (is equal "http://example.com/feed.xml" (first tokens))))

(define-test tokenize-line-with-title
  "Test tokenization of a line with URL and title."
  (let ((tokens (newsboat:newsboat-tokenize-with-quotes "http://example.com/feed.xml Example Feed")))
    (is equal 2 (length tokens))
    (is equal "http://example.com/feed.xml" (first tokens))
    (is equal "Example Feed" (second tokens))))

(define-test tokenize-line-with-quoted-title
  "Test tokenization of a line with a quoted title containing spaces."
  (let ((tokens (newsboat:newsboat-tokenize-with-quotes "http://example.com/feed.xml \"Example Feed\"")))
    (is equal 2 (length tokens))
    (is equal "http://example.com/feed.xml" (first tokens))
    (is equal "\"Example Feed\"" (second tokens))))

(define-test tokenize-line-with-tags
  "Test tokenization of a line with URL, title, and tags."
  (let ((tokens (newsboat:newsboat-tokenize-with-quotes "http://example.com/feed.xml Example #tech #news")))
    (is equal 4 (length tokens))
    (is equal "http://example.com/feed.xml" (first tokens))
    (is equal "Example" (second tokens))
    (is equal "#tech" (third tokens))
    (is equal "#news" (fourth tokens))))

(define-test tokenize-empty-line
  "Test tokenization of an empty line."
  (let ((tokens (newsboat:newsboat-tokenize-with-quotes "")))
    (is equal 0 (length tokens))))

;;; ============================================================================
;;; Parsing Tests
;;; ============================================================================

(define-test parse-empty-line
  "Test parsing of an empty line returns nil."
  (false (newsboat:parse-newsboat-line "")))

(define-test parse-comment-line
  "Test parsing of a comment line returns nil."
  (false (newsboat:parse-newsboat-line "# This is a comment"))
  (false (newsboat:parse-newsboat-line "#Comment without space")))

(define-test parse-simple-feed
  "Test parsing of a simple feed line with just URL."
  (let ((result (newsboat:parse-newsboat-line "http://example.com/feed.xml")))
    (is equal :feed (getf result :type))
    (is equal "http://example.com/feed.xml" (getf result :xml-url))
    (is equal "feed.xml" (getf result :title))))

(define-test parse-feed-with-title
  "Test parsing of a feed line with URL and title."
  (let ((result (newsboat:parse-newsboat-line "http://example.com/feed.xml My Feed")))
    (is equal :feed (getf result :type))
    (is equal "http://example.com/feed.xml" (getf result :xml-url))
    (is equal "My Feed" (getf result :title))))

(define-test parse-feed-with-tags
  "Test parsing of a feed line with URL, title, and tags."
  (let ((result (newsboat:parse-newsboat-line "http://example.com/feed.xml My Feed #tech #news")))
    (is equal :feed (getf result :type))
    (is equal "http://example.com/feed.xml" (getf result :xml-url))
    (is equal "My Feed" (getf result :title))
    (is equal '("#tech" "#news") (getf result :tags))))

(define-test parse-query-line
  "Test parsing of a query line (folder)."
  (let ((result (newsboat:parse-newsboat-line "query:Development:unread = \"yes\" and tags # \"development\"")))
    (is equal :folder (getf result :type))
    (is equal "Development" (getf result :title))))

(define-test parse-full-file
  "Test parsing of a complete newsboat URLs file content."
  (let* ((content "query:Development:unread = \"yes\" and tags # \"development\"
query:News:unread = \"yes\" and tags # \"news\"
http://example.com/feed.xml Example Feed #development
http://news.com/rss.xml News Site #news")
         (feeds (newsboat:parse-newsboat-string content)))
    (is equal 4 (length feeds))
    (is equal :folder (getf (first feeds) :type))
    (is equal "Development" (getf (first feeds) :title))
    (is equal :feed (getf (third feeds) :type))
    (is equal "http://example.com/feed.xml" (getf (third feeds) :xml-url))
    (is equal "Example Feed" (getf (third feeds) :title))))

(define-test parse-with-feed-class
  "Test parsing with a feed-class argument returns proper instances."
  (let* ((content "http://example.com/feed.xml Example Feed")
         (feeds (newsboat:parse-newsboat-string content 'backend:feed)))
    (is equal 1 (length feeds))
    (of-type backend:feed (first feeds))
    (is equal "Example Feed" (backend:feed-title (first feeds)))
    (is equal "http://example.com/feed.xml" (backend:feed-xml-url (first feeds)))))

;;; ============================================================================
;;; Rendering Tests
;;; ============================================================================

(define-test render-simple-feed
  "Test rendering of a simple feed."
  (let ((feed (list :type :feed
                    :title "Example Feed"
                    :xml-url "http://example.com/feed.xml")))
    (is equal "http://example.com/feed.xml Example Feed"
              (newsboat:render-newsboat-line feed))))

(define-test render-feed-without-title
  "Test rendering of a feed without title uses filename."
  (let ((feed (list :type :feed
                    :title nil
                    :xml-url "http://example.com/feed.xml")))
    (is equal "http://example.com/feed.xml feed.xml"
              (newsboat:render-newsboat-line feed))))

(define-test render-folder
  "Test rendering of a folder (query line)."
  (let ((feed (list :type :folder
                    :title "Development"
                    :folder "Development")))
    (is equal "query:Development:unread = \"yes\" and tags # \"Development\""
              (newsboat:render-newsboat-line feed))))

(define-test render-full-file
  "Test rendering of a complete feed list."
  (let ((feeds (list (list :type :folder
                           :title "Development"
                           :folder "Development")
                     (list :type :feed
                           :title "Example Feed"
                           :xml-url "http://example.com/feed.xml"))))
    (let ((output (newsboat:render-newsboat-string feeds)))
      (is (stringp output))
      (true (string-search "query:Development" output))
      (true (string-search "http://example.com/feed.xml Example Feed" output)))))

(define-test render-with-custom-accessors
  "Test rendering with custom accessor functions."
  (let ((feeds (list (make-instance 'backend:feed
                                    :title "Test"
                                    :xml-url "http://test.com/feed.xml")))
        (output (newsboat:render-newsboat-string feeds
                                                  :xml-url-accessor #'backend:feed-xml-url
                                                  :title-accessor #'backend:feed-title)))
    (true (string-search "http://test.com/feed.xml Test" output))))

;;; ============================================================================
;;; Generic Function Method Tests
;;; ============================================================================

(define-test parse-feeds-generic
  "Test the parse-feeds generic function for newsboat format."
  (let* ((content "http://example.com/feed.xml Example Feed")
         (feeds (backend:parse-feeds :newsboat content)))
    (is equal 1 (length feeds))
    (is equal "http://example.com/feed.xml" (getf (first feeds) :xml-url))))

(define-test render-feeds-generic
  "Test the render-feeds generic function for newsboat format."
  (let ((feeds (list (list :type :feed
                           :title "Example"
                           :xml-url "http://example.com/feed.xml")))
        (output (backend:render-feeds :newsboat feeds)))
    (true (string-search "http://example.com/feed.xml Example" output))))
