#lang racket

(define (main)

  (cond [(= 1 1) 1]
        [(= 2 2) (define var 3)
                 var]
        [else 3])

  (cond
    [(= 1 1) 1]
    [(= 2 2) 2]
    [else 3])

  (let ([a 0]
        [b 1]
        [c
         (+ 1 2)])
    (+ a b c))

  #[v1 v2
    v3 v4]
  (1 2
   3 4)

  #hasheq((k1 . v1) (k2 . v2)
          (k3 . v3) (k4 . v4))

  '(a b c)
  `(a b c ,(* 1 2))

  ;; (fixw off)

  (1 2
     3 4)

  ;; (fixw on)
  )

