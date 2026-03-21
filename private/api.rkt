#lang racket/base

(provide fixw
         fixw/lines)

(require racket/list
         racket/port
         racket/string
         "formatter.rkt")

(define (trim-trailing-newlines text file-newline)
  (string-trim text file-newline #:left? #f #:repeat? #t))

(define (fixw in rules
              #:interactive? [interactive? #f]
              #:trailing-newline? [trailing-newline? #f])
  (define-values (file-newline formatted)
    (format-port in rules
                 #:interactive? interactive?))
  (cond [trailing-newline?
         (string-append (trim-trailing-newlines formatted file-newline)
                        file-newline
                        file-newline)]
        [else
         formatted]))

(define (fixw/lines in rules [start-line 0] [end-line #f] #:interactive? [interactive? #f])
  (define-values (_file-newline formatted)
    (format-port in rules #:interactive? interactive?))

  (define formatted-port (open-input-string formatted))
  (for/list ([line (in-lines formatted-port)]
             [ln (in-naturals 0)]
             #:when (and (<= start-line ln)
                         (or (not end-line) (< ln end-line))))
    line))


