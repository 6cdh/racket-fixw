#lang racket/base

(require racket/cmdline
         "cli.rkt")

(define time-mode? (make-parameter #f))
(define paths
  (command-line
    #:program "fixw"
    #:once-each
    [("-t" "--time") "show total time to run"
                     (time-mode? #t)]
    #:args files-or-dirs
    files-or-dirs))

(cond [(time-mode?) (time (run/user paths))]
      [else (run/user paths)])

