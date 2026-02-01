#lang racket/base

(module+ test
  (require "../fixw.rkt"
           rackunit
           racket/port)

  (define (format-string str [rules #f])
    (fixw (open-input-string str) rules))

  ;; Nested lists
  (check-equal?
    (format-string "((a\n  b)\n c)")
    "((a\n   b)\n c)"
    "Nested lists alignment")

  ;; Vector literals
  (check-equal?
    (format-string "#(1\n  2\n  3)")
    "#(1\n  2\n  3)"
    "Vector literal alignment")

  ;; Quoted lists
  (check-equal?
    (format-string "'(1\n  2)")
    "'(1\n  2)"
    "Quoted list alignment")

  ;; Quasiquoted lists
  (check-equal?
    (format-string "`(1\n  ,a)")
    "`(1\n  ,a)"
    "Quasiquoted list alignment")

  ;; S-expression comments
  (check-equal?
    (format-string "#;(a\n   b)\nc")
    "#; (a\n     b)\nc"
    "S-expression comment alignment")

  ;; Reader conditionals (if supported by lexer)
  ;; The lexer might treat #+ as symbol or specific token.
  ;; Based on fixw.rkt, # is prefix or part of other tokens.

  ;; Box literals
  (check-equal?
    (format-string "#&(\n   val)")
    "#&(\n   val)"
    "Box literal alignment")

  ;; Hash tables
  (check-equal?
    (format-string "#hash((a . 1)\n      (b . 2))")
    "#hash((a . 1)\n      (b . 2))"
    "Hash table alignment")
  )

