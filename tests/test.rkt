#lang racket

(module+ test
  (require "../fixw.rkt"
           rackunit)

  (define (string->lines str)
    (define in (open-input-string str))
    (for/list ([line (in-port read-line in)])
      line))

  (define port (open-input-file "expect.rkt"))
  (define code (port->bytes port))
  (define original-lines (port->lines (open-input-bytes code)))
  (define formatted (fixw (open-input-bytes code) #f))
  (for ([l1 (string->lines formatted)]
        [l2 original-lines])
    (check-equal? l1 l2)))

