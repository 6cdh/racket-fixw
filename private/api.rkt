#lang racket/base

(provide fixw
         fixw/lines)

(require racket/list
         racket/port
         racket/string
         "formatter.rkt")

(define (trim-trailing-newlines text file-newline)
  (string-trim text file-newline #:left? #f #:repeat? #t))

(define (ensure-trailing-empty-line text file-newline)
  (string-append (trim-trailing-newlines text file-newline)
                 file-newline
                 file-newline))

(define (ensure-newline-at-eof text file-newline)
  (if (string-suffix? text file-newline)
      text
      (string-append text file-newline)))

(define (apply-trailing-newline-policy text file-newline
                                       trailing-newline?
                                       ensure-newline-eof?)
  (cond [trailing-newline?
         (ensure-trailing-empty-line text file-newline)]
        [ensure-newline-eof?
         (ensure-newline-at-eof text file-newline)]
        [else
         text]))

(define (fixw in rules
              #:interactive? [interactive? #f]
              #:trailing-newline? [trailing-newline? #f]
              #:ensure-newline-eof? [ensure-newline-eof? #f])
  (define-values (file-newline formatted)
    (format-port in rules
                 #:interactive? interactive?))
  (apply-trailing-newline-policy formatted
                                 file-newline
                                 trailing-newline?
                                 ensure-newline-eof?))

(define (fixw/lines in rules [start-line 0] [end-line #f] #:interactive? [interactive? #f])
  (define-values (_file-newline formatted)
    (format-port in rules #:interactive? interactive?))

  (define formatted-port (open-input-string formatted))
  (for/list ([line (in-lines formatted-port)]
             [ln (in-naturals 0)]
             #:when (and (<= start-line ln)
                         (or (not end-line) (< ln end-line))))
    line))


