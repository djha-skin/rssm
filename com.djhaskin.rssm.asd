(defsystem "com.djhaskin.rssm"
  :version "0.1.0"
  :author "Daniel Jay Haskin"
  :license "MIT"
  :depends-on (
               "alexandria"
               "com.djhaskin.cliff"
               "plump"
               "parachute"
               )
  :components ((:module "src"
          :components
          ((:file "backend")
           (:file "newsboat")
           (:file "opml")
           (:file "rsssavvy")
           (:file "main"))))
  :description "RSS Manager - A tool for managing RSS feeds across Newsboat, RSSSavvy, and OPML formats"
  :in-order-to (
                (test-op (test-op "com.djhaskin.rssm/tests"))))

(defsystem "com.djhaskin.rssm/tests"
  :version "0.1.0"
  :author "Daniel Jay Haskin"
  :license "MIT"
  :depends-on (
               "com.djhaskin.rssm"
               "parachute"
               )
  :components ((:module "tests"
                :components
                ((:file "main")
                 (:file "backend"))))
  :description "Test system for RSSM"
  :perform (asdf:test-op (op c)
                         (uiop:symbol-call
                           :parachute
                           :test :com.djhaskin.rssm/tests)))
