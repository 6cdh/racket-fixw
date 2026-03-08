#lang racket/base

;; This module defines a lexer for Racket code.
;; It reads from an input port and produces a sequence of tokens.
;; Each token is represented as a `Token` struct with `text` and `type` fields.

;; This lexer is a wrapper around the `racket-lexer` from the `syntax-color` library,
;; normalizing its output into a smaller set of token types for use in the formatter and parser.

(provide (struct-out Token)
         read-tokens)

(require racket/list
         racket/match
         racket/port
         racket/string
         syntax-color/racket-lexer)

(struct Token
  (text type)
  #:transparent)

(define (lexer in)
  (define-values (text type _paren start end) (racket-lexer in))
  (cond [(eof-object? text) eof]
        [else (list text type start end)]))

(define (vector-prefix-error? text)
  (regexp-match-exact? #px"#[fF][lx][0-9]*" text))

(define (case-sensitivity-prefix? text)
  (regexp-match-exact? #px"#[cC][iIsS]" text))

(define (graph-definition-prefix? text)
  (regexp-match-exact? #px"#[0-9]{1,8}=" text))

(define (graph-reference? text)
  (regexp-match-exact? #px"#[0-9]{1,8}#" text))

(define (next-source-char bytes-code end)
  (and (<= end (bytes-length bytes-code))
       (bytes->string/utf-8
         (subbytes bytes-code (sub1 end) end))))

(define (string-count str char)
  (for/sum ([c str]
            #:when (char=? c char))
    1))

;; Normalized token types produced by read-tokens:
;;   newline            => "\n" "\r\n"
;;   open-parenthesis   => "(" "[" "{"
;;   close-parenthesis  => ")" "]" "}"
;;   open-list-literal  => "#(" "#[" "#{" "#hash(" "#s(" "#fl(" "#fx("
;;   comment            => ";; x" "#| x |#" "#! x" "#!/x"
;;   sexp-comment       => "#;"
;;   quote              => "'" "`" "#'" "#,"
;;   string             => "\"x\"" "#<<EOF"
;;   keyword            => "#:name"
;;   symbol             => "name" "."
;;   prefix             => "#&" "#0="
;;   case-sensitivity-prefix => "#ci" "#cs"
;;   constant           => "1" "#t" "#\\a" "#0#"
;;   lang               => "#lang racket" "#!/usr/bin/env racket"
;;   other              => fallback for uncategorized `other` lexer tokens
;;   disable            => any token inside a `fixw off` region
;;   error              => lexer fallback for unsupported or malformed input

(define (read-tokens in)
  (define bytes-code (port->bytes in))
  (define lexer-in (open-input-bytes bytes-code))
  (define on? #t)
  (define file-newline "\n")

  (define (disable-token token)
    (Token (Token-text token) 'disable))

  (define (add-tokens tokens token-or-tokens)
    (cond
      [(null? token-or-tokens) tokens]
      [(Token? token-or-tokens)
       (cons (if on?
                 token-or-tokens
                 (disable-token token-or-tokens))
             tokens)]
      [else
       (define adjusted-tokens
         (if on?
             token-or-tokens
             (map disable-token token-or-tokens)))
       (append adjusted-tokens tokens)]))

  (define tokens
    (let loop ([tokens '()])
      (define tok (lexer lexer-in))
      (cond
        [(eof-object? tok) tokens]
        [else
         (define token-or-tokens
           (match tok
             [(list spaces 'white-space _ ...)
              (cond [(not on?) (Token spaces 'disable)]
                    [else
                     (let ([newlines (string-count spaces #\newline)]
                           [returns (string-count spaces #\return)])
                       (when (> returns 0)
                         (set! file-newline "\r\n"))
                       (if (= newlines 0)
                           '()
                           (make-list newlines (Token file-newline 'newline))))])]

             [(list opar 'parenthesis _ ...)
              #:when (string-contains? "([{" opar)
              (Token opar 'open-parenthesis)]

             [(list cpar 'parenthesis _ ...)
              #:when (string-contains? ")]}" cpar)
              (Token cpar 'close-parenthesis)]

             [(list restpar 'parenthesis _ ...)
              (Token restpar 'open-list-literal)]

             [(list text 'error _start end)
              #:when (vector-prefix-error? text)
              (define next-char (next-source-char bytes-code end))
              (cond [(and next-char
                          (string-contains? "([{" next-char))
                     (lexer lexer-in)
                     (Token (string-append text next-char) 'open-list-literal)]
                    [else
                     (Token text 'error)])]

             [(list _ 'comment start end _ ...)
              (define content
                (bytes->string/utf-8
                  (subbytes bytes-code (sub1 start) (sub1 end))))
              (cond [(string-contains? content "(fixw on)") (set! on? #t)]
                    [(string-contains? content "(fixw off)") (set! on? #f)])
              (when (string-contains? content "\r")
                (set! file-newline "\r\n"))
              (when on?
                (set! content (string-trim content)))
              (Token content 'comment)]

             [(list sexp-cmt 'sexp-comment _ ...)
              (Token sexp-cmt 'sexp-comment)]

             [(list sym 'constant _ ...)
              #:when (ormap (lambda (candidate) (string=? candidate sym))
                            '("'" "`" "#'" "#`"))
              (Token sym 'quote)]

             [(list sym 'other _ ...)
              #:when (ormap (lambda (candidate) (string=? candidate sym))
                            '("," ",@" "#," "#,@"))
              (Token sym 'quote)]

             [(list str 'string _ ...)
              (Token str 'string)]

             [(list text 'hash-colon-keyword _ ...)
              (Token text 'keyword)]

             [(list text 'symbol _ ...)
              (Token text 'symbol)]

             [(list text 'other _ ...)
              #:when (string=? text ".")
              (Token text 'symbol)]

             [(list text 'constant _ ...)
              #:when (string=? text "#&")
              (Token text 'prefix)]

             [(list text 'other _ ...)
              #:when (case-sensitivity-prefix? text)
              (Token text 'case-sensitivity-prefix)]

             [(list text 'other _ ...)
              #:when (graph-definition-prefix? text)
              (Token text 'prefix)]

             [(list text 'other _ ...)
              #:when (graph-reference? text)
              (Token text 'constant)]

             [(list text 'constant _ ...)
              (Token text 'constant)]

             [(list text 'error _ ...)
              (Token text 'error)]

             [(list text 'other _ ...)
              #:when (or (string-prefix? text "#lang")
                         (string-prefix? text "#!"))
              (Token text 'lang)]

             [(list text 'other _ ...)
              (Token text 'other)]

             [err
              (error "unknown token" err)]))

         (loop (add-tokens tokens token-or-tokens))])))
  (values file-newline (reverse tokens)))
