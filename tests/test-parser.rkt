#lang racket/base

(module+ test
  (require rackunit
           "../private/lexer.rkt"
           "../private/parser.rkt")

  (define (parse-string str)
    (define-values (_file-newline tokens)
      (read-tokens (open-input-string str)))
    (parse-tokens tokens))

  (define (node->datum node)
    (cond [(Token? node)
           `(atom ,(Token-type node) ,(Token-text node))]
          [(AstPrefixed? node)
           `(prefixed ,(node->datum (AstPrefixed-prefix node))
                      ,(map node->datum (AstPrefixed-trivia node))
                      ,(and (AstPrefixed-datum node)
                            (node->datum (AstPrefixed-datum node))))]
          [(AstList? node)
           `(list ,(Token-text (AstList-opener node))
                  ,(map node->datum (AstList-elements node))
                  ,(and (AstList-closer node)
                        (Token-text (AstList-closer node))))]))

  (check-equal?
    (map node->datum (parse-string "(a (b c))"))
    '((list "("
            ((atom symbol "a")
             (list "(" ((atom symbol "b") (atom symbol "c")) ")"))
            ")")))

  (check-equal?
    (map node->datum (parse-string "(a (b c)"))
    '((list "("
            ((atom symbol "a")
             (list "(" ((atom symbol "b") (atom symbol "c")) ")"))
            #f)))

  (check-equal?
    (map node->datum (parse-string "a)"))
    '((atom symbol "a")
      (atom close-parenthesis ")")))

  (check-equal?
    (map node->datum (parse-string "#0=(foo)"))
    '((prefixed (atom prefix "#0=")
                ()
                (list "(" ((atom symbol "foo")) ")"))))

  (check-equal?
    (map node->datum (parse-string "#ci\n(foo)"))
    '((atom case-sensitivity-prefix "#ci")
      (atom newline "\n")
      (list "(" ((atom symbol "foo")) ")")))

  (check-equal?
    (map node->datum (parse-string "#;''(a)"))
    '((prefixed (atom sexp-comment "#;")
                ()
                (prefixed (atom quote "'")
                          ()
                          (prefixed (atom quote "'")
                                    ()
                                    (list "(" ((atom symbol "a")) ")"))))))

  (check-equal?
    (map node->datum (parse-string "#;\n(a)\nb"))
    '((prefixed (atom sexp-comment "#;")
                ((atom newline "\n"))
                (list "(" ((atom symbol "a")) ")"))
      (atom newline "\n")
      (atom symbol "b")))

  (check-equal?
    (map node->datum (parse-string "'#;x y"))
    '((prefixed (atom quote "'")
                ((prefixed (atom sexp-comment "#;")
                           ()
                           (atom symbol "x")))
                (atom symbol "y"))))

  (check-equal?
    (map node->datum (parse-string "#& #;x y"))
    '((prefixed (atom prefix "#&")
                ((prefixed (atom sexp-comment "#;")
                           ()
                           (atom symbol "x")))
                (atom symbol "y"))))

  (check-equal?
    (map node->datum (parse-string "#0= #;x y"))
    '((prefixed (atom prefix "#0=")
                ((prefixed (atom sexp-comment "#;")
                           ()
                           (atom symbol "x")))
                (atom symbol "y"))))

  (check-equal?
    (map node->datum (parse-string "` #;x y"))
    '((prefixed (atom quote "`")
                ((prefixed (atom sexp-comment "#;")
                           ()
                           (atom symbol "x")))
                (atom symbol "y"))))

  (check-equal?
    (map node->datum (parse-string "#; #;x y"))
    '((prefixed (atom sexp-comment "#;")
                ((prefixed (atom sexp-comment "#;")
                           ()
                           (atom symbol "x")))
                (atom symbol "y")))))
