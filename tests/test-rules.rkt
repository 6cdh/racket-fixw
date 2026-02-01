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

  ;; Test 'begin' (rule 0)
  (check-equal?
    (format-string "(begin\n  expr1\n  expr2)")
    "(begin\n  expr1\n  expr2)"
    "begin indentation (rule 0)")

  ;; Test 'begin' with first arg on new line (should be same)
  (check-equal?
    (format-string "(begin expr1\n  expr2)")
    "(begin expr1\n  expr2)"
    "begin indentation with first arg on same line (rule 0)")

  ;; Test 'syntax-parse' (rule 1)
  (check-equal?
    (format-string "(syntax-parse stx\n  [pat body])")
    "(syntax-parse stx\n  [pat body])"
    "syntax-parse indentation (rule 1)")

  ;; Test 'define-simple-macro' (rule 1)
  (check-equal?
    (format-string "(define-simple-macro (name arg)\n  body)")
    "(define-simple-macro (name arg)\n  body)"
    "define-simple-macro indentation (rule 1)")

  ;; Test 'test-case' (rule 1)
  (check-equal?
    (format-string "(test-case \"name\"\n  (check-equal? 1 1))")
    "(test-case \"name\"\n  (check-equal? 1 1))"
    "test-case indentation (rule 1)")

  ;; Test 'test-begin' (rule 0)
  (check-equal?
    (format-string "(test-begin\n  (check-equal? 1 1))")
    "(test-begin\n  (check-equal? 1 1))"
    "test-begin indentation (rule 0)")

  ;; Test 'match-define' (rule 1)
  (check-equal?
    (format-string "(match-define (list a b)\n  (list 1 2))")
    "(match-define (list a b)\n  (list 1 2))"
    "match-define indentation (rule 1)")

  ;; Test 'mixin' (rule 2)
  (check-equal?
    (format-string "(mixin (i1%)\n       (i2%)\n  (super-new))")
    "(mixin (i1%)\n       (i2%)\n  (super-new))"
    "mixin indentation (rule 2)")

  ;; Test 'trait' (rule 0)
  (check-equal?
    (format-string "(trait (i1%)\n  (define/public (m) 1))")
    "(trait (i1%)\n  (define/public (m) 1))"
    "trait indentation (rule 0)")

  ;; Test 'struct-copy' (rule 2)
  (check-equal?
    (format-string "(struct-copy point p\n  [x 1]\n  [y 2])")
    "(struct-copy point p\n  [x 1]\n  [y 2])"
    "struct-copy indentation (rule 2)")

  ;; Test 'new' (rule 1)
  (check-equal?
    (format-string "(new frame%\n  [label \"Hi\"])")
    "(new frame%\n  [label \"Hi\"])"
    "new indentation (rule 1)")

  ;; Test 'instantiate' (rule 2)
  (check-equal?
    (format-string "(instantiate frame% ()\n  [label \"Hi\"])")
    "(instantiate frame% ()\n  [label \"Hi\"])"
    "instantiate indentation (rule 2)")

  ;; Test 'shift' (rule 1)
  (check-equal?
    (format-string "(shift k\n  (k 1))")
    "(shift k\n  (k 1))"
    "shift indentation (rule 1)")

  ;; Test 'reset' (rule 0)
  (check-equal?
    (format-string "(reset\n  (shift k (k 1)))")
    "(reset\n  (shift k (k 1)))"
    "reset indentation (rule 0)")
  )

