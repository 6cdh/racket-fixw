#lang racket/base

(module+ test
  (require "../cli.rkt"
           rackunit
           racket/file
           racket/port)

  (define test-dir
    (make-temporary-file "fixw-cli-~a" 'directory))

  (define (run-cli args input)
    (parameterize ([current-directory test-dir]
                   [current-command-line-arguments (list->vector args)]
                   [current-input-port (open-input-string input)])
      (with-output-to-string cli-main)))

  (dynamic-wind
    void
    (lambda ()
      (check-equal?
        (run-cli '("--ensure-newline-eof") "(a)")
        "(a)\n"
        "--ensure-newline-eof adds one trailing newline if missing")

      (check-equal?
        (run-cli '("--ensure-newline-eof") "(a)\n\n")
        "(a)\n\n"
        "--ensure-newline-eof preserves multiple trailing newlines")

      (check-equal?
        (run-cli '("--newline" "--ensure-newline-eof") "(a)")
        "(a)\n\n"
        "--newline takes priority over --ensure-newline-eof"))
    (lambda ()
      (delete-directory/files test-dir))))
