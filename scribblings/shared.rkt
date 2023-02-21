;; copy from https://github.com/racket/racket/blob/master/pkgs/racket-doc/scribblings/style/shared.rkt
;; with little changed

; Permission is hereby granted, free of charge, to any
; person obtaining a copy of this software and associated
; documentation files (the "Software"), to deal in the
; Software without restriction, including without
; limitation the rights to use, copy, modify, merge,
; publish, distribute, sublicense, and/or sell copies of
; the Software, and to permit persons to whom the Software
; is furnished to do so, subject to the following
; conditions:

; The above copyright notice and this permission notice
; shall be included in all copies or substantial portions
; of the Software.

; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
; ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
; TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
; PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT
; SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
; CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
; OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
; IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
; DEALINGS IN THE SOFTWARE.

#lang s-exp racket

;; ---------------------------------------------------------------------------------------------------
; things to be shared among all sections of the style guide

(provide (for-label (all-from-out racket))
         (all-from-out scribble/manual))

(provide
  1/2-line
  LINEWIDTH
  eli
  codebox
  compare
  codebox0
  compare0
  column-table
  row-table
  rkt rkt/base rkt/gui xml)

(require (for-label racket)
         scribble/base
         scribble/manual
         scribble/struct
         (only-in scribble/core table-columns table-cells style plain
                  color-property nested-flow)
         scribble/html-properties
         racket/list)

(define eli "eli@barzilay.org")

(define (LINEWIDTH) "102")

;; ---------------------------------------------------------------------------------------------------

(define (1/2-line (n 11)) (t (string-join (map string (make-list n #\-)))))

(define (rkt) (racketmodname racket))
(define (rkt/base) (racketmodname racket/base))
(define (rkt/gui) (racketmodname racket/gui))
(define (xml) (racketmodname xml))


(define stretching-style
  (style #f (list (attributes '([style . "margin-left: 0; margin-right: 0"])))))

(define (stretch d)
  (match d
    [(nested-flow _ content) (nested-flow stretching-style content)]
    [_ d]))

;; compare: two code snippets, in two columns: left is good, right is bad
;; The styling is slightly broken.
;; Consider using compare0 instead;
;; compare is provided only for backward compatibility
(define (compare stuff1 stuff2)
  (define stuff (list (list stuff1) (list stuff2)))
  (table (sty 2 500) (apply map (compose make-flow list) stuff)))

;; compare0: two code snippets, in two columns: left is before right is after
(define (compare0 #:left [left "before"] #:right [right "after"]
                  stuff1 stuff2)
  (define stuff (list (list (stretch (filebox (tt left) stuff1)))
                      (list (stretch (filebox (tt right) stuff2)))))
  (table (sty 2 500) (apply map (compose make-flow list) stuff)))

;; codebox: a code snippet in a box. The styling is slightly broken.
;; Consider using codebox0 instead;
;; codebox is provided only for backward compatibility
(define (codebox stuff1)
  (define stuff (list (list stuff1)))
  (table (sty 1 700) (apply map (compose make-flow list) stuff)))

;; codebox0: a code snippet in a box.
(define (codebox0 stuff1 #:label [label "left"])
  (define stuff (list (list (stretch (filebox (tt label) stuff1)))))
  (table (sty 1 700) (apply map (compose make-flow list) stuff)))

(define-syntax (column-table stx)
  (syntax-case stx (col)
    [(_ (col x ...) ...)
     #`(begin
	 (define stuff (list (list (paragraph plain (format "~a" 'x)) ...) ...))
	 (table (sty (length stuff) 200)
	        (apply map (compose make-flow list) stuff)))]))

(define-syntax (row-table stx)
  (syntax-case stx (row)
    [(row-table (row titles ...) (row char kind example) ...)
     #`(row-table/proc
        (list
         (list (paragraph plain (format "~a" 'titles)) ...)
         (list (paragraph plain (litchar (~a 'char)))
               (paragraph plain (format "~a" 'kind))
               (paragraph plain (litchar (~a 'example)))) ...))]))

(define (row-table/proc stuff)
  (table (sty (length (car stuff)) 200 #:valign? #f)
         stuff))

(define (sty columns width #:valign? [valign? #t])
  (define space
    (style #f `(,(attributes `((width . ,(format "~a" width)) (align . "left")
                                                              ,@(if valign?
                                                                    (list '(valign . "top"))
                                                                    (list)))))))
  ;; -- in --
  (style #f
    (list
     (attributes '((border . "1") (cellpadding . "1")))
     (table-columns (make-list columns space)))))
