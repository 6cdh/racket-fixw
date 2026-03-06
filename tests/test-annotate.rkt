#lang racket

(module+ test
  (require rackunit
           "../fixw.rkt")

  (define (format-string str [rules #f])
    (fixw (open-input-string str) rules #:annotate? #t))

  ;; Annotate mode
  (check-equal?
    (format-string "(f arg1\n   arg2)")
    "(f arg1\n   arg2) ;/f"
    "Annotated close parens stay with the current line when possible")

  (check-equal?
    (format-string "(f)\n(g)")
    "(f) ;/f\n(g) ;/g"
    "Top-level forms keep inline close-paren annotations")

  (check-equal?
    (format-string "(f (g x))")
    "(f (g x) ;/g\n   ) ;/f"
    "Nested forms break only after an annotated close paren when needed")

  (check-equal?
    (format-string "(f))")
    "(f) ;/f\n) ;/unmatched"
    "Unmatched close parens are still annotated"))

