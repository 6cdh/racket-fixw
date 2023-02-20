# Racket fixw

A Racket formatter that add/remove some whitespaces but respects newline.

## :battery: Status

It should work as expected, except some rules for macros and special forms are missing.

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

* [x] format a 5k lines file in 100ms on a 6 years old laptop

The biggest Racket file [class-internal.rkt](https://github.com/racket/racket/blob/9b202f565d85cebdf8b5bb91d013eb0ecf06cba6/racket/collects/racket/private/class-internal.rkt) in [racket/racket](https://github.com/racket/racket) repo has almost 5k lines, so I think it's fast enough.

## :sparkles: Features

* [x] fix indent
* [x] respect newline
* [x] works for unbalanced code
* [x] remove trailing spaces
* [x] convert crlf to lf
* [x] force only one space between two tokens with several exceptions
* [x] force only one empty line at the end of the file
* [x] raco integration
* [x] read [scmindent](https://github.com/ds26gte/scmindent) compatible configuration file
* [x] skip code that surrounded by special comments
* [x] support range formatting

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

## :thinking: FAQ

* How `fixw` indent?

  See [indent.md](./indent.md) for details.

* How to turn off formatter temporarily?

  Use `(fixw off)` in comment to turn off it, `(fixw on)` to enable it again. For example,

  ```racket
  ;; (fixw off)
  ;; your code here
  ;; (fixw on)
  ```

* How `fixw` read config file?

  For a `.rkt` file, `fixw` will read `.lispwords` at its same directory, if not found, then its parent directory, ...
  Buitin rules are always used, user config can override the builtin rules.
  
## See also
  
* [fmt](https://github.com/sorawee/fmt) - a Racket formatter that calculate optimal layout
* [scmindent](https://github.com/ds26gte/scmindent) - a general lisp indenter
