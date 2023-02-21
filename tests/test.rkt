#lang racket

(module+ test
  (require "../fixw.rkt"
           rackunit)

  (define (string->lines str)
    (define in (open-input-string str))
    (for/list ([line (in-port read-line in)])
      line))

  (define original (port->string (open-input-file "expect.rkt")))
  (define formatted (fixw (open-input-string original) #f))
  (for ([l1 (string->lines formatted)]
        [l2 (string->lines original)])
    (check-equal? l1 l2)))

