#lang racket/base

(module+ test
  (require "../cli.rkt"
           rackunit
           racket/file
           racket/path)

  (define test-dir (build-path (current-directory) "tests" "tmp-config-test"))

  (define (setup)
    (when (directory-exists? test-dir)
      (delete-directory/files test-dir))
    (make-directory* (build-path test-dir "subdir")))

  (define (teardown)
    (when (directory-exists? test-dir)
      (delete-directory/files test-dir)))

  (dynamic-wind
    setup
    (λ ()
      ;; Write root config
      (with-output-to-file (build-path test-dir ".lispwords")
        (λ ()
          (write '(my-macro 1))
          (display "\n")
          (write '(shared-macro 0))))

      ;; Write subdir config
      (with-output-to-file (build-path test-dir "subdir" ".lispwords")
        (λ ()
          (write '(my-other-macro 2))
          (display "\n")
          (write '(shared-macro 1))))

      ;; Test read-config (non-recursive)
      (let ([rules (read-config test-dir)])
        (check-equal? (hash-ref rules "my-macro") 1)
        (check-equal? (hash-ref rules "shared-macro") 0))

      ;; Test read-config/rec (recursive) from subdir
      (let ([rules (read-config/rec (build-path test-dir "subdir"))])
        (check-equal? (hash-ref rules "my-macro") 1 "Inherited from parent")
        (check-equal? (hash-ref rules "my-other-macro") 2 "Defined in child")
        (check-equal? (hash-ref rules "shared-macro") 1 "Child overrides parent"))
      )
    teardown)
  )

