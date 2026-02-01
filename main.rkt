#lang racket/base

(provide fixw
         fixw/trailing-newline
         fixw/lines)

(require "fixw.rkt")

(module+ main
  (require "cli.rkt")
  (cli-main))

