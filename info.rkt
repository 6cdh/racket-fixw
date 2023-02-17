#lang info
(define collection "fixw")
(define deps '("base" "syntax-color"))
(define build-deps '("scribble-lib" "racket-doc" "rackunit-lib"))
(define scribblings '(("scribblings/fixw.scrbl" ())))
(define pkg-desc "a Racket formatter that only fixes whitespaces")
;; https://semver.org/
(define version "0.1.0")
(define pkg-authors '(6cdh))
(define license '(MIT))

(define raco-commands
  '(("fixw" fixw/raco "fix whitespaces use fixw" #f)))
