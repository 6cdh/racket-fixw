#lang racket/base

(require racket/contract
         "private/api.rkt"
         "private/rules.rkt")

(define rules-ctc (or/c #f rules?))

(provide
  (contract-out
    [fixw
     (->* (input-port? rules-ctc)
          (#:interactive? boolean?
           #:trailing-newline? boolean?
           #:ensure-newline-eof? boolean?)
          string?)]
    [fixw/lines
     (->* (input-port? rules-ctc)
          (exact-nonnegative-integer?
            (or/c exact-nonnegative-integer? #f)
            #:interactive? boolean?)
          (listof string?))]))
