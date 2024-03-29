#lang racket/base

(provide fixw
         fixw/lines)

(require syntax-color/racket-lexer
         racket/match
         racket/list
         racket/string
         racket/port
         racket/hash
         "rules.rkt")

(define (lexer in)
  (define-values (text type paren start end) (racket-lexer in))
  (cond [(eof-object? text) eof]
        [else (list text type start end)]))

(struct Token
  (text type))

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
   [last-indent #:mutable]))

(define (sf-inc-arg! sf)
  (set-StackFrame-arg! sf (add1 (StackFrame-arg sf))))

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
  (define on? #t)
  (define file-newline "\n")
  (for ([tok (in-port lexer (open-input-bytes bytes-code))])
    (define new-toks
      (match tok
        ;; newline
        [(list spaces 'white-space _ ...)
         (cond [(not on?) (list (Token spaces 'disable))]
               [else
                (let ([newlines (string-count spaces #\newline)]
                      [returns (string-count spaces #\return)])
                  (when (> returns 0)
                    (set! file-newline "\r\n"))
                  (if (= newlines 0)
                      '()
                      (make-list newlines (Token file-newline 'newline))))])]
        
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
        [(list _ 'comment start end _ ...)
         (define content (bytes->string/utf-8
                           (subbytes bytes-code (sub1 start) (sub1 end))))
         (cond [(string-contains? content "(fixw on)") (set! on? #t)]
               [(string-contains? content "(fixw off)") (set! on? #f)])
         (when (string-contains? content "\r")
           (set! file-newline "\r\n"))
         ;; remove trailing `\r` in comment for `\r\n` file
         (when on?
           (set! content (string-trim content)))
         (list (Token content 'comment))]
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
        
        [(list text 'other _ ...)
         (list (Token text 'other))]
        
        [err (error "unknown token" err)]))
    (set! tokens (append (if on?
                             new-toks
                             (map (λ (tok) (Token (Token-text tok) 'disable))
                                  new-toks))
                         tokens)))
  (values file-newline (reverse tokens)))

(define (process-trailing-newlines tokens file-newline)
  (define reversed (reverse tokens))
  (reverse (append (list file-newline file-newline)
                   (or (memf (λ (tok) (not (string=? tok file-newline)))
                             reversed)
                       '()))))

(define (fixw/tokens in user-rules interactive?)
  (define builtin-rules (add-rule rule/racket))
  (define rules (hash-union builtin-rules (or user-rules (hash))
                            #:combine/key (λ (k builtin user) user)))

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
  
  (define-values (file-newline tokens) (read-tokens in))
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
               [('disable _) 0] ; disabled
               [(_ 'disable) 0] ; disabled
               [(_ _) 1]))
           
           (define current-char-pos (+ char-pos spaces-before))
           (define next-char-pos
             (match tok-t
               ['newline 0]
               [_ (+ current-char-pos tok-len)]))
           
           (define new-stack
             (match* [prev-tok-t tok-t]
               [(_ (or 'newline 'comment 'sexp-comment 'disable))
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
  
  (values file-newline (rec 'open-parenthesis tokens 0 '())))

(define (fixw in rules #:interactive? [interactive? #f])
  (define-values (file-newline formatted) (fixw/tokens in rules interactive?))
  (string-append* (process-trailing-newlines formatted file-newline)))

(define (fixw/lines in rules [start-line 0] [end-line #f] #:interactive? [interactive? #f])
  (define-values (file-newline toks) (fixw/tokens in rules interactive?))
  (define lines-lst
    (for/fold ([res '(())]
               #:result (reverse (map reverse res)))
              ([tok toks])
      (cond [(string=? tok file-newline)
             (cons '() res)]
            [else
             (cons (cons tok (car res))
                   (cdr res))])))
  (define lines
    (for/list ([line-lst lines-lst])
      (string-append* line-lst)))
  (when (not end-line)
    (set! end-line (length lines)))
  (drop (take lines end-line) start-line))

