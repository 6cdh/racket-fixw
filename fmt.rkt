#lang racket/base

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
   ;; for example, in `(fn arg1 arg2)`, `(` is 0, `fn` is 1, `arg`1 is 2, ...
   [arg #:mutable]
   ;; char position of the opening parenthesis at it's line
   par-indent
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

(define (fmt in)
  (define rules (add-rule rule/racket))

  (define (indenter stack)
    (cond [(null? stack) 0]
          [(= 0 (StackFrame-arg (car stack)))
           (+ 1 (StackFrame-par-indent (car stack)))]
          [(memq (Token-type (StackFrame-head (car stack)))
                 '(constant string keyword prefix))
           (+ 1 (StackFrame-par-indent (car stack)))]
          [(and (hash-has-key? rules (Token-text (StackFrame-head (car stack))))
                (>= (- (StackFrame-arg (car stack)) 1)
                    (hash-ref rules (Token-text (StackFrame-head (car stack))))))
           (+ 2 (StackFrame-par-indent (car stack)))]
          [(= -1 (StackFrame-last-indent (car stack)))
           (+ 1 (StackFrame-par-indent (car stack)))]
          [else
           (StackFrame-last-indent (car stack))]))

  (define (process-trailing-newlines tokens)
    (define reversed (reverse tokens))
    (reverse (cons "\n"
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
               [('newline 'newline) 0] ; TODO: indent at interactive mode
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
                (cons (StackFrame tok 0 current-char-pos -1) stack)]
               [(_ _)
                (update-stack! stack prev-tok-t tok current-char-pos)
                stack]))

           (append (make-list spaces-before " ")
                   (list tok-text)
                   (rec tok-t (cdr tokens) next-char-pos new-stack))]))

  (define result (rec 'open-parenthesis tokens 0 '()))
  (string-append* (process-trailing-newlines result)))

(define file "large.rkt")
(define out "out.rkt")
(define formatted (time (fmt (open-input-file file))))
(with-output-to-file out
  #:exists 'replace
  (λ () (displayln formatted)))
