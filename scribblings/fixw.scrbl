#lang scribble/manual
@require[
    scribble/bnf
    scribble/example
    "shared.rkt"
    @for-label[fixw racket/base]]

@title{fixw}
@author{6cdh}

@defmodule[fixw]

A Racket formatter that only fixes whitespace and keeps newlines.

It provides a command line tool and a library.

@section{Examples}

@compare0[
@racketmod0[
racket

(Range #:start (Position #:line 0
#:character 0)
#:end(Position #:line 10
#:character 0) )
]
@racketmod0[
racket

(Range #:start (Position #:line 0
                         #:character 0)
       #:end (Position #:line 10
                       #:character 0))

]
]

@section{@exec{raco fixw}}

@exec{raco fixw} reads text from stdin and outputs formatted code to stdout.

@exec{raco fixw @nonterm{files or dirs} ...} formats @nonterm{files} or @nonterm{dirs} recursively.
For @nonterm{files}, fixw formats them regardless of extension.
For @nonterm{dirs}, fixw formats all @filepath{*.rkt} files recursively.

It accepts the following flags:

@itemlist[
    @item{@Flag{t} --- Use @racket[time] to time the entire formatting process and output the result.}
    @item{@Flag{n} or @DFlag{newline} --- Enforce a trailing empty line (two newlines) at the end of the file.}
  @item{@Flag{a} or @DFlag{annotate} --- Append an annotation such as @tt{) ;/for} after each close parenthesis. If more code would follow on the same line, fixw inserts a newline after the annotation so the comment stays local. Unmatched close parentheses are annotated as @tt{) ;/unmatched}.}
]

@section{API}

@defproc[(fixw [in input-port?]
               [rules (or/c (hash/c string? integer?) #f)]
               [#:interactive? interactive? boolean? #f]
               [#:annotate? annotate? boolean? #f]
               [#:trailing-newline? boolean? #f])
               string?]{
    Reads from @racket[in] using user-defined rules @racket[rules], and returns the formatted string.

    If @racket[interactive?] is @racket[#t], every empty line will be indented with the appropriate
    amount of whitespace as if there were a visible atom at that line. This is designed for use
    during editing.

    If @racket[#:trailing-newline?] is @racket[#t], a trailing empty line (two newlines) is enforced at the end of the file.
    Otherwise, @racket[fixw] preserves existing trailing empty lines.

    If @racket[#:annotate?] is @racket[#t], every close parenthesis is annotated with the current form head, such as @tt{) ;/for}. If more tokens would otherwise follow on the same line, @racket[fixw] inserts a newline after the annotation so the comment does not consume later code. Unmatched close parentheses are annotated as @tt{) ;/unmatched}.

    The built-in rules are always used.
}

@defproc[(fixw/lines [in input-port?]
                     [rules (or/c (hash/c string? integer?) #f)]
                     [start exact-nonnegative-integer? 0]
                     [end exact-nonnegative-integer? (length (port->lines in))]
                     [#:interactive? interactive? boolean? #f])
                     (listof string?)]{
    Like @racket[fixw], but returns a list of strings containing the formatted lines from @racket[start]
    to @racket[end] (exclusive).

    @racket[fixw/lines] does not remove extra trailing empty lines.

    The built-in rules are always used.
}

@section{Features}

You might want to know what fixw exactly does with your code:

@itemlist[
    @item{Runs a lexer on the code, removing whitespace (except newlines) unless in @literal{(fixw off)} disabled region.}
    @item{Regenerates the code, adding whitespace between tokens (with exceptions) and indenting tokens that follow a @racket[#\newline].}
    @item{Preserves trailing empty lines (use @racket[fixw/trailing-newline] to enforce a single trailing newline).}
]

Any other behavior should be considered a bug.

@section{Indent rules}

The fixw indenter has a basic assumption: user-defined procedures are more common than macros.
Therefore, it performs procedure indentation by default.

Procedure indentation looks like this:

@racketblock[
(fn arg1
    arg2
    ...)
]

Macros are treated as special cases. They are assumed to be like this:

@racketblock[
(macro parg_1
       parg_2
       ...
       parg_n
  body ...)
]

The number of @nonterm{parg} arguments for a macro is specified by a rule.

For example, a rule @racket[("func" 2)] specifies a form starting with @racket[func],
followed by 2 aligned arguments, and then the body.
So fixw formats @racket[func] like this:

@racketblock[
(func (function-name args ...)
      (types ...)
  body ...)
]

Besides these two strategies, fixw also uses some heuristics. Here are the full details:

@itemlist[
@item{If the head element of the form needs indentation, it receives 1 extra space.
@racketblock[
  (
   head)
]
}
@item{If the form is considered a list literal whose head element is a string, boolean,
number, character, keyword, @racket["#&"] or the opening parenthesis is not one of @racket[#\(],
@racket[#\[], @racket[#\{], all elements in this list have the same indentation.
@racketblock[
  (1 2
   3 4)
  #[v1 v2
    v3 v4]
]
}
@item{If the opening parenthesis ends with @racket[#\[], the second element of the form shares the same indentation.
@racketblock[
  [a
   (expt 2 10)]
]
}
@item{If the head element is a list, the second element shares the same indentation.
@racketblock[
  ([a 1]
   [b 2])
]
}
@item{If the head element is not a list, the second element is indented by 2 extra spaces.
@racketblock[
  (cond 
    [...])
]
}
@item{If a rule applies, it is followed.}
@item{Otherwise, elements follow the indentation of the second element.}
]

@section{Config file}

fixw supports reading user-defined rules from a @filepath{.lispwords} configuration file, compatible with 
@hyperlink["https://github.com/ds26gte/scmindent"]{scmindent's config}. Here are some examples; they are equivalent:

@racketblock[
(lambda 1)
(define 1)
@code:comment2{or}
(1 define lambda)
@code:comment2{or}
((define lambda) 1)
]

When formatting a file, fixw attempts to read the @filepath{.lispwords} file in the same directory.
If not found, it checks the parent directory, continuing up to the root directory.

The built-in rules are always used. User-defined rules override them.

@section{Enable/Disable in code}

Use @literal{(fixw off)} in a comment to temporarily disable fixw.
Use @literal{(fixw on)} to re-enable it.

For example,

@racketblock[
@code:comment2{(fixw off)}

@code:comment2{your code}

@code:comment2{(fixw on)}
]

