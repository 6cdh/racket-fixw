#lang racket/base

(provide fixw
         fixw/lines
         fixw/range
         fixw/on-type)

(require syntax-color/racket-lexer
         racket/match
         racket/list
         racket/string
         racket/port
         "rules.rkt")

(define (lexer in)
  (define-values (text type paren start end) (racket-lexer in))
  (cond [(eof-object? text) eof]
        [else (list text type start end)]))

(struct Token
  (text type) #:transparent)

(define (string-count str char)
  (for/sum ([c str]
            #:when (char=? c char))
    1))

(struct StackFrame
  (;; the first element of a form, or the opening token
   ;; for example, it's `fn` in `(fn arg ...)`,
   ;; it's `#hash(` in `#hash((key . val))`
   ;; it's `(` in `()`
   ;; it's `(` in `((fn ...))`
   [head #:mutable]
   ;; the number of current atom in current list, 0-indexed
   ;; for example, in `(fn arg1 arg2)`, `fn` is 0, `arg`1 is 1, ...
   [arg #:mutable]
   ;; the opening paren token
   paren
   ;; char position of the last char of the opening parenthesis at it's line
   par-pos
   ;; char position of the first atom at the previous line in the current list if exists
   ;; or the char position of the second element of the current list if exists
   ;; otherwise, it's -1
   [last-indent #:mutable])
  #:transparent)

(define (sf-inc-arg! sf)
  (set-StackFrame-arg! sf (add1 (StackFrame-arg sf))))

(define *newline* "\n")

;; return a list of tokens
;; returned tokens:
;;   * 'newline - "\n" or "\r\n"
;;   * 'open-parenthesis - `([{`
;;   * 'close-parenthesis - `}])`
;;   * 'open-list-literal - `#(`, `#[`, `#{`, `#hash(`, ...
;;   * 'constant - boolean, number, character literal
;;   * 'quote - one of `'`, `,`, `#'`, `#\``, `\``, `,@`, `#,`, `#,@`
;;   * 'string - string, regex, herestring
;;   * 'comment - line comment that starts with `;`, block comment, or "#!" stuff
;;   * 'sexp-comment - sexp comment "#;"
;;   * 'keyword - keyword, `#:keyword`
;;   * 'symbol - identifier
;;   * 'dot - `.`
;;   * 'prefix - `#&`
;;   * 'lang - `#lang ...` or `#!...`
;;   * 'error - otherwise
(define (read-tokens in)
  (define bytes-code (port->bytes in))
  (define tokens '())
  (for ([tok (in-port lexer (open-input-bytes bytes-code))])
    (define new-toks
      (match tok
        ;; newline
        [(list spaces 'white-space _ ...)
         (let ([newlines (string-count spaces #\newline)])
           (if (= newlines 0)
               '()
               (make-list newlines (Token *newline* 'newline))))]

        ;; parenthesis
        [(list opar 'parenthesis _ ...)
         #:when (string-contains? "([{" opar)
         (list (Token opar 'open-parenthesis))]
        [(list cpar 'parenthesis _ ...)
         #:when (string-contains? ")]}" cpar)
         (list (Token cpar 'close-parenthesis))]
        [(list restpar 'parenthesis _ ...)
         (list (Token restpar 'open-list-literal))]

        ;; comment
        [(list cmt 'comment start end _ ...)
         (list (Token (bytes->string/utf-8 (subbytes bytes-code (sub1 start) (sub1 end)))
                      'comment))]
        [(list sexp-cmt 'sexp-comment _ ...)
         (list (Token sexp-cmt 'sexp-comment))]

        ;; quote
        [(list sym 'constant _ ...)
         #:when (ormap (λ (s) (string=? s sym))
                       '("'" "`" "#'" "#`"))
         (list (Token sym 'quote))]
        [(list sym 'other _ ...)
         #:when (ormap (λ (s) (string=? s sym))
                       '("," ",@" "#," "#,@"))
         (list (Token sym 'quote))]

        ;; string
        [(list str 'string _ ...)
         (list (Token str 'string))]

        ;; keyword
        [(list text 'hash-colon-keyword _ ...)
         (list (Token text 'keyword))]

        ;; symbol
        [(list text 'symbol _ ...)
         (list (Token text 'symbol))]

        ;; dot
        [(list text 'other _ ...)
         #:when (string=? text ".")
         (list (Token text 'dot))]

        ;; prefix
        [(list text 'constant _ ...)
         #:when (string=? text "#&")
         (list (Token text 'prefix))]

        ;; constant
        [(list text 'constant _ ...)
         (list (Token text 'constant))]

        ;; error
        [(list text 'error _ ...)
         (list (Token text 'error))]

        [(list text 'other _ ...)
         #:when (or (string-prefix? text "#lang")
                    (string-prefix? text "#!"))
         (list (Token text 'lang))]

        [err (error "unknown token" err)]))
    (set! tokens (append new-toks tokens)))
  (reverse tokens))

(define (fixw/tokens in interactive?)
  (define rules (add-rule rule/racket))

  (define (indenter stack)
    (define (hit-rule? rules head arg)
      (and (hash-has-key? rules (Token-text head))
           (>= (- arg 1) (hash-ref rules (Token-text head)))))

    (define (list-literal? head paren)
      (or (memq (Token-type head) '(constant string keyword prefix))
          (memq (Token-type paren) '(open-list-literal))))

    (define (guess-list-literal? paren)
      (string-suffix? (Token-text paren) "["))

    (define (head-is-list? head)
      (memq (Token-type head) '(open-parenthesis open-list-literal)))

    (match stack
      ['() 0]
      [(list (StackFrame _ 0 _ par-pos _) _ ...)
       (+ 1 par-pos)]
      [(list (StackFrame head 1 paren par-pos _) _ ...)
       (cond [(list-literal? head paren) (+ 1 par-pos)]
             [(guess-list-literal? paren) (+ 1 par-pos)]
             [(head-is-list? head) (+ 1 par-pos)]
             [else (+ 2 par-pos)])]
      [(list (StackFrame head arg paren par-pos last-indent) _ ...)
       (cond [(list-literal? head paren) (+ 1 par-pos)]
             [(hit-rule? rules head arg) (+ 2 par-pos)]
             [else last-indent])]))

  (define (process-trailing-newlines tokens)
    (define reversed (reverse tokens))
    (reverse (append (list "\n" "\n")
                     (or (memf (λ (tok) (not (string=? tok "\n")))
                               reversed)
                         '()))))

  (define (update-stack! stack prev-tok-t tok current-char-pos)
    (when (and (not (null? stack))
               (not (memq prev-tok-t '(quote prefix))))
      (define sf (car stack))
      (when (and (= 0 (StackFrame-arg sf))
                 (eq? 'open-parenthesis
                      (Token-type (StackFrame-head sf))))
        (set-StackFrame-head! sf tok))
      (when (or (eq? prev-tok-t 'newline)
                (= 1 (StackFrame-arg sf)))
        (set-StackFrame-last-indent! sf current-char-pos))
      (sf-inc-arg! sf)))

  (define tokens (read-tokens in))
  (define (rec prev-tok-t tokens char-pos stack)
    (cond [(null? tokens) '()]
          [else
           (define tok (car tokens))
           (define tok-t (Token-type tok))
           (define tok-text (Token-text tok))
           (define tok-len (string-length tok-text))

           (define spaces-before
             (match* [prev-tok-t tok-t]
               [('newline 'newline) (if interactive? (indenter stack) 0)]
               [(_ 'newline) 0] ; no trailing spaces
               [('newline _) (indenter stack)]
               [('open-parenthesis _) 0]
               [('open-list-literal _) 0]
               [('quote _) 0]
               [('prefix _) 0]
               [(_ 'close-parenthesis) 0]
               [(_ _) 1]))

           (define current-char-pos (+ char-pos spaces-before))
           (define next-char-pos
             (match tok-t
               ['newline 0]
               [_ (+ current-char-pos tok-len)]))

           (define new-stack
             (match* [prev-tok-t tok-t]
               [(_ (or 'newline 'comment 'sexp-comment))
                stack]
               [(_ 'close-parenthesis)
                (if (null? stack)
                    '()
                    (cdr stack))]
               [(_ (or 'open-parenthesis 'open-list-literal))
                (update-stack! stack prev-tok-t tok current-char-pos)
                (cons (StackFrame tok 0 tok (sub1 next-char-pos) -1) stack)]
               [(_ _)
                (update-stack! stack prev-tok-t tok current-char-pos)
                stack]))

           (append (make-list spaces-before " ")
                   (list tok-text)
                   (rec tok-t (cdr tokens) next-char-pos new-stack))]))

  (define result (rec 'open-parenthesis tokens 0 '()))
  (process-trailing-newlines result))

(define (fixw in)
  (string-append* (fixw/tokens in #f)))

(define (fixw/lines in #:interactive? [interactive? #f])
  (define toks (fixw/tokens in interactive?))
  (define lines-lst
    (let ([res '(())])
      (for ([tok toks])
        (cond [(string=? tok *newline*) (set! res (list-set res 0
                                                            (cons tok (car res))))
                                        (set! res (cons '() res))]
              [else (set! res (list-set res 0
                                        (cons tok (car res))))]))))
  (for/list ([line-lst lines-lst])
    (string-append* line-lst)))

(define (fixw/range in start-line end-line #:interactive? [interactive? #f])
  (define lines (fixw/lines in #:interactive? interactive?))
  (let loop ([i 0]
             [lines lines])
    (cond [(= i end-line) '()]
          [(< i start-line) (loop (add1 i) (cdr lines))]
          [(null? lines) (cons "" (loop (add1 i) lines))]
          [else (cons (car lines) (loop (add1 i) (cdr lines)))])))

(define (fixw/on-type in line)
  (fixw/range in 0 (add1 line) #:interactive? #t))

