#lang racket/base

(module+ main
  (require racket/cmdline)
  (require "cli.rkt")
  (define time-mode? (make-parameter #f))
  (define files
    (command-line
     #:program "fixw"
     #:once-each
     [("-t" "--time") "show total time to run"
                      (time-mode? #t)]
     #:args files
     files))

  (cond [(time-mode?) (time (run files))]
        [else (run files)]))

