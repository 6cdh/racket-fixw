#lang racket

;; A field-info is a (vector iref iset eref eset)
;; where
;;   iref, iset, eref, and eset are projections to be applied
;;     on internal and external access and mutation.

;; make-field-info creates a new field-info for a field.
;; The caller gives the class and relative position (in the
;; new object struct layer), and this function fills
;; in the projections.
(define (make-field-info cls rpos)
  (let ([field-ref (make-struct-field-accessor (class-field-ref cls) rpos)]
        [field-set! (make-struct-field-mutator (class-field-set! cls) rpos)])
    (vector field-ref field-set! field-ref field-set!)))

(define (field-info-extend-internal fi ppos pneg neg-party)
  (let* ([old-ref (unsafe-vector-ref fi 0)]
         [old-set! (unsafe-vector-ref fi 1)])
    (vector (λ (o) (ppos (old-ref o) neg-party))
            (λ (o v) (old-set! o (pneg v neg-party)))
            (unsafe-vector-ref fi 2)
            (unsafe-vector-ref fi 3))))

(define (field-info-extend-external fi ppos pneg neg-party)
  (let* ([old-ref (unsafe-vector-ref fi 2)]
         [old-set! (unsafe-vector-ref fi 3)])
    (vector (unsafe-vector-ref fi 0)
            (unsafe-vector-ref fi 1)
            (λ (o) (ppos (old-ref o) neg-party))
            (λ (o v) (old-set! o (pneg v neg-party))))))

(define (field-info-internal-ref  fi) (unsafe-vector-ref fi 0))
(define (field-info-internal-set! fi) (unsafe-vector-ref fi 1))
(define (field-info-external-ref  fi) (unsafe-vector-ref fi 2))
(define (field-info-external-set! fi) (unsafe-vector-ref fi 3))

;;--------------------------------------------------------------------
;;  class macros
;;--------------------------------------------------------------------
