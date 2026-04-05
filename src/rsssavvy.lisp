;;;; rssm/src/rsssavvy.lisp
;;;;
;;;; RSSSavvy format support for RSSM.
;;;;
;;;; The purpose of this file is to implement `backend:parse-feeds` and
;;;; `backend:render-feeds` for the RSSSavvy JSON format.
;;;;
;;;; RSSSavvy uses a JSON structure with:
;;;; - `rssfeeds`: array of {title, url, icon} objects
;;;; - `groups`: array of {title, icon, id, filters} objects
;;;; - `userid`: string identifier
;;;;
;;;; Groups use filters like `"RS <url>"` to assign feeds to folders.
;;;; Feeds without a group assignment go to the NIL folder.

(defpackage #:com.djhaskin.rssm/rsssavvy
  (:use #:cl)
  (:import-from #:com.djhaskin.rssm/backend)
  (:local-nicknames (#:backend #:com.djhaskin.rssm/backend)
                    (#:nrdl #:com.djhaskin.nrdl))
  (:export #:parse-feeds
           #:render-feeds
           #:rsssavvy-folder-of-url
           #:rsssavvy-group-to-folder
           #:filter-to-url
           #:rsssavvy-group-filters))

(in-package #:com.djhaskin.rssm/rsssavvy)

;;; Helper to get a list from NRDL output (NRDL returns cons for arrays)

(defun ensure-list (x)
  "Ensure X is a proper list. Returns X if it's a list, NIL if null."
  (cond
    ((null x) nil)
    ((listp x) x)
    (t nil)))

;;; Filter Parsing

(defun rsssavvy-group-to-folder (group)
  "Extract the folder name from a RSSSavvy group object (hash table)."
  (gethash "title" group))

(defun rsssavvy-group-filters (group)
  "Get the list of filter strings from a RSSSavvy group object.
   Returns a list or nil."
  (ensure-list (gethash "filters" group)))

(defun filter-to-url (filter)
  "Extract the URL from a RSSSavvy filter string.
   Filters are in the form 'RS <url>' or just 'RS' for the Hub.
   Returns the URL portion or NIL if not applicable."
  (let ((prefix "RS "))
    (when (and (stringp filter)
               (>= (length filter) (length prefix))
               (string= prefix filter :start2 0 :end2 (length prefix)))
      (let ((url (subseq filter (length prefix))))
        (unless (string= url "")
          url)))))

(defun rsssavvy-folder-of-url (url groups)
  "Find the folder name for a given URL based on group filters.
   Returns the folder name (a string) or NIL if no group contains
   this URL in its filters."
  (when (null groups)
    (return-from rsssavvy-folder-of-url nil))
  (dolist (group groups)
    (let ((folder (rsssavvy-group-to-folder group))
          (filters (rsssavvy-group-filters group)))
      (when filters
        (dolist (filter filters)
          (when (string= url (filter-to-url filter))
            (return-from rsssavvy-folder-of-url folder))))))
  nil)

;;; Parsing

(defun parse-rssfeeds-array (rssfeeds groups)
  "Parse the rssfeeds array into a list of backend:feed objects.
   Each feed is assigned to a folder based on its URL matching
   a group's filter. Feeds not matching any group go to NIL folder."
  (when (null rssfeeds)
    (return-from parse-rssfeeds-array nil))
  (loop for feed-obj in rssfeeds
        for url = (gethash "url" feed-obj)
        for title = (gethash "title" feed-obj)
        for folder = (rsssavvy-folder-of-url url groups)
        collect (make-instance 'backend:feed
                              :xml-url url
                              :title (or title "")
                              :folder folder)))

(defmethod backend:parse-feeds ((fmt (eql :rsssavvy)) strm)
  "Parse RSSSavvy JSON format from stream.
   Returns a hash table mapping folder names to lists of feeds."
  (let* ((json (nrdl:parse-from strm))
         (rssfeeds (ensure-list (gethash "rssfeeds" json)))
         (groups (ensure-list (gethash "groups" json)))
         (feeds (make-hash-table :test #'equal)))
    (loop for feed in (parse-rssfeeds-array rssfeeds groups)
          for folder = (backend:feed-folder feed)
          do (push feed (gethash folder feeds)))
    feeds))

;;; Rendering

(defun make-rssfeeds-array (feeds)
  "Generate the rssfeeds JSON array from the feeds hash table.
   Returns a list of hash tables representing feed objects."
  (loop for folder being the hash-keys of feeds
        using (hash-value folder-feeds)
        append
        (loop for feed in folder-feeds
              collect (let ((ht (make-hash-table :test #'equal)))
                        (setf (gethash "title" ht) (backend:feed-title feed))
                        (setf (gethash "url" ht) (backend:feed-xml-url feed))
                        (setf (gethash "icon" ht) "")
                        ht))))

(defun group-feeds (feeds)
  "Group feeds by folder, excluding the NIL folder.
   Returns an alist of (folder-name . feeds-list)."
  (loop for folder being the hash-keys of feeds
        using (hash-value folder-feeds)
        when folder
          collect (cons folder folder-feeds)))

(defun make-filters-for-feed (url)
  "Create the filter string for a feed URL."
  (format nil "RS ~A" url))

(defun make-group-object (folder-name feeds)
  "Create a RSSSavvy group object for a folder."
  (let ((ht (make-hash-table :test #'equal)))
    (setf (gethash "title" ht) folder-name)
    (setf (gethash "icon" ht) (format nil "asset:///images/ic_~A.png"
                                       (char-downcase (char folder-name 0))))
    (setf (gethash "id" ht) (random #x7FFFFFFF))
    (setf (gethash "filters" ht)
          (loop for feed in feeds
                collect (make-filters-for-feed
                         (backend:feed-xml-url feed))))
    ht))

(defun make-groups-array (feeds)
  "Generate the groups JSON array from feeds.
   Only non-NIL folders become groups."
  (loop for (folder . folder-feeds) in (group-feeds feeds)
        collect (make-group-object folder folder-feeds)))

(defmethod backend:render-feeds ((fmt (eql :rsssavvy)) feeds strm)
  "Render feeds to RSSSavvy JSON format."
  (nrdl:generate-to
   strm
   (let ((ht (make-hash-table :test #'equal)))
     (setf (gethash "rssfeeds" ht) (make-rssfeeds-array feeds))
     (setf (gethash "groups" ht) (make-groups-array feeds))
     (setf (gethash "userid" ht) "generated-by-rssm")
     ht)
   :json-mode t))
