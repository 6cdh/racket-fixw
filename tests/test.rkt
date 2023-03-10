#lang racket

(module+ test
  (require "../fixw.rkt"
           rackunit)

  (define (string->lines str)
    (define in (open-input-string str))
    (for/list ([line (in-port read-line in)])
      line))

  (define port (open-input-file "expect.rkt"))
  (define code (port->string port))
  (define original-lines (string->lines code))
  (define formatted (fixw (open-input-string code) #f))
  (for ([l1 (string->lines formatted)]
        [l2 original-lines])
    (check-equal? l1 l2)))

