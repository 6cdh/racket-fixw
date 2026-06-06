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
;; interactive?: whether REPL-style newline handling is enabled.
(struct FormatConfig
  (rules interactive?)
  #:transparent)

;; Output state tracks the previous token type, current column, and active frame.
;; prev-type: type of the most recently emitted token.
;; col: current zero-based output column.
;; frame: active indentation frame, or #f at top level.
(struct FormatState
  (prev-type col frame)
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
       (let ([r (hash-ref rules (Token-text head))])
         (and (exact-nonnegative-integer? r) (> arg r)))))

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

;; Emit one token and return the updated formatter state.
(define (emit-token out token state config)
  (define token-type (Token-type token))
  (define token-text (Token-text token))
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

  (values (FormatState token-type
                       next-col
                       (FormatState-frame state))
          current-col))

;; Emit one atomic token and update the current frame when it affects layout.
(define (format-token out token state config)
  (define-values (next-state current-col)
    (emit-token out token state config))
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
(define (format-list out opener elements closer state config)
  (define-values (after-open-state opener-col)
    (emit-token out opener state config))
  (define parent-frame
    (update-frame (FormatState-frame state)
                  (FormatState-prev-type state)
                  opener
                  opener-col))
  (define child-frame
    ;; (sub1 ...) because this should be the last column of the opener.
    (Frame #f 0 opener (sub1 (FormatState-col after-open-state)) -1))
  (define after-elements-state
    (format-sequence out elements
                     (state-with-frame after-open-state child-frame)
                     config))
  (cond [closer
         (define-values (after-close-state _current-col)
           (emit-token out closer after-elements-state config))
         (state-with-frame after-close-state parent-frame)]
        [else
         (state-with-frame after-elements-state parent-frame)]))

(define (format-prefixed out prefix trivia datum state config)
  (define following-nodes
    (if datum
        (append trivia (list datum))
        trivia))
  (define after-prefix-state
    (format-token out prefix state config))
  (if (null? following-nodes)
      after-prefix-state
      (format-sequence out following-nodes after-prefix-state config)))

;; Dispatch formatting by node shape.
(define (format-node out node state config)
  (match node
    [(AstList opener elements closer)
     (format-list out opener elements closer state config)]
    [(? Token? token)
     (format-token out token state config)]
    [(AstPrefixed prefix trivia datum)
     (format-prefixed out prefix trivia datum state config)]))

;; Walk sibling nodes in order.
(define (format-sequence out nodes state config)
  (let loop ([remaining nodes]
             [state state])
    (match remaining
      [(cons node rest)
       (loop rest (format-node out node state config))]
      ['()
       state])))

;; Parse once, then format the resulting AST with the initial top-level state.
(define (format-port in user-rules #:interactive? [interactive? #f])
  (define rules (build-rules user-rules))
  (define-values (file-newline nodes) (parse-port in))
  (define out (open-output-string))
  (define config
    (FormatConfig rules interactive?))
  (format-sequence out
                   nodes
                   (FormatState 'open-parenthesis 0 #f)
                   config)
  (values file-newline (get-output-string out)))
