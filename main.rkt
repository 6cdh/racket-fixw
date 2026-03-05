#lang racket/base

(provide fixw
         fixw/lines)

(require "fixw.rkt")

(module+ main
  (require "cli.rkt")
  (cli-main))

