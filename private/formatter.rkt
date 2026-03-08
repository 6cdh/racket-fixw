#lang racket/base

(provide format-port)

;; The formatter walks the parser AST recursively and emits text directly.
;; `Frame` and `FormatState` keep the local indentation context that used to be
;; maintained by the old global stack-based engine.

(require racket/hash
         racket/match
         racket/string
         "lexer.rkt"
         "parser.rkt"
         "rules.rkt")

;; A frame records indentation anchors for one surrounding list.
;; head: first layout-significant token seen in the list, or #f.
;; arg: number of layout-significant items emitted in the list so far.
;; opener: opening delimiter token for the list.
;; opener-pos: zero-based column where the opener was emitted,
;;             if the opener contains multiple chars, this is the column of the last char.
;; last-indent: indentation column to reuse for later aligned arguments.
(struct Frame
  (head arg opener opener-pos last-indent)
  #:transparent)

;; rules: merged indentation rule table.
;; file-newline: newline sequence to emit for inserted line breaks,
;;               is CRLF for Windows and LF for Unix.
;; interactive?: whether REPL-style newline handling is enabled.
;; annotate?: whether close-paren annotations should be emitted.
(struct FormatConfig
  (rules file-newline interactive? annotate?)
  #:transparent)

;; Output state tracks the previous token type, current column, and active frame.
;; prev-type: type of the most recently emitted token.
;; col: current zero-based output column.
;; frame: active indentation frame, or #f at top level.
(struct FormatState
  (prev-type col frame)
  #:transparent)

;; Annotate mode only needs to know which visible token comes next.
;; token: next visible token, or #f if there is none.
(struct AnnotateLookahead
  (token)
  #:transparent)

;; Merge built-in and user indentation rules into one lookup table.
(define (build-rules user-rules)
  (define builtin-rules (add-rule rule/racket))
  (hash-union builtin-rules
              (or user-rules (hash))
              #:combine/key (lambda (_key _builtin user) user)))

(define (hit-rule? rules head arg)
  (and head
       (hash-has-key? rules (Token-text head))
       (> arg (hash-ref rules (Token-text head)))))

(define (list-literal? head opener)
  (or (and head
           (memq (Token-type head) '(constant string keyword prefix)))
      (memq (Token-type opener) '(open-list-literal))))

(define (guess-list-literal? token)
  (and token
       (string-suffix? (Token-text token) "[")))

(define (head-is-list? head)
  (and head
       (memq (Token-type head) '(open-parenthesis open-list-literal))))

;; Compute the indentation for the next token from the current list frame.
(define (indentation frame config)
  (define rules (FormatConfig-rules config))
  (cond [(not frame) 0]
        [(= (Frame-arg frame) 0)
         (+ 1 (Frame-opener-pos frame))]
        [(= (Frame-arg frame) 1)
         (define head (Frame-head frame))
         (define opener (Frame-opener frame))
         (define opener-pos (Frame-opener-pos frame))
         (cond [(list-literal? head opener) (+ 1 opener-pos)]
               [(guess-list-literal? opener) (+ 1 opener-pos)]
               [(head-is-list? head) (+ 1 opener-pos)]
               [else (+ 2 opener-pos)])]
        [else
         (define head (Frame-head frame))
         (define opener (Frame-opener frame))
         (define opener-pos (Frame-opener-pos frame))
         (cond [(list-literal? head opener) (+ 1 opener-pos)]
               [(hit-rule? rules head (Frame-arg frame)) (+ 2 opener-pos)]
               [(guess-list-literal? opener) (+ 1 opener-pos)]
               [(guess-list-literal? head) (+ 1 opener-pos)]
               [else (Frame-last-indent frame)])]))

(define (state-with-frame state frame)
  (FormatState (FormatState-prev-type state)
               (FormatState-col state)
               frame))

;; Advance the active frame after emitting a token that participates in layout.
(define (update-frame frame prev-type token current-col)
  (cond [(or (not frame) (memq prev-type '(quote prefix)))
         frame]
        [else
         (define current-head (Frame-head frame))
         (define new-head
           (if (= 0 (Frame-arg frame))
               token
               current-head))
         (define new-last-indent
           (if (or (eq? prev-type 'newline)
                   (= 1 (Frame-arg frame)))
               current-col
               (Frame-last-indent frame)))
         (Frame new-head
                (add1 (Frame-arg frame))
                (Frame-opener frame)
                (Frame-opener-pos frame)
                new-last-indent)]))

(define (spaces-before token state config)
  (define token-type (Token-type token))
  (define token-text (Token-text token))
  (define prev-type (FormatState-prev-type state))
  (define frame (FormatState-frame state))
  (define interactive? (FormatConfig-interactive? config))
  (match* [prev-type token-type]
    [('newline 'newline) (if interactive? (indentation frame config) 0)]
    [('newline 'string)
     #:when (string-prefix? token-text "#<<")
     0]
    [(_ 'newline) 0]
    [('newline _) (indentation frame config)]
    [('open-parenthesis _) 0]
    [('open-list-literal _) 0]
    [('quote _) 0]
    [('prefix _) 0]
    [(_ 'close-parenthesis) 0]
    [('disable _) 0]
    [(_ 'disable) 0]
    [(_ _) 1]))

(define (close-paren-annotation frame)
  (define annotation-name
    (cond [(and frame (Frame-head frame))
           (Token-text (Frame-head frame))]
          [frame
           (Token-text (Frame-opener frame))]
          [else "unmatched"]))
  (string-append " ;/" annotation-name))

;; Emit one token, including annotate-mode close-paren comments when enabled.
(define (emit-token out token lookahead state config)
  (define token-type (Token-type token))
  (define token-text (Token-text token))
  (define next-token (AnnotateLookahead-token lookahead))
  (define spaces
    (spaces-before token state config))
  (define current-col (+ (FormatState-col state) spaces))
  (unless (zero? spaces)
    (write-string (make-string spaces #\space) out))
  (write-string token-text out)

  (define next-col
    (if (eq? token-type 'newline)
        0
        (+ current-col (string-length token-text))))

  (define annotated-close?
    (and (FormatConfig-annotate? config)
         (eq? token-type 'close-parenthesis)))
  (define insert-newline?
    (and annotated-close?
         next-token
         (not (eq? 'newline (Token-type next-token)))))

  (when annotated-close?
    (write-string (close-paren-annotation (FormatState-frame state)) out))
  (when insert-newline?
    (write-string (FormatConfig-file-newline config) out))

  (values (FormatState (if insert-newline? 'newline token-type)
                       (if insert-newline? 0 next-col)
                       (FormatState-frame state))
          current-col))

(define (node-first-token node)
  (match node
    [(? Token? token) token]
    [(AstPrefixed prefix _ _)
     prefix]
    [(AstList opener _ _) opener]))

;; Emit one atomic token and update the current frame when it affects layout.
(define (format-token out token lookahead state config)
  (define-values (next-state current-col)
    (emit-token out token lookahead state config))
  (define next-frame
    (if (memq (Token-type token)
              '(newline comment sexp-comment disable close-parenthesis))
        (FormatState-frame state)
        (update-frame (FormatState-frame state)
                      (FormatState-prev-type state)
                      token
                      current-col)))
  (state-with-frame next-state next-frame))

;; Format one list with a child frame for its contents, then restore the parent.
(define (format-list out opener elements closer lookahead state config)
  (define-values (after-open-state opener-col)
    (emit-token out opener (AnnotateLookahead #f) state config))
  (define parent-frame
    (update-frame (FormatState-frame state)
                  (FormatState-prev-type state)
                  opener
                  opener-col))
  (define child-frame
    ;; (sub1 ...) because this should be the last column of the opener.
    (Frame #f 0 opener (sub1 (FormatState-col after-open-state)) -1))
  (define child-lookahead
    (AnnotateLookahead
      (or closer (AnnotateLookahead-token lookahead))))
  (define after-elements-state
    (format-sequence out elements child-lookahead
                     (state-with-frame after-open-state child-frame)
                     config))
  (cond [closer
         (define-values (after-close-state _current-col)
           (emit-token out closer lookahead after-elements-state config))
         (state-with-frame after-close-state parent-frame)]
        [else
         (state-with-frame after-elements-state parent-frame)]))

(define (format-prefixed out prefix trivia datum lookahead state config)
  (define following-nodes
    (if datum
        (append trivia (list datum))
        trivia))
  (define prefix-lookahead
    (AnnotateLookahead
      (if (null? following-nodes)
          (AnnotateLookahead-token lookahead)
          (node-first-token (car following-nodes)))))
  (define after-prefix-state
    (format-token out prefix prefix-lookahead state config))
  (if (null? following-nodes)
      after-prefix-state
      (format-sequence out following-nodes lookahead after-prefix-state config)))

;; Dispatch formatting by node shape while preserving annotate lookahead.
(define (format-node out node lookahead state config)
  (match node
    [(? Token? token)
     (format-token out token lookahead state config)]
    [(AstPrefixed prefix trivia datum)
     (format-prefixed out prefix trivia datum lookahead state config)]
    [(AstList opener elements closer)
     (format-list out opener elements closer lookahead state config)]))

;; Walk sibling nodes while carrying the next visible token for annotations.
(define (format-sequence out nodes lookahead state config)
  (let loop ([remaining nodes]
             [state state])
    (match remaining
      ['()
       state]
      [(cons node rest)
       (define next-lookahead
         (match rest
           [(cons next-node _)
            (AnnotateLookahead (node-first-token next-node))]
           ['()
            lookahead]))
       (define next-state
         (format-node out node next-lookahead state config))
       (loop rest next-state)])))

;; Parse once, then format the resulting AST with the initial top-level state.
(define (format-port in user-rules
                     #:interactive? [interactive? #f]
                     #:annotate? [annotate? #f])
  (define rules (build-rules user-rules))
  (define-values (file-newline nodes) (parse-port in))
  (define out (open-output-string))
  (define config
    (FormatConfig rules file-newline interactive? annotate?))
  (format-sequence out
                   nodes
                   (AnnotateLookahead #f)
                   (FormatState 'open-parenthesis 0 #f)
                   config)
  (values file-newline (get-output-string out)))
