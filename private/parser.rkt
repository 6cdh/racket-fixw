#lang racket/base

;; This module defines a parser for Racket code.
;; It takes a sequence of tokens (produced by the lexer) and constructs an AST.
;; AST is either a token (defined in "lexer.rkt"), an `AstList`, or an
;; `AstPrefixed` node that keeps one datum-prefix token, any intervening trivia
;; nodes, and the following datum grouped together.

(provide (struct-out AstList)
         (struct-out AstPrefixed)
         parse-port
         parse-tokens)

(require racket/match
         "lexer.rkt")

(struct AstList
  (opener elements closer)
  #:transparent)

(struct AstPrefixed
  (prefix trivia datum)
  #:transparent)

(define (open-token? token)
  (memq (Token-type token)
        '(open-parenthesis open-list-literal)))

(define (prefix-token? token)
  (memq (Token-type token)
        '(quote prefix sexp-comment)))

(define (prefix-trivia-token? token)
  (memq (Token-type token)
        '(newline comment)))

(define (sexp-comment-token? token)
  (eq? (Token-type token) 'sexp-comment))

(define (parse-port in)
  (define-values (file-newline tokens) (read-tokens in))
  (values file-newline (parse-tokens tokens)))

(define (parse-tokens tokens)
  (define-values (nodes _rest _closed?)
    (parse-sequence tokens (lambda _ #f)))
  nodes)

(define (parse-node token tokens)
  (cond [(open-token? token)
         (parse-list token tokens)]
        [(prefix-token? token)
         (parse-prefixed token tokens)]
        [else
         (values token tokens)]))

(define (parse-prefixed prefix-token tokens)
  (define-values (trivia rest)
    (collect-prefix-trivia tokens))
  (match rest
    ['()
     (values (AstPrefixed prefix-token trivia #f) '())]
    [(cons token more)
     (define-values (datum remaining)
       (parse-node token more))
     (values (AstPrefixed prefix-token trivia datum) remaining)]))

(define (collect-prefix-trivia tokens)
  (let loop ([rest tokens]
             [trivia '()])
    (match rest
      [(cons token more)
       #:when (prefix-trivia-token? token)
       (loop more (cons token trivia))]
      [(cons token more)
       #:when (sexp-comment-token? token)
       (define-values (comment-node remaining)
         (parse-prefixed token more))
       (loop remaining (cons comment-node trivia))]
      [_
       (values (reverse trivia) rest)])))

(define (close-parenthesis-token? token)
  (eq? (Token-type token) 'close-parenthesis))

(define (parse-sequence tokens stop?)
  (let loop ([rest tokens]
             [nodes '()])
    (match rest
      ['()
       (values (reverse nodes) '() #f)]
      [(cons token more)
       (cond [(stop? token)
              (values (reverse nodes) rest #t)]
             [else
              (define-values (node remaining)
                (parse-node token more))
              (loop remaining (cons node nodes))])])))

(define (parse-list opener tokens)
  (define-values (elements rest closed?)
    (parse-sequence tokens close-parenthesis-token?))
  (if closed?
      (values (AstList opener elements (car rest))
              (cdr rest))
      (values (AstList opener elements #f)
              rest)))
