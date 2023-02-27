#lang racket/base

(module+ test
  (require "../fixw.rkt"
           rackunit)

  (define original
    #<<END
(1)
(2)
(3)
(4)
(5)
END
    )
  (let ([formatted (fixw/lines (open-input-string original)
                               #f)])
    (check-equal? formatted '("(1)" "(2)" "(3)" "(4)" "(5)")))

  (let ([formatted (fixw/lines (open-input-string original)
                               #f
                               1)])
    (check-equal? formatted '("(2)" "(3)" "(4)" "(5)")))

  (let ([formatted (fixw/lines (open-input-string original)
                               #f
                               2
                               4)])
    (check-equal? formatted '("(3)" "(4)")))
  )

