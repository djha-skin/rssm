;;;; rssm/tests/newsboat.lisp
;;;;
;;;; Unit tests for the newsboat format support.
;;;;
;;;; Tests cover every public-facing function in
;;;; src/newsboat.lisp, plus the parse-feeds and
;;;; render-feeds generic-function methods registered
;;;; for :newsboat format.

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
    #:of-type
    #:finish)
  (:import-from #:com.djhaskin.rssm/newsboat)
  (:import-from #:com.djhaskin.rssm/backend)
  (:local-nicknames
    (#:parachute #:org.shirakumo.parachute)
    (#:newsboat  #:com.djhaskin.rssm/newsboat)
    (#:backend   #:com.djhaskin.rssm/backend)))

(in-package #:com.djhaskin.rssm/tests/newsboat)

;;; -------------------------------------------------------
;;; Helpers
;;; -------------------------------------------------------

(defun rq (str)
  "Call internal read-quoted on STR (must start with \")."
  (with-input-from-string (s str)
    (newsboat::read-quoted s)))

(defun wq (str)
  "Call internal render-quoted on STR, return result."
  (with-output-to-string (s)
    (newsboat::render-quoted s str)))

(defun nt (str)
  "Call internal next-token on STR."
  (with-input-from-string (s str)
    (newsboat::next-token s)))

(defun make-nbt (title hidden value)
  "Construct a newsboat-tag."
  (make-instance 'newsboat::newsboat-tag
                 :title title
                 :hidden hidden
                 :value value))

(defun make-nbf (url tags)
  "Construct a newsboat-feed."
  (make-instance 'newsboat::newsboat-feed
                 :url url
                 :tags tags))

(defun nl ()
  "Return a one-character string containing a newline."
  (string #\Newline))

;;; -------------------------------------------------------
;;; Top-level suite
;;; -------------------------------------------------------

(define-test newsboat-suite)

;;; -------------------------------------------------------
;;; read-quoted
;;; -------------------------------------------------------

(define-test read-quoted-simple
  :parent newsboat-suite
  "read-quoted parses a plain quoted string."
  (is equal "hello" (rq "\"hello\"")))

(define-test read-quoted-empty
  :parent newsboat-suite
  "read-quoted returns the empty string for \"\"."
  (is equal "" (rq "\"\"")))

(define-test read-quoted-escaped-quote
  :parent newsboat-suite
  "read-quoted unescapes backslash-quote sequences."
  (is equal "say \"hi\""
      (rq "\"say \\\"hi\\\"\"")))

(define-test read-quoted-escaped-backslash
  :parent newsboat-suite
  "read-quoted unescapes double-backslash to one backslash."
  (is equal "back\\slash"
      (rq "\"back\\\\slash\"")))

(define-test read-quoted-fails-without-opening-quote
  :parent newsboat-suite
  "read-quoted signals an error when stream does not start with \"."
  (fail
    (with-input-from-string (s "noquote")
      (newsboat::read-quoted s))))

(define-test read-quoted-fails-on-empty-stream
  :parent newsboat-suite
  "read-quoted signals an error on an empty stream."
  (fail
    (with-input-from-string (s "")
      (newsboat::read-quoted s))))

;;; -------------------------------------------------------
;;; render-quoted
;;; -------------------------------------------------------

(define-test render-quoted-simple
  :parent newsboat-suite
  "render-quoted wraps a plain string in double quotes."
  (is equal "\"hello\"" (wq "hello")))

(define-test render-quoted-empty
  :parent newsboat-suite
  "render-quoted produces \"\" for the empty string."
  (is equal "\"\"" (wq "")))

(define-test render-quoted-escapes-quote
  :parent newsboat-suite
  "render-quoted backslash-escapes embedded double quotes."
  (is equal "\"say \\\"hi\\\"\""
      (wq "say \"hi\"")))

(define-test render-quoted-escapes-backslash
  :parent newsboat-suite
  "render-quoted doubles embedded backslashes."
  (is equal "\"back\\\\slash\""
      (wq "back\\slash")))

;;; -------------------------------------------------------
;;; render-quoted / read-quoted round-trip
;;; -------------------------------------------------------

(define-test quoted-roundtrip
  :parent newsboat-suite
  "render-quoted followed by read-quoted recovers the original."
  (let ((orig "complex \"quoted\" string with a\\backslash"))
    (is equal orig (rq (wq orig)))))

(define-test quoted-roundtrip-empty
  :parent newsboat-suite
  "Round-trip of the empty string works."
  (is equal "" (rq (wq ""))))

;;; -------------------------------------------------------
;;; next-token
;;; -------------------------------------------------------

(define-test next-token-unquoted
  :parent newsboat-suite
  "next-token reads an unquoted token up to the first space."
  (is equal "hello" (nt "hello world")))

(define-test next-token-quoted
  :parent newsboat-suite
  "next-token delegates to read-quoted when token starts with \"."
  (is equal "hello world"
      (nt "\"hello world\" next")))

(define-test next-token-skips-leading-spaces
  :parent newsboat-suite
  "next-token skips leading spaces before the token."
  (is equal "foo" (nt "   foo")))

(define-test next-token-nil-at-newline
  :parent newsboat-suite
  "next-token returns NIL when the first character is a newline."
  (false
    (with-input-from-string
      (s (concatenate 'string (nl) "more"))
      (newsboat::next-token s))))

(define-test next-token-nil-at-eof
  :parent newsboat-suite
  "next-token returns NIL on an empty stream."
  (false (nt "")))

(define-test next-token-unreads-newline
  :parent newsboat-suite
  "After consuming a token, the trailing newline stays in the stream."
  (is eql #\Newline
      (with-input-from-string
        (s (concatenate 'string "foo" (nl) "bar"))
        (newsboat::next-token s)
        (read-char s nil :eof))))

;;; -------------------------------------------------------
;;; token-to-tag
;;; -------------------------------------------------------

(define-test token-to-tag-plain
  :parent newsboat-suite
  "A plain token produces a non-hidden, non-title tag."
  (let ((tag (newsboat::token-to-tag "mytag")))
    (false (newsboat:newsboat-tag-hidden tag))
    (false (newsboat:newsboat-tag-title tag))
    (is equal "mytag"
        (newsboat:newsboat-tag-value tag))))

(define-test token-to-tag-tilde-prefix
  :parent newsboat-suite
  "A ~ prefix marks the tag as a custom feed title."
  (let ((tag (newsboat::token-to-tag "~MyTitle")))
    (false (newsboat:newsboat-tag-hidden tag))
    (true  (newsboat:newsboat-tag-title tag))
    (is equal "MyTitle"
        (newsboat:newsboat-tag-value tag))))

(define-test token-to-tag-bang-prefix
  :parent newsboat-suite
  "A ! prefix marks the tag as hidden."
  (let ((tag (newsboat::token-to-tag "!hiddentag")))
    (true  (newsboat:newsboat-tag-hidden tag))
    (false (newsboat:newsboat-tag-title tag))
    (is equal "hiddentag"
        (newsboat:newsboat-tag-value tag))))

(define-test token-to-tag-bare-bang
  :parent newsboat-suite
  "A bare ! is hidden everywhere, with an empty value."
  (let ((tag (newsboat::token-to-tag "!")))
    (true  (newsboat:newsboat-tag-hidden tag))
    (false (newsboat:newsboat-tag-title tag))
    (is equal ""
        (newsboat:newsboat-tag-value tag))))

(define-test token-to-tag-bang-tilde
  :parent newsboat-suite
  "!~ prefix sets both hidden and custom-name flags."
  (let ((tag (newsboat::token-to-tag "!~BothFlags")))
    (true (newsboat:newsboat-tag-hidden tag))
    (true (newsboat:newsboat-tag-title tag))
    (is equal "BothFlags"
        (newsboat:newsboat-tag-value tag))))

(define-test token-to-tag-tilde-bang
  :parent newsboat-suite
  "~! prefix (tilde first) also sets both flags."
  (let ((tag (newsboat::token-to-tag "~!BothFlags2")))
    (true (newsboat:newsboat-tag-hidden tag))
    (true (newsboat:newsboat-tag-title tag))
    (is equal "BothFlags2"
        (newsboat:newsboat-tag-value tag))))

;;; -------------------------------------------------------
;;; concrete-feed-p
;;; -------------------------------------------------------

(define-test concrete-feed-p-real
  :parent newsboat-suite
  "A normal HTTP feed URL is concrete."
  (true
    (newsboat:concrete-feed-p
      (make-nbf "http://example.com/rss" nil))))

(define-test concrete-feed-p-query
  :parent newsboat-suite
  "A query: URL is not concrete."
  (false
    (newsboat:concrete-feed-p
      (make-nbf "query:Folder:unread = \"yes\"" nil))))

;;; -------------------------------------------------------
;;; newsboat-to-generic
;;; -------------------------------------------------------

(define-test n2g-title-and-folder
  :parent newsboat-suite
  "newsboat-to-generic maps ~title and folder tags correctly."
  (let* ((tags (list (make-nbt t nil "My Feed")
                     (make-nbt nil nil "tech")))
         (gen (newsboat:newsboat-to-generic
                (make-nbf "http://ex.com/rss" tags))))
    (is equal "My Feed" (backend:feed-title gen))
    (is equal "http://ex.com/rss"
        (backend:feed-xml-url gen))
    (is equal "tech" (backend:feed-folder gen))))

(define-test n2g-no-title-tag
  :parent newsboat-suite
  "When no title tag exists, feed title is NIL."
  (let* ((tags (list (make-nbt nil nil "tech")))
         (gen (newsboat:newsboat-to-generic
                (make-nbf "http://ex.com/rss" tags))))
    (false (backend:feed-title gen))
    (is equal "tech" (backend:feed-folder gen))))

(define-test n2g-no-tags
  :parent newsboat-suite
  "With no tags at all, folder is NIL."
  (let* ((gen (newsboat:newsboat-to-generic
                (make-nbf "http://ex.com/rss" nil))))
    (false (backend:feed-title gen))
    (false (backend:feed-folder gen))))

(define-test n2g-empty-string-tag-not-folder
  :parent newsboat-suite
  "An empty-string tag does not become a folder."
  (let* ((tags (list (make-nbt nil nil "")))
         (gen (newsboat:newsboat-to-generic
                (make-nbf "http://ex.com/rss" tags))))
    (false (backend:feed-folder gen))))

;;; -------------------------------------------------------
;;; read-next-line (internal)
;;; -------------------------------------------------------

(define-test read-next-line-url-and-tag
  :parent newsboat-suite
  "read-next-line extracts URL and tags from a line."
  (let ((feed (with-input-from-string
                (s "http://ex.com/rss mytag")
                (newsboat::read-next-line s))))
    (is equal "http://ex.com/rss"
        (newsboat:newsboat-feed-url feed))
    (is = 1
        (length (newsboat:newsboat-feed-tags feed)))
    (is equal "mytag"
        (newsboat:newsboat-tag-value
          (first (newsboat:newsboat-feed-tags feed))))))

(define-test read-next-line-blank-line
  :parent newsboat-suite
  "A blank line (just a newline) returns NIL."
  (false
    (with-input-from-string (s (nl))
      (newsboat::read-next-line s))))

(define-test read-next-line-eof
  :parent newsboat-suite
  "An empty stream returns NIL."
  (false
    (with-input-from-string (s "")
      (newsboat::read-next-line s))))

(define-test read-next-line-two-consecutive
  :parent newsboat-suite
  "Two consecutive lines can be read independently."
  (is equal "http://b.com/rss"
      (with-input-from-string
        (s (concatenate 'string
             "http://a.com/rss" (nl)
             "http://b.com/rss" (nl)))
        (newsboat::read-next-line s)
        (newsboat:newsboat-feed-url
          (newsboat::read-next-line s)))))

;;; -------------------------------------------------------
;;; backend:parse-feeds :newsboat
;;; -------------------------------------------------------

(define-test parse-feeds-basic
  :parent newsboat-suite
  "parse-feeds puts feeds into the right folder buckets."
  (let* ((content
           (concatenate 'string
             "http://ex.com/r1 ~Feed1 tech" (nl)
             "query:tech:unread = \"yes\""  (nl)
             "http://ex.com/r2 ~Feed2 news" (nl)))
         (feeds (backend:parse-feeds-string
                  :newsboat content)))
    (is = 1 (length (gethash "tech" feeds)))
    (is = 1 (length (gethash "news" feeds)))))

(define-test parse-feeds-skips-query-lines
  :parent newsboat-suite
  "parse-feeds ignores query: virtual-feed lines."
  (let* ((content
           (concatenate 'string
             "query:tech:unread = \"yes\"" (nl)
             "http://ex.com/r1 tech"       (nl)))
         (feeds (backend:parse-feeds-string
                  :newsboat content)))
    (false (gethash "query" feeds))
    (is = 1 (length (gethash "tech" feeds)))))

(define-test parse-feeds-two-feeds-same-folder
  :parent newsboat-suite
  "Two feeds sharing a folder both appear in that bucket."
  (let* ((content
           (concatenate 'string
             "http://a.com/r1 tech" (nl)
             "http://a.com/r2 tech" (nl)))
         (feeds (backend:parse-feeds-string
                  :newsboat content)))
    (is = 2 (length (gethash "tech" feeds)))))

(define-test parse-feeds-no-folder-key
  :parent newsboat-suite
  "A feed with no tags lands under the NIL folder key."
  (let* ((content
           (concatenate 'string
             "http://a.com/r1" (nl)))
         (feeds (backend:parse-feeds-string
                  :newsboat content)))
    (is = 1 (length (gethash nil feeds)))))

(define-test parse-feeds-nil-folder-absent-when-all-tagged
  :parent newsboat-suite
  "No NIL key when every feed has a folder tag."
  (let* ((content
           (concatenate 'string
             "http://a.com/r1 tech" (nl)))
         (feeds (backend:parse-feeds-string
                  :newsboat content)))
    (false (gethash nil feeds))))

(define-test parse-feeds-returns-backend-feed-objects
  :parent newsboat-suite
  "Values in the hash are lists of backend:feed instances."
  (let* ((content
           (concatenate 'string
             "http://ex.com/r1 tech" (nl)))
         (feeds (backend:parse-feeds-string
                  :newsboat content))
         (feed  (first (gethash "tech" feeds))))
    (of-type backend:feed feed)
    (is equal "http://ex.com/r1"
        (backend:feed-xml-url feed))))

;;; -------------------------------------------------------
;;; backend:render-feeds :newsboat
;;; -------------------------------------------------------

(define-test render-feeds-query-line-present
  :parent newsboat-suite
  "render-feeds emits a query: virtual-feed line per folder."
  (let* ((f1 (make-instance 'backend:feed
               :xml-url "http://ex.com/r1"
               :folder  "tech"))
         (ht (make-hash-table :test #'equal)))
    (setf (gethash "tech" ht) (list f1))
    (let ((out (backend:render-feeds-string :newsboat ht)))
      (true
        (search "query:tech:unread" out)))))

(define-test render-feeds-feed-url-present
  :parent newsboat-suite
  "render-feeds includes the feed URL on a feed line."
  (let* ((f1 (make-instance 'backend:feed
               :xml-url "http://ex.com/r1"
               :folder  "tech"))
         (ht (make-hash-table :test #'equal)))
    (setf (gethash "tech" ht) (list f1))
    (let ((out (backend:render-feeds-string :newsboat ht)))
      (true (search "http://ex.com/r1" out)))))

(define-test render-feeds-title-with-tilde
  :parent newsboat-suite
  "render-feeds emits ~Title for feeds that have a title."
  (let* ((f1 (make-instance 'backend:feed
               :xml-url "http://ex.com/r1"
               :title   "My Feed"
               :folder  "tech"))
         (ht (make-hash-table :test #'equal)))
    (setf (gethash "tech" ht) (list f1))
    (let ((out (backend:render-feeds-string :newsboat ht)))
      (true (search "~My Feed" out)))))

(define-test render-feeds-no-title-omits-tilde-token
  :parent newsboat-suite
  "render-feeds omits the ~Title token when title is NIL."
  (let* ((f1 (make-instance 'backend:feed
               :xml-url "http://ex.com/r1"
               :folder  "tech"))
         (ht (make-hash-table :test #'equal)))
    (setf (gethash "tech" ht) (list f1))
    (let ((out (backend:render-feeds-string :newsboat ht)))
      (false (search "~" out)))))

(define-test render-feeds-folder-tag-present
  :parent newsboat-suite
  "render-feeds appends the folder name as a quoted tag."
  (let* ((f1 (make-instance 'backend:feed
               :xml-url "http://ex.com/r1"
               :folder  "tech"))
         (ht (make-hash-table :test #'equal)))
    (setf (gethash "tech" ht) (list f1))
    (let ((out (backend:render-feeds-string :newsboat ht)))
      (true (search "\"tech\"" out)))))
