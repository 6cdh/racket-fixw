# Racket fixw

A Racket formatter that add/remove some whitespaces but respects newline.

## :battery: Status

Under development

## :printer: Example

before

```racket
#lang racket

(define(fib n )
(if (<= n 1)
1
(+ (fib  (- n 1))
(fib (- n 2)) )))
```

after

```racket
#lang racket

(define (fib n)
  (if (<= n 1)
      1
      (+ (fib (- n 1))
         (fib (- n 2)))))

```

## :airplane: Performance

* [x] format a 5k lines file in 150ms on a 6 years old laptop

The biggest Racket file [class-internal.rkt](https://github.com/racket/racket/blob/9b202f565d85cebdf8b5bb91d013eb0ecf06cba6/racket/collects/racket/private/class-internal.rkt) in [racket/racket](https://github.com/racket/racket) repo has almost 5k lines, so I think it's fast enough.

## :sparkles: Features

* [x] fix indent
* [x] respect newline
* [x] works for unbalanced code
* [x] remove trailing spaces
* [x] force only one space between two tokens unless one of them is parenthesis
* [x] force only one empty line at the end of the file
* [x] raco integration
* [ ] read scmindent compatible configuration file
* [ ] skip form that following a specified comment
* [ ] support range formatting
* [ ] support on type formatting

## :rocket: Run

```shell
# install
raco pkg install
# show help
raco fixw -h
# read from stdin and output formatted text to stdout
raco fixw
# format current directory recursively
raco fixw .
```
