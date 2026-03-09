#lang racket/base

(require racket/contract
         "private/api.rkt")

(define rules/c (or/c #f (hash/c string? natural-number/c)))

(provide
  (contract-out
    [fixw
     (->* (input-port? rules/c)
          (#:interactive? boolean?
         #:trailing-newline? boolean?)
          string?)]
    [fixw/lines
     (->* (input-port? rules/c)
          (exact-nonnegative-integer?
            (or/c exact-nonnegative-integer? #f)
            #:interactive? boolean?)
          (listof string?))]))
