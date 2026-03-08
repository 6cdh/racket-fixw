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
              #:trailing-newline? [trailing-newline? #f]
              #:annotate? [annotate? #f])
  (define-values (file-newline formatted)
    (format-port in rules
                 #:interactive? interactive?
                 #:annotate? annotate?))
  (cond [trailing-newline?
         (string-append (trim-trailing-newlines formatted file-newline)
                        file-newline
                        file-newline)]
        [else
         formatted]))

(define (fixw/lines in rules [start-line 0] [end-line #f] #:interactive? [interactive? #f])
  (define text (port->string in))
  (define lines (port->lines (open-input-string text)))
  (define-values (_file-newline formatted)
    (format-port (open-input-string text) rules #:interactive? interactive?))
  (define formatted-lines (port->lines (open-input-string formatted)))
  (when (not end-line)
    (set! end-line (length lines)))
  (drop (take formatted-lines end-line) start-line))


