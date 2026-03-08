#lang racket/base

(module+ test
  (require rackunit
           racket/list
           "../private/lexer.rkt")

  (define (lex str)
    (call-with-values
      (lambda ()
        (read-tokens (open-input-string str)))
      list))

  (define (lex/newline str)
    (define result (lex str))
    (values (car result) (cadr result)))

  (define (token-types tokens)
    (map Token-type tokens))

  (define (token-texts tokens)
    (map Token-text tokens))

  (define (check-lex str expected-types expected-texts)
    (define-values (_file-newline tokens)
      (lex/newline str))
    (check-equal? (token-types tokens) expected-types)
    (check-equal? (token-texts tokens) expected-texts))

  (define-values (file-newline tokens)
    (lex/newline "#lang racket\r\n(1)\r\n"))
  (check-equal? file-newline "\r\n")
  (check-equal? (token-types tokens)
                '(lang newline open-parenthesis constant close-parenthesis newline))
  (check-equal? (token-texts tokens)
                '("#lang racket" "\r\n" "(" "1" ")" "\r\n"))

  (check-lex ". #%app #:kw"
             '(symbol symbol keyword)
             '("." "#%app" "#:kw"))

  (check-lex "; hi\n#| block |#\n#;x\n#! /usr/bin/env racket\n#!/bin/sh\n"
             '(comment newline comment newline sexp-comment symbol newline comment newline comment newline)
             '("; hi" "\n" "#| block |#" "\n" "#;" "x" "\n"
               "#! /usr/bin/env racket" "\n" "#!/bin/sh" "\n"))

  (define-values (_disabled-file-newline disabled-tokens)
    (lex/newline ";; (fixw off)\n(  1   2)\n;; (fixw on)\n(1 2)\n"))
  (check-equal? (token-types disabled-tokens)
                '(disable disable disable disable disable disable disable disable disable comment newline
                          open-parenthesis constant constant close-parenthesis newline))
  (check-equal? (take (token-texts disabled-tokens) 4)
                '(";; (fixw off)" "\n" "(" "  "))

  (check-lex "' ` #' #` , ,@ #, #,@"
             '(quote quote quote quote quote quote quote quote)
             '("'" "`" "#'" "#`" "," ",@" "#," "#,@"))

  (check-lex "\"a\" #\"a\" #rx\"a\" #px\"a\" #rx#\"a\" #px#\"a\""
             '(string string string string string string)
             '("\"a\"" "#\"a\"" "#rx\"a\"" "#px\"a\"" "#rx#\"a\"" "#px#\"a\""))
  (check-lex "#<<EOF\nbody\nEOF\n"
             '(string newline)
             '("#<<EOF\nbody\nEOF" "\n"))

  (check-lex "#t #true #f #false #\\newline #\\u03BB 1"
             '(constant constant constant constant constant constant constant)
             '("#t" "#true" "#f" "#false" "#\\newline" "#\\u03BB" "1"))

  (check-lex "#&(a) #0=(bar) #0# #ci foo #cs bar"
             '(prefix open-parenthesis symbol close-parenthesis
                      prefix open-parenthesis symbol close-parenthesis
                      constant case-sensitivity-prefix symbol case-sensitivity-prefix symbol)
             '("#&" "(" "a" ")"
               "#0=" "(" "bar" ")"
               "#0#" "#ci" "foo" "#cs" "bar"))

  (check-lex "#(a) #[a] #{a} #3(a) #fl(1.0) #fl3(1.0) #fx(1) #fx3(1) #s(x 1) #s[x 1] #s{x 1}"
             '(open-list-literal symbol close-parenthesis
                                 open-list-literal symbol close-parenthesis
                                 open-list-literal symbol close-parenthesis
                                 open-list-literal symbol close-parenthesis
                                 open-list-literal constant close-parenthesis
                                 open-list-literal constant close-parenthesis
                                 open-list-literal constant close-parenthesis
                                 open-list-literal constant close-parenthesis
                                 open-list-literal symbol constant close-parenthesis
                                 open-list-literal symbol constant close-parenthesis
                                 open-list-literal symbol constant close-parenthesis)
             '("#(" "a" ")"
               "#[" "a" "]"
               "#{" "a" "}"
               "#3(" "a" ")"
               "#fl(" "1.0" ")"
               "#fl3(" "1.0" ")"
               "#fx(" "1" ")"
               "#fx3(" "1" ")"
               "#s(" "x" "1" ")"
               "#s[" "x" "1" "]"
               "#s{" "x" "1" "}"))

  (check-lex "#hash((a . 1)) #hasheq((a . 1)) #hasheqv((a . 1)) #hashalw((a . 1))"
             '(open-list-literal open-parenthesis symbol symbol constant close-parenthesis close-parenthesis
                                 open-list-literal open-parenthesis symbol symbol constant close-parenthesis close-parenthesis
                                 open-list-literal open-parenthesis symbol symbol constant close-parenthesis close-parenthesis
                                 open-list-literal open-parenthesis symbol symbol constant close-parenthesis close-parenthesis)
             '("#hash(" "(" "a" "." "1" ")" ")"
               "#hasheq(" "(" "a" "." "1" ")" ")"
               "#hasheqv(" "(" "a" "." "1" ")" ")"
               "#hashalw(" "(" "a" "." "1" ")" ")"))

  (check-lex "#lang racket #!r6rs"
             '(lang lang)
             '("#lang racket" "#!r6rs"))
  (check-lex "#reader racket/base (x)"
             '(error symbol open-parenthesis symbol close-parenthesis)
             '("#reader" "racket/base" "(" "x" ")"))
  (check-lex "#~compiled"
             '(error)
             '("#~compiled")))
