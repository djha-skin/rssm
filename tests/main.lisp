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
    #:finish
    #:test)
  (:import-from
    #:com.djhaskin.rssm
    #:execute-program
    #:convert-command
    #:main)
  (:local-nicknames
    (#:parachute #:org.shirakumo.parachute)
    (#:rssm #:com.djhaskin.rssm)))

(in-package #:com.djhaskin.rssm/tests)

;;; Test the execute-program function with convert subcommand

(define-test convert-command-exists
  :parent nil
  (true (fboundp 'rssm:convert-command))
  (true (functionp (symbol-function 'rssm:convert-command))))

(define-test main-function-exists
  :parent nil
  (true (fboundp 'rssm:main))
  (true (functionp (symbol-function 'rssm:main))))

(define-test convert-newsboat-to-opml
  :parent nil
  (let* ((input "# Example Newsboat URLs file
https://example.com/feed \"~Example Feed\" \"News\"
https://blog.example.com/rss \"~Blog\" \"Tech\"")
         (results (multiple-value-list
                     (rssm:execute-program
                       "rssm"
                       :cli-arguments (list
                                        "convert"
                                        "--set-source-format" "newsboat"
                                        "--set-source" input
                                        "--set-dest-format" "opml"
                                        "--set-source-type" "string")
                       :subcommand-functions
                       (list (cons '("convert") #'rssm:convert-command))
                       :defaults nil
                       :suppress-final-output t)))
         (exit-code (first results))
         (result (second results)))
    (true (>= exit-code 0) "Exit code should be >= 0 for successful conversion")
    (true (hash-table-p result) "Result should be a hash table")
    (true (eq :SUCCESSFUL (gethash :status result))
          "Status should be :SUCCESSFUL")
    (true (stringp (gethash :output result)) "Output should be a string")))

(define-test convert-newsboat-to-json
  :parent nil
  (let* ((input "# Example Newsboat URLs file
https://example.com/feed \"~Example Feed\" \"News\"
https://blog.example.com/rss \"~Blog\" \"Tech\"")
         (results (multiple-value-list
                     (rssm:execute-program
                       "rssm"
                       :cli-arguments (list
                                        "convert"
                                        "--set-source-format" "newsboat"
                                        "--set-source" input
                                        "--set-dest-format" "json"
                                        "--set-source-type" "string")
                       :subcommand-functions
                       (list (cons '("convert") #'rssm:convert-command))
                       :defaults nil
                       :suppress-final-output t)))
         (exit-code (first results))
         (result (second results)))
    (true (>= exit-code 0) "Exit code should be >= 0 for successful conversion")
    (true (hash-table-p result) "Result should be a hash table")
    (true (eq :SUCCESSFUL (gethash :status result))
          "Status should be :SUCCESSFUL")
    (true (stringp (gethash :output result)) "Output should be a string")))

(define-test convert-json-to-newsboat
  :parent nil
  (let* ((input "{\"rssfeeds\": [{\"title\": \"Example\", \"url\": \"https://example.com/feed\", \"icon\": \"\"}], \"groups\": [{\"title\": \"News\", \"icon\": \"\", \"id\": \"1\", \"filters\": [\"RS https://example.com/feed\"]}]}")
         (results (multiple-value-list
                     (rssm:execute-program
                       "rssm"
                       :cli-arguments (list
                                        "convert"
                                        "--set-source-format" "json"
                                        "--set-source" input
                                        "--set-dest-format" "newsboat"
                                        "--set-source-type" "string")
                       :subcommand-functions
                       (list (cons '("convert") #'rssm:convert-command))
                       :defaults nil
                       :suppress-final-output t)))
         (exit-code (first results))
         (result (second results)))
    (true (>= exit-code 0) "Exit code should be >= 0 for successful conversion")
    (true (hash-table-p result) "Result should be a hash table")
    (true (eq :SUCCESSFUL (gethash :status result))
          "Status should be :SUCCESSFUL")
    (true (stringp (gethash :output result)) "Output should be a string")))

(define-test convert-json-to-opml
  :parent nil
  (let* ((input "{\"rssfeeds\": [{\"title\": \"Example\", \"url\": \"https://example.com/feed\", \"icon\": \"\"}], \"groups\": [{\"title\": \"News\", \"icon\": \"\", \"id\": \"1\", \"filters\": [\"RS https://example.com/feed\"]}]}")
         (results (multiple-value-list
                     (rssm:execute-program
                       "rssm"
                       :cli-arguments (list
                                        "convert"
                                        "--set-source-format" "json"
                                        "--set-source" input
                                        "--set-dest-format" "opml"
                                        "--set-source-type" "string")
                       :subcommand-functions
                       (list (cons '("convert") #'rssm:convert-command))
                       :defaults nil
                       :suppress-final-output t)))
         (exit-code (first results))
         (result (second results)))
    (true (>= exit-code 0) "Exit code should be >= 0 for successful conversion")
    (true (hash-table-p result) "Result should be a hash table")
    (true (eq :SUCCESSFUL (gethash :status result))
          "Status should be :SUCCESSFUL")
    (true (stringp (gethash :output result)) "Output should be a string")))

(define-test convert-opml-to-newsboat
  :parent nil
  (let* ((input "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<opml version=\"2.0\">
  <head><title>Test Feeds</title></head>
  <body>
    <outline text=\"News\" title=\"News\">
      <outline type=\"rss\" text=\"Example\" title=\"Example\" xmlUrl=\"https://example.com/feed\"/>
    </outline>
  </body>
</opml>")
         (results (multiple-value-list
                     (rssm:execute-program
                       "rssm"
                       :cli-arguments (list
                                        "convert"
                                        "--set-source-format" "opml"
                                        "--set-source" input
                                        "--set-dest-format" "newsboat"
                                        "--set-source-type" "string")
                       :subcommand-functions
                       (list (cons '("convert") #'rssm:convert-command))
                       :defaults nil
                       :suppress-final-output t)))
         (exit-code (first results))
         (result (second results)))
    (true (>= exit-code 0) "Exit code should be >= 0 for successful conversion")
    (true (hash-table-p result) "Result should be a hash table")
    (true (eq :SUCCESSFUL (gethash :status result))
          "Status should be :SUCCESSFUL")
    (true (stringp (gethash :output result)) "Output should be a string")))

(define-test convert-opml-to-json
  :parent nil
  (let* ((input "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<opml version=\"2.0\">
  <head><title>Test Feeds</title></head>
  <body>
    <outline text=\"News\" title=\"News\">
      <outline type=\"rss\" text=\"Example\" title=\"Example\" xmlUrl=\"https://example.com/feed\"/>
    </outline>
  </body>
</opml>")
         (results (multiple-value-list
                     (rssm:execute-program
                       "rssm"
                       :cli-arguments (list
                                        "convert"
                                        "--set-source-format" "opml"
                                        "--set-source" input
                                        "--set-dest-format" "json"
                                        "--set-source-type" "string")
                       :subcommand-functions
                       (list (cons '("convert") #'rssm:convert-command))
                       :defaults nil
                       :suppress-final-output t)))
         (exit-code (first results))
         (result (second results)))
    (true (>= exit-code 0) "Exit code should be >= 0 for successful conversion")
    (true (hash-table-p result) "Result should be a hash table")
    (true (eq :SUCCESSFUL (gethash :status result))
          "Status should be :SUCCESSFUL")
    (true (stringp (gethash :output result)) "Output should be a string")))

(define-test convert-roundtrip-newsboat-to-newsboat
  :parent nil
  (let* ((input "# Example Newsboat URLs file
https://example.com/feed \"~Example Feed\" \"News\"
https://blog.example.com/rss \"~Blog\" \"Tech\"")
         (results (multiple-value-list
                     (rssm:execute-program
                       "rssm"
                       :cli-arguments (list
                                        "convert"
                                        "--set-source-format" "newsboat"
                                        "--set-source" input
                                        "--set-dest-format" "newsboat"
                                        "--set-source-type" "string")
                       :subcommand-functions
                       (list (cons '("convert") #'rssm:convert-command))
                       :defaults nil
                       :suppress-final-output t)))
         (exit-code (first results))
         (result (second results)))
    (true (>= exit-code 0) "Exit code should be >= 0 for successful conversion")
    (true (hash-table-p result) "Result should be a hash table")
    (true (eq :SUCCESSFUL (gethash :status result))
          "Status should be :SUCCESSFUL")
    (true (stringp (gethash :output result)) "Output should be a string")
    (true (search "https://example.com/feed" (gethash :output result))
          "Output should contain first feed URL")
    (true (search "https://blog.example.com/rss" (gethash :output result))
          "Output should contain second feed URL")))

;;; Tests using example files

(define-test convert-newsboat-example-to-opml
  :parent nil
  (let* ((input "# Newsboat example
https://kevingal.com/feed.xml development")
         (results (multiple-value-list
                     (rssm:execute-program
                       "rssm"
                       :cli-arguments (list
                                        "convert"
                                        "--set-source-format" "newsboat"
                                        "--set-source" input
                                        "--set-dest-format" "opml"
                                        "--set-source-type" "string")
                       :subcommand-functions
                       (list (cons '("convert") #'rssm:convert-command))
                       :defaults nil
                       :suppress-final-output t)))
         (exit-code (first results))
         (result (second results))
         (output (gethash :output result)))
    (true (>= exit-code 0) "Exit code should be >= 0")
    (true (eq :SUCCESSFUL (gethash :status result)) "Status should be SUCCESSFUL")
    (true (stringp output) "Output should be a string")
    (true (search "<opml" output) "Output should contain OPML tag")
    (true (search "https://kevingal.com/feed.xml" output)
          "Output should contain feed URL")
    (true (search "development" output)
          "Output should contain tag/folder name")))

(define-test convert-newsboat-example-to-json
  :parent nil
  (let* ((input "# Newsboat example
https://kevingal.com/feed.xml development")
         (results (multiple-value-list
                     (rssm:execute-program
                       "rssm"
                       :cli-arguments (list
                                        "convert"
                                        "--set-source-format" "newsboat"
                                        "--set-source" input
                                        "--set-dest-format" "json"
                                        "--set-source-type" "string")
                       :subcommand-functions
                       (list (cons '("convert") #'rssm:convert-command))
                       :defaults nil
                       :suppress-final-output t)))
         (exit-code (first results))
         (result (second results))
         (output (gethash :output result)))
    (true (>= exit-code 0) "Exit code should be >= 0")
    (true (eq :SUCCESSFUL (gethash :status result)) "Status should be SUCCESSFUL")
    (true (stringp output) "Output should be a string")
    (true (search "rssfeeds" output) "Output should contain rssfeeds key")
    (true (search "kevingal" output) "Output should contain feed title")
    (true (search "https://kevingal.com/feed.xml" output)
          "Output should contain feed URL")))

(define-test convert-opml-example-to-newsboat
  :parent nil
  (let* ((input "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<opml version=\"2.0\">
  <head><title>Test</title></head>
  <body>
    <outline text=\"Tech\" title=\"Tech\">
      <outline type=\"rss\" text=\"Example\" xmlUrl=\"https://example.com/rss\"/>
    </outline>
  </body>
</opml>")
         (results (multiple-value-list
                     (rssm:execute-program
                       "rssm"
                       :cli-arguments (list
                                        "convert"
                                        "--set-source-format" "opml"
                                        "--set-source" input
                                        "--set-dest-format" "newsboat"
                                        "--set-source-type" "string")
                       :subcommand-functions
                       (list (cons '("convert") #'rssm:convert-command))
                       :defaults nil
                       :suppress-final-output t)))
         (exit-code (first results))
         (result (second results))
         (output (gethash :output result))
         (newline-count (count #\Newline output)))
    (true (>= exit-code 0) "Exit code should be >= 0")
    (true (eq :SUCCESSFUL (gethash :status result)) "Status should be SUCCESSFUL")
    (true (stringp output) "Output should be a string")
    (true (search "https://example.com/rss" output)
          "Output should contain feed URL")
    (true (search "Tech" output) "Output should contain folder name")
    (true (>= newline-count 2)
          "Should have at least 2 newlines (query line + feed line)")))

(define-test convert-json-example-to-newsboat
  :parent nil
  (let* ((input "{\"rssfeeds\": [{\"title\": \"Test Feed\", \"url\": \"https://test.com/feed.xml\", \"icon\": \"\"}], \"groups\": [{\"title\": \"Tech\", \"icon\": \"\", \"id\": 1, \"filters\": [\"RS https://test.com/feed.xml\"]}]}")
         (results (multiple-value-list
                     (rssm:execute-program
                       "rssm"
                       :cli-arguments (list
                                        "convert"
                                        "--set-source-format" "json"
                                        "--set-source" input
                                        "--set-dest-format" "newsboat"
                                        "--set-source-type" "string")
                       :subcommand-functions
                       (list (cons '("convert") #'rssm:convert-command))
                       :defaults nil
                       :suppress-final-output t)))
         (exit-code (first results))
         (result (second results))
         (output (gethash :output result)))
    (true (>= exit-code 0) "Exit code should be >= 0")
    (true (eq :SUCCESSFUL (gethash :status result)) "Status should be SUCCESSFUL")
    (true (stringp output) "Output should be a string")
    (true (search "https://test.com/feed.xml" output)
          "Output should contain feed URL")
    (true (search "Tech" output) "Output should contain folder/group name")))
