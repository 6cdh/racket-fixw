#lang racket/base

(provide rule/racket
         add-rule)

(require racket/list)

(define (add-rule rules)
  (for/hash ([r rules])
    (values (first r) (second r))))

(define rule/racket
  '(("define" 1)
    ("define-syntax" 1)
    ("define-syntaxes" 1)
    ("define-for-syntax" 1)
    ("syntax-case" 2)
    ("syntax-rules" 1)
    ("with-syntax" 1)
    ("syntax/loc" 1)

    ("case" 1)

    ("for/sum" 1)
    ("for/list" 1)
    ("for/fold" 2)
    ("for" 1)

    ("let" 1)
    ("let*" 1)
    ("let-values" 1)
    ("define-values" 1)
    ("when" 1)
    ("unless" 1)
    ("begin" 0)
    ("lambda" 1)
    ("λ" 1)

    ("match" 1)
    ("match*" 1)

    ("struct" 1)))

