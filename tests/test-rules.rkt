#lang racket/base

(module+ test
  (require "../fixw.rkt"
           rackunit)

  (define (format-string str [rules #f])
    (fixw (open-input-string str) rules))

  ;; Basic function call alignment
  (check-equal?
    (format-string "(f arg1\n   arg2)")
    "(f arg1\n   arg2)"
    "Standard function alignment")

  ;; Define rule (1 special arg)
  (check-equal?
    (format-string "(define (f)\n  body)")
    "(define (f)\n  body)"
    "Define indentation")

  ;; Custom rule with 1 special arg
  (define rules-1 (hash "my-macro" 1))
  (check-equal?
    (format-string "(my-macro arg1\n  body)" rules-1)
    "(my-macro arg1\n  body)"
    "Custom rule with 1 special arg")

  ;; Without rule, it aligns
  (check-equal?
    (format-string "(my-macro arg1\n          body)")
    "(my-macro arg1\n          body)"
    "Without custom rule")

  ;; Custom rule with 0 special args
  (define rules-0 (hash "my-form" 0))
  (check-equal?
    (format-string "(my-form\n  arg1)" rules-0)
    "(my-form\n  arg1)"
    "Custom rule with 0 special args")

  ;; Test fixw trailing newline behavior (should preserve existing)
  (check-equal?
    (format-string "(a)")
    "(a)"
    "fixw: No trailing newline preserved")

  (check-equal?
    (format-string "(a)\n")
    "(a)\n"
    "fixw: Trailing newline preserved")

  (check-equal?
    (format-string "(a)\n\n")
    "(a)\n\n"
    "fixw: Multiple trailing newlines preserved")

  ;; Test trailing newline handling for fixw/trailing-newline
  (define (format-string/trailing str [rules #f])
    (fixw/trailing-newline (open-input-string str) rules))

  (check-equal?
    (format-string/trailing "(a)")
    "(a)\n\n"
    "Adds trailing newline (empty line) if missing")

  (check-equal?
    (format-string/trailing "(a)\n")
    "(a)\n\n"
    "Ensures empty line at end")

  (check-equal?
    (format-string/trailing "(a)\n\n")
    "(a)\n\n"
    "Preserves empty line")

  ;; Test square brackets behavior
  (check-equal?
    (format-string "[a\n b]")
    "[a\n b]"
    "Square brackets alignment")

  ;; Test let binding alignment
  ;; (let ([a 1]
  ;;       [b 2])
  ;;   body)
  (check-equal?
    (format-string "(let ([a 1]\n      [b 2])\n  body)")
    "(let ([a 1]\n      [b 2])\n  body)"
    "Let binding alignment")

  ;; Test function application split across lines (no rule)
  ;; (f
  ;;  arg)
  ;; Current behavior indents 2 spaces from paren
  (check-equal?
    (format-string "(f\n arg)")
    "(f\n  arg)"
    "Function application split lines")
  )

