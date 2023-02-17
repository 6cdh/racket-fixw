#lang racket/base

(provide run)

(require "fixw.rkt"
         racket/port
         racket/path)

(define (run paths)
  (cond [(null? paths) (define output (fixw (current-input-port)))
                       (display output)]
        [else
         (for ([p paths])
           (cond [(not (path-string? p)) (error (format "~v is not a path." p))]
                 [(not (file-or-directory-type p #f)) (error (format "path ~v does not exist." p))]
                 [(file? p) (run-file p)]
                 [(dir? p) (run-dir p)]
                 [else (error "unknown error for path: ~v" p)]))]))

(define (run/rec paths)
  (for ([p paths])
    (cond [(not (path-string? p)) (error (format "~v is not a path." p))]
          [(not (file-or-directory-type p #f)) (error (format "path ~v does not exist." p))]
          [(and (file? p)
                (equal? #".rkt" (path-get-extension p)))
           (run-file p)]
          [(dir? p) (run-dir p)]
          [else (void)])))

(define (file? path)
  (file-exists? path))

(define (dir? path)
  (directory-exists? path))

(define (run-file path)
  (define formatted (fixw (open-input-file path)))
  (define original (port->string (open-input-file path)))
  (when (not (string=? formatted original))
    (with-output-to-file path
      #:exists 'replace
      (λ () (display formatted)))))

(define (run-dir path)
  (run/rec (directory-list path #:build? #t)))

