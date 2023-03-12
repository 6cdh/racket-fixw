#lang info
(define collection "fixw")
(define deps '("base" "syntax-color"))
(define build-deps '("scribble-lib" "racket-doc" "rackunit-lib"))
(define scribblings '(("scribblings/fixw.scrbl" ())))
(define pkg-desc "a Racket formatter that only fixes whitespaces")
;; https://semver.org/
(define version "0.1")
(define pkg-authors '(6cdh))
(define license '(Apache-2.0 OR MIT))

(define raco-commands
  '(("fixw" fixw/raco "fix whitespaces use fixw" 1)))

