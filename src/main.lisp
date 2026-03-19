(defpackage #:com.djhaskin.rssm
  (:use #:cl)
  (:import-from #:com.djhaskin.cliff)
  (:import-from #:com.djhaskin.rssm/backend)
  (:import-from #:com.djhaskin.rssm/newsboat)
  (:import-from #:com.djhaskin.rssm/opml)
  (:import-from #:com.djhaskin.rssm/rsssavvy)
  (:use #:com.djhaskin.rssm/backend)
  (:local-nicknames (#:alex #:alexandria)
                    (#:cliff #:com.djhaskin.cliff))
  (:export #:main))

