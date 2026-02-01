# Racket fixw

A Racket formatter that adjusts whitespace but respects newlines.

## :battery: Status

It should work as expected, except some builtin rules for macros and special forms are missing.

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

- [x] format a 5k lines file in 100ms on a 6 years old laptop

The biggest Racket file [class-internal.rkt](https://github.com/racket/racket/blob/9b202f565d85cebdf8b5bb91d013eb0ecf06cba6/racket/collects/racket/private/class-internal.rkt) in [racket/racket](https://github.com/racket/racket) repo has almost 5k lines, so I think it's fast enough.

## :sparkles: Features

- [x] Fixes indentation
- [x] Respects existing newlines
- [x] Works on incorrect code
- [x] Removes trailing spaces
- [x] Enforces single spaces between tokens (with several exceptions)
- [x] Raco integration
- [x] Reads [scmindent](https://github.com/ds26gte/scmindent)-compatible configuration files
- [x] Skips code surrounded by special comments
- [x] Supports range formatting

Planned Features:

- [ ] Configurable trailing newline
- [ ] Customizable formatting system (macro-like)
  - [ ] Sorting `require` clauses
  - [ ] Keyword arguments and default arguments support

## :bookmark_tabs: Todo

- [ ] Refactor
  - [ ] Isolate lexer workarounds and special escape comment processing
  - [ ] Simplify core logic

## :rocket: Run

```shell
# install
raco pkg install fixw
# show help
raco fixw -h
# read from stdin and print formatted text to stdout
raco fixw
# format all Racket files in current directory recursively
raco fixw .
```

## :thinking: Documentation

See the [online documentation](https://docs.racket-lang.org/fixw/index.html).

## :paperclips: See also

- [fmt](https://github.com/sorawee/fmt) - A Racket formatter that calculates optimal layout.
- [scmindent](https://github.com/ds26gte/scmindent) - A general Lisp indenter.
