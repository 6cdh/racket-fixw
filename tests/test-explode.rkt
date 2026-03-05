#lang racket

(module+ test
  (require rackunit
           "../fixw.rkt")

  (define (format-string str [rules #f])
    (fixw (open-input-string str) rules #:explode? #t))

  ;; Explore mode
  (check-equal?
    (format-string "(f arg1\n   arg2)")
    "(f arg1\n   arg2\n   )"
    "Standard function alignment"))

