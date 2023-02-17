#lang racket

(define(fib n )
(if (<= n 1)
0
(+ (fib  (- n 1))
(fib (- n 2)) )))
