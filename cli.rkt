#lang racket/base

(provide run/user)

(require "fixw.rkt"
         racket/port
         racket/path
         racket/match
         racket/contract)

(define (run/user path-strings)
  (cond [(null? path-strings) (define output (fixw (current-input-port)
                                                   (read-config/rec (current-directory))))
                              (display output)]
        [else
         (for ([p path-strings])
           (cond [(not (path-string? p)) (error (format "~v is not a path." p))]
                 [(not (file-or-directory-type p #f)) (error (format "path ~v does not exist." p))]
                 [(file? p) (fmt-file p (read-config/rec p))]
                 [(dir? p) (fmt-dir p (read-config/rec p))]
                 [else (error "unknown error for path: ~v" p)]))]))

(define/contract (run/internal paths rules)
  (-> (listof path?) (or/c hash? #f) void?)

  (for ([p paths])
    (cond [(not (file-or-directory-type p #f)) (error (format "path ~v does not exist." p))]
          [(and (file? p)
                (equal? #".rkt" (path-get-extension p)))
           (fmt-file p rules)]
          [(dir? p) (when (not (string=? ".git"
                                         (some-system-path->string
                                           (file-name-from-path p))))
                      (fmt-dir p rules))]
          [else (void)])))

(define/contract (file? path)
  (-> (or/c path? path-string?) boolean?)

  (file-exists? path))

(define/contract (dir? path)
  (-> (or/c path? path-string?) boolean?)

  (directory-exists? path))

(define/contract (fmt-file path rules)
  (-> (or/c path? path-string?) (or/c hash? #f) void?)

  (call-with-input-file path
    (λ (infile)
      (define original (port->string infile))
      (define formatted (fixw (open-input-string original) rules))
      (when (not (string=? formatted original))
        (with-output-to-file path
          #:exists 'replace
          (λ () (display formatted)))))))

(define/contract (fmt-dir path rules)
  (-> (or/c path? path-string?) (or/c hash? #f) void?)

  (define new-rules (read-config path))
  (run/internal (directory-list path #:build? #t)
                (or rules new-rules)))

(define/contract (read-config/rec path)
  (-> (or/c path? path-string?) (or/c hash? #f))

  (let loop ([p (simple-form-path path)])
    (define-values (base name must-be-dir?) (split-path p))
    (cond [(not base) #f]
          [else
           (define rules (read-config base))
           (cond [(not rules) (loop base)]
                 [else rules])])))

(define/contract (read-config path)
  (-> (or/c path? path-string?) (or/c hash? #f))

  (define conf-file-name (build-path (path-only (simple-form-path path)) ".lispwords"))
  (cond [(file-exists? conf-file-name) (parse-config conf-file-name)]
        [else #f]))

(define/contract (parse-config path)
  (-> complete-path? (or/c (hash/c string? integer?) #f))

  (call-with-input-file path
    (λ (in)
      (define rules (make-hash))
      (for ([r (in-port read in)])
        (match r
          [(list sym num)
           #:when (and (symbol? sym) (integer? num))
           (hash-set! rules (symbol->string sym) num)]
          [(list num sym)
           #:when (and (symbol? sym) (integer? num))
           (hash-set! rules (symbol->string sym) num)]
          [(list sym-lst num)
           #:when (and (list? sym-lst) (andmap symbol? sym-lst) (integer? num))
           (for ([sym sym-lst])
             (hash-set! rules (symbol->string sym) num))]
          [(list num sym-lst ...)
           #:when (and (list? sym-lst) (andmap symbol? sym-lst) (integer? num))
           (for ([sym sym-lst])
             (hash-set! rules (symbol->string sym) num))]
          [text (error (format "error rule ~v\n in path ~v" text path))]))
      rules)))

