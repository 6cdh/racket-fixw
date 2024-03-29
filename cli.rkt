#lang racket/base

(provide run/user)

(require "fixw.rkt"
         racket/port
         racket/path
         racket/match
         racket/contract
         racket/hash)

(define (run/user path-strings)
  (cond [(null? path-strings)
         (define output
           (fixw (current-input-port) (read-config/dir (current-directory))))
         (display output)]
        [else
         (for ([p path-strings])
           (cond [(not (path-string? p)) (error (format "~v is not a path." p))]
                 [(not (file-or-directory-type p #f)) (error (format "path ~v does not exist." p))]
                 [(file? p) (format-file p (read-config/dir p))]
                 [(dir? p) (format-dir p (read-config/dir p))]
                 [else (error "unknown error for path: ~v" p)]))]))

(define/contract (file? path)
  (-> (or/c path? path-string?) boolean?)

  (file-exists? path))

(define/contract (dir? path)
  (-> (or/c path? path-string?) boolean?)

  (directory-exists? path))

(define rules? (hash/c string? natural-number/c))

(define/contract (format-file path rules)
  (-> (or/c path? path-string?) (or/c rules? #f) void?)

  (call-with-input-file path
    (λ (infile)
      (define original (port->string infile))
      (define formatted (fixw (open-input-string original) rules))
      (when (not (string=? formatted original))
        (with-output-to-file path
          #:exists 'replace
          (λ () (display formatted)))))))

(define/contract (format-dir path rules)
  (-> (or/c path? path-string?) (or/c rules? #f) void?)

  (let loop ([path path]
             [rules rules])
    (for ([p (directory-list path #:build? #t)])
      (cond [(not (file-or-directory-type p #f))
             (error (format "path ~v does not exist." p))]
            [(and (file? p) (equal? #".rkt" (path-get-extension p)))
             (format-file p rules)]
            [(dir? p)
             (when (not (string=? ".git"
                                  (some-system-path->string
                                    (file-name-from-path p))))
               (loop p (rules-merge rules (read-config p))))]
            [else (void)]))))

(define (rules-merge old-rules new-rules)
  (-> (or rules? #f) (or rules? #f) rules?)

  (hash-union (or old-rules (hash)) (or new-rules (hash))
              #:combine/key (λ (k old new) new)))

;; recursively read config start at `path` towards root directory
(define/contract (read-config/dir dir-path)
  (-> (or/c path? path-string?) (or/c hash? #f))

  (let loop ([dir-path (simple-form-path dir-path)]
             [rules (hash)])
    (define upper-rules (read-config dir-path))
    (define-values (base _name _must-be-dir?) (split-path dir-path))
    (cond [(not base) (rules-merge upper-rules rules)]
          [else (loop base (rules-merge upper-rules rules))])))

(define/contract (read-config dir-path)
  (-> (or/c path? path-string?) (or/c hash? #f))

  (define conf-file-name (build-path (simple-form-path dir-path) ".lispwords"))
  (cond [(file-exists? conf-file-name) (parse-config conf-file-name)]
        [else #f]))

(define/contract (parse-config file-path)
  (-> complete-path? (or/c rules? #f))

  (call-with-input-file file-path
    (λ (in)
      (for/fold ([rules (hash)])
                ([r (in-port read in)])
        (match r
          [(list sym num)
           #:when (and (symbol? sym) (exact-nonnegative-integer? num))
           (hash-set rules (symbol->string sym) num)]
          [(list num sym)
           #:when (and (symbol? sym) (exact-nonnegative-integer? num))
           (hash-set rules (symbol->string sym) num)]
          [(list sym-lst num)
           #:when (and (list? sym-lst) (andmap symbol? sym-lst) (exact-nonnegative-integer? num))
           (for/fold ([rules rules])
                     ([sym sym-lst])
             (hash-set rules (symbol->string sym) num))]
          [(list num sym-lst ...)
           #:when (and (list? sym-lst) (andmap symbol? sym-lst) (exact-nonnegative-integer? num))
           (for/fold ([rules rules])
                     ([sym sym-lst])
             (hash-set rules (symbol->string sym) num))]
          [text (error (format "error rule ~v\n in path ~v" text file-path))])))))
