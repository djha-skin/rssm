(defpackage #:com.djhaskin.rssm
  (:use #:cl)
  (:import-from #:com.djhaskin.cliff)
  (:import-from #:com.djhaskin.rssm/backend)
  (:use #:com.djhaskin.rssm/backend)
  (:local-nicknames (#:alex #:alexandria)
                    (#:cliff #:com.djhaskin.cliff))
  (:export #:main))

(in-package #:com.djhaskin.rssm)

;;; Helpers

(defun trim-or-nil (value)
  (let ((trimmed (and value (string-trim '(#\Space #\Tab #\Newline) value))))
    (unless (or (null trimmed) (string= trimmed ""))
      trimmed)))

(defun json-escape (value)
  (let ((text (or value "")))
    (with-output-to-string (out)
      (loop for ch across text
            do (case ch
                 (#\\ (write-string "\\\\" out))
                 (#\" (write-string "\\\"" out))
                 (#\Newline (write-string "\\n" out))
                 (#\Return (write-string "\\r" out))
                 (#\Tab (write-string "\\t" out))
                 (t (write-char ch out)))))))

(defun xml-escape (value)
  (let ((text (or value "")))
    (with-output-to-string (out)
      (loop for ch across text
            do (case ch
                 (#\& (write-string "&amp;" out))
                 (#\< (write-string "&lt;" out))
                 (#\> (write-string "&gt;" out))
                 (#\" (write-string "&quot;" out))
                 (t (write-char ch out)))))))

(defun split-lines (text)
  (with-input-from-string (in text)
    (loop for line = (read-line in nil nil)
          while line
          collect line)))

(defun split-whitespace (text)
  (let ((parts '())
        (start nil)
        (len (length text)))
    (loop for i from 0 below len
          for ch = (char text i)
          do (if (find ch '(#\Space #\Tab #\Newline #\Return))
                 (when start
                   (push (subseq text start i) parts)
                   (setf start nil))
                 (unless start
                   (setf start i))))
    (when start
      (push (subseq text start) parts))
    (nreverse parts)))

(defun feed-from-tsv (line)
  (let* ((parts (split-whitespace (substitute #\Space #\Tab line)))
         (url (first parts))
         (title (second parts))
         (home-page (third parts))
         (folder (fourth parts)))
    (when (trim-or-nil url)
      (make-instance 'feed
                     :xml-url (trim-or-nil url)
                     :title (trim-or-nil title)
                     :home-page-url (trim-or-nil home-page)
                     :folder (trim-or-nil folder)))))

(defun run-python-parser (script text)
  (let ((output (uiop:run-program
                 (list "python3" "-c" script)
                 :input text
                 :output :string)))
    (split-lines output)))

(defun parse-rsssavvy-json-string (text)
  (let* ((script
          (concatenate
           'string
           "import json,sys\n"
           "data=json.load(sys.stdin)\n"
           "folders={}\n"
           "for group in data.get('groups', []):\n"
           "  title=(group.get('title') or '').strip()\n"
           "  for filt in group.get('filters', []):\n"
           "    if isinstance(filt, str) and filt.startswith('RS '):\n"
           "      folders[filt[3:]]=title\n"
           "for feed in data.get('rssfeeds', []):\n"
           "  url=(feed.get('url') or '').strip()\n"
           "  title=(feed.get('title') or '').strip()\n"
           "  folder=folders.get(url, '').strip()\n"
           "  home=''\n"
           "  cols=[url,title,home,folder]\n"
           "  cols=[c.replace('\\t',' ').replace('\\n',' ') for c in cols]\n"
           "  print('\\t'.join(cols))\n"))
         (lines (run-python-parser script text)))
    (loop for line in lines
          for feed = (feed-from-tsv line)
          when feed
            collect feed)))

(defun parse-opml-string (text)
  (let* ((script
          (concatenate
           'string
           "import sys\n"
           "import xml.etree.ElementTree as ET\n"
           "root=ET.fromstring(sys.stdin.read())\n"
           "def local(tag):\n"
           "  return tag.split('}',1)[-1]\n"
           "def children(node,name):\n"
           "  return [c for c in list(node) if local(c.tag)==name]\n"
           "def attr(node,key):\n"
           "  return (node.attrib.get(key) or '').strip()\n"
           "body=None\n"
           "for child in list(root):\n"
           "  if local(child.tag)=='body':\n"
           "    body=child\n"
           "    break\n"
           "if body is None:\n"
           "  body=root\n"
           "def emit(url,title,home,folder):\n"
           "  cols=[url,title,home,folder]\n"
           "  cols=[c.replace('\\t',' ').replace('\\n',' ') for c in cols]\n"
           "  print('\\t'.join(cols))\n"
           "def walk(node,folder=None,depth=0):\n"
           "  for o in children(node,'outline'):\n"
           "    xml=attr(o,'xmlUrl') or attr(o,'xmlurl')\n"
           "    title=attr(o,'title') or attr(o,'text')\n"
           "    home=attr(o,'htmlUrl') or attr(o,'htmlurl')\n"
           "    if xml:\n"
           "      emit(xml,title,home,folder or '')\n"
           "    else:\n"
           "      next_folder=folder\n"
           "      if depth==0:\n"
           "        next_folder=title\n"
           "      walk(o,next_folder,depth+1)\n"
           "walk(body)\n"))
         (lines (run-python-parser script text)))
    (loop for line in lines
          for feed = (feed-from-tsv line)
          when feed
            collect feed)))

(defun render-rsssavvy-json-string (feeds)
  (let ((groups (make-hash-table :test #'equal))
        (group-order '()))
    (dolist (f feeds)
      (let ((folder (trim-or-nil (feed-folder f))))
        (when folder
          (unless (gethash folder groups)
            (setf (gethash folder groups) '())
            (push folder group-order))
          (push (feed-xml-url f) (gethash folder groups)))))
    (with-output-to-string (out)
      (write-string "{\n  \"rssfeeds\": [\n" out)
      (loop for feed in feeds
            for i from 0
            do (format out
                       "    {\"title\": \"~a\", \"url\": \"~a\", "
                       (json-escape (or (feed-title feed) ""))
                       (json-escape (feed-xml-url feed)))
               (format out "\"icon\": \"\"}~a~%"
                       (if (< i (1- (length feeds))) "," "")))
      (write-string "  ],\n  \"groups\": [\n" out)
      (let* ((ordered (nreverse group-order))
             (count (length ordered)))
        (loop for folder in ordered
              for index from 0
              for urls = (nreverse (copy-list (gethash folder groups)))
              do (format out
                         "    {\"title\": \"~a\", \"icon\": \"\", "
                         (json-escape folder))
                 (format out "\"id\": ~d, \"filters\": [" (1+ index))
                 (loop for url in urls
                       for j from 0
                       do (format out "\"RS ~a\"~a"
                                  (json-escape url)
                                  (if (< j (1- (length urls))) ", " "")))
                 (format out "]}~a~%"
                         (if (< index (1- count)) "," ""))))
      (write-string "  ],\n  \"userid\": \"\"\n}\n" out))))

(defun render-opml-feed (feed)
  (format nil
          "    <outline type=\"rss\" title=\"~a\" text=\"~a\" "
          (xml-escape (or (feed-title feed) ""))
          (xml-escape (or (feed-title feed) ""))))

(defun render-opml-string (feeds)
  (let ((groups (make-hash-table :test #'equal))
        (group-order '())
        (root-feeds '()))
    (dolist (f feeds)
      (let ((folder (trim-or-nil (feed-folder f))))
        (if folder
            (progn
              (unless (gethash folder groups)
                (setf (gethash folder groups) '())
                (push folder group-order))
              (push f (gethash folder groups)))
            (push f root-feeds))))
    (with-output-to-string (out)
      (write-string "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" out)
      (write-string "<opml version=\"1.0\">\n" out)
      (write-string "  <head>\n" out)
      (write-string "    <title>RSSM Export</title>\n" out)
      (write-string "  </head>\n" out)
      (write-string "  <body>\n" out)
      (dolist (feed (nreverse root-feeds))
        (format out
                "    <outline type=\"rss\" title=\"~a\" text=\"~a\" "
                (xml-escape (or (feed-title feed) ""))
                (xml-escape (or (feed-title feed) "")))
        (format out "xmlUrl=\"~a\" htmlUrl=\"~a\"/>~%"
                (xml-escape (feed-xml-url feed))
                (xml-escape (or (feed-home-page-url feed) ""))))
      (dolist (folder (nreverse group-order))
        (format out "    <outline title=\"~a\">~%" (xml-escape folder))
        (dolist (feed (nreverse (gethash folder groups)))
          (format out
                  "      <outline type=\"rss\" title=\"~a\" text=\"~a\" "
                  (xml-escape (or (feed-title feed) ""))
                  (xml-escape (or (feed-title feed) "")))
          (format out "xmlUrl=\"~a\" htmlUrl=\"~a\"/>~%"
                  (xml-escape (feed-xml-url feed))
                  (xml-escape (or (feed-home-page-url feed) ""))))
        (write-string "    </outline>\n" out))
      (write-string "  </body>\n" out)
      (write-string "</opml>\n" out))))

(defun supported-format-p (name)
  (member (string-downcase (or name ""))
          '("newsboat" "json" "opml")
          :test #'string=))

(defun read-feeds (format-name input-path)
  (let* ((text (uiop:read-file-string input-path))
         (format-key (string-downcase format-name)))
    (cond
      ((string= format-key "newsboat")
       (parse-newsboat-string text 'feed))
      ((string= format-key "json")
       (parse-rsssavvy-json-string text))
      ((string= format-key "opml")
       (parse-opml-string text))
      (t
       (error "Unsupported source format: ~a" format-name)))))

(defun write-feeds (feeds format-name output-path)
  (let* ((format-key (string-downcase format-name))
         (text (cond
                 ((string= format-key "newsboat")
                  (render-newsboat-string feeds
                                          #'feed-xml-url
                                          #'feed-title
                                          #'feed-folder))
                 ((string= format-key "json")
                  (render-rsssavvy-json-string feeds))
                 ((string= format-key "opml")
                  (render-opml-string feeds))
                 (t
                  (error "Unsupported destination format: ~a"
                         format-name)))))
    (with-open-file (out output-path :direction :output :if-exists :supersede)
      (write-string text out))
    feeds))

(defun run-convert (source-format dest-format input output)
  (let ((feeds (read-feeds source-format input)))
    (write-feeds feeds dest-format output)
    feeds))

;;; Subcommands

(defun version (options)
  "Return the version of the application."
  (declare (ignore options))
  (let ((result (make-hash-table :test #'equal)))
    (setf (gethash :version result) "0.1.0")
    (setf (gethash :status result) :successful)
    (setf (gethash :cliff-suppress-output result) nil)
    result))

(defun convert (options)
  "Convert feeds between different formats."
  (let ((result (make-hash-table :test #'equal))
        (source-format (gethash "source-format" options))
        (dest-format (gethash "dest-format" options))
        (input (gethash "input" options))
        (output (gethash "output" options)))
    (handler-case
        (progn
          (unless (supported-format-p source-format)
            (error "Invalid --source-format: ~a" source-format))
          (unless (supported-format-p dest-format)
            (error "Invalid --dest-format: ~a" dest-format))
          (unless (trim-or-nil input)
            (error "Missing --input path"))
          (unless (trim-or-nil output)
            (error "Missing --output path"))
          (let ((feeds (run-convert source-format dest-format input output)))
            (setf (gethash :count result) (length feeds))
            (setf (gethash :status result) :successful)
            (setf (gethash :cliff-suppress-output result) t)
            result))
      (error (condition)
        (setf (gethash :status result) :failed)
        (setf (gethash :error result)
              (with-output-to-string (out)
                (princ condition out)))
        (setf (gethash :cliff-suppress-output result) nil)
        result))))

;;; CLI Entry Point

(defun main (argv)
  "Entry point for RSSM application."
  (cliff:execute-program
   "rssm"
   :subcommand-functions
   `(("version" . ,#'version)
     (("convert") . ,#'convert))
   :subcommand-helps
   `(("version" . "Print version information.")
     (("convert") . "Convert between feed formats."))
   :default-function
   (lambda (options)
     (declare (ignore options))
     (let ((result (make-hash-table :test #'equal)))
       (format t "RSSM - RSS Manager~%")
       (format t "Use 'rssm help' for usage information.~%")
       (setf (gethash :status result) :successful)
       result))
   :default-func-help "Manage RSS feeds across different formats."
   :cli-arguments argv
   :cli-aliases '(("-h" . "help")
                  ("--help" . "help")
                  ("-v" . "version")
                  ("--version" . "version")
                  ("-s" . "--source-format")
                  ("-d" . "--dest-format")
                  ("-i" . "--input")
                  ("-o" . "--output"))
   :suppress-final-output nil))
