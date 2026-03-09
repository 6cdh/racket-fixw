#lang racket/base

(module+ test
  (require rackunit
           "../fixw.rkt")

  (define (format-string str [rules #f])
    (fixw (open-input-string str) rules))

  (check-equal?
    (format-string "(f\nx")
    "(f\n  x"
    "Unclosed lists still indent relative to the opening form")

  (check-equal?
    (format-string "(f))")
    "(f))"
    "Stray closers remain in the output stream")

  (check-equal?
    (format-string "#fl(1\n2)")
    "#fl(1\n    2)"
    "Flvector prefixes stay attached to list literals")

  (check-equal?
    (format-string "#ci (foo)")
    "#ci (foo)"
    "Case-sensitivity prefixes do not collapse onto the following datum")

  (check-equal?
    (format-string "#0= (foo) #0# bar")
    "#0=(foo) #0# bar"
    "Graph definition prefixes stay attached while graph references remain atoms")

  (check-equal?
    (format-string "#;\n(foo)")
    "#;\n(foo)"
    "S-expression comments keep a newline between the prefix and datum when present")

  (check-equal?
    (format-string "#;''(a)")
    "#; ''(a)"
    "Nested prefixed data stays attached under an s-expression comment")

  (check-equal?
    (format-string "'#;x y")
    "'#; x y"
    "S-expression comment nodes count as trivia between a prefix and its datum"))
