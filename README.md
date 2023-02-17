# Racket fixw

A Racket formatter that add/remove some spaces but respect newline.

## Status

Under development

## Example

before

```racket
#lang racket

(define(fib n )
(if (<= n 1)
0
(+ (fib  (- n 1))
(fib (- n 2)) )))
```

after

```racket
#lang racket

(define (fib n)
  (if (<= n 1)
      0
      (+ (fib (- n 1))
         (fib (- n 2)))))

```

## Features

* [x] fix indent
* [x] respect newline
* [x] remove trailing spaces
* [x] force only one space between two tokens unless one of them is parenthesis
* [x] force only one empty line at the end of the file
* [ ] raco integration
* [ ] read scmindent compatible configuration file
* [ ] skip form that following a specified comment
