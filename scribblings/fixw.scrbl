#lang scribble/manual
@require[
    scribble/bnf
    scribble/example
    "shared.rkt"
    @for-label[fixw racket/base]]

@title{fixw}
@author{6cdh}

@defmodule[fixw]

A Racket formatter that only fixes whitespaces and keep newlines.

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

@exec{raco fixw} reads text from stdin, and output formatted code to stdout.

@exec{raco fixw @nonterm{files or dirs} ...} format @nonterm{files} or @nonterm{dirs} recursively.
For @nonterm{files}, fixw will format it whatever its extension.
For @nonterm{dirs}, fixw will format all @filepath{*.rkt} files recursively.

It accepts these flags:

@itemlist[
    @item{@Flag{t} --- use @racket[time] timing the whole formatting process and output.}
]

@section{API}

@defproc[(fixw [in input-port?]
               [rules (or/c (hash/c string? integer?) #f)]
               [#:interactive? interactive? boolean? #f])
               string?]{
    Read from @racket[in], and user defined rules @racket[rules], return formatted string.

    If @racket[interactive?] is @racket[#t], every empty line will be indented with appropriate
    amount of whitespace as if there are visible atom at that line. It is designed to be used 
    when editing.
    
    @racket[fixw] also remove extra trailing empty lines to keep only one trailing empty line.

    The builtin rules are always used.
}

@defproc[(fixw/lines [in input-port?]
                     [rules (or/c (hash/c string? integer?) #f)]
                     [start exact-nonnegative-integer? 0]
                     [end exact-nonnegative-integer? (length (port->lines in))]
                     [#:interactive? interactive? boolean? #f])
                     (listof string?)]{
    Like @racket[fixw], but return a list of string contains the formatted lines from @racket[start]
    to @racket[end](exclusive).

    @racket[fixw/lines] don't remove extra trailing empty lines.

    The builtin rules are always used.
}

@section{Features}

You might want to know what fixw exactly do with your code:

@itemlist[
    @item{running lexer on the code, remove whitespaces except newline or it's in disabled part.}
    @item{regenerate the code while add some whitespaces between two tokens except several exceptions,
    and indent for the tokens that following a @racket[#\newline].}
    @item{remove extra trailing empty lines.}
]

Any other behavior should be considered a bug.

@section{Indent rules}

fixw indenter has a basic assumption: user defined procedure is more common than macros.
So it will perform procedure indent by default.

The procedure indent look like this:

@racketblock[
(fn arg1
    arg2
    ...)
]

Macros as special cases. They are assumed to be like this:

@racketblock[
(macro parg_1
       parg_2
       ...
       parg_n
  body ...)
]

The number of @nonterm{parg} of a macro is specified by a rule.

For example, A rule @racket[("func" 2)] specifies a form whose first
element is @racket[func], then 2 argument aligned, then body.
So fixw will format @racket[func] as this:

@racketblock[
(func (function-name args ...)
      (types ...)
  body ...)
]

Except these two strategy, fixw also use some heuristics strategies. Here are the full details:

@itemlist[
@item{If the head element of the form need indent, it would have 1 extra space.
@racketblock[
  (
   head)
]
}
@item{If the form is considered a list literal whose head element is a string, boolean,
number, character, keyword, @racket["#&"] or the opening parenthesis is not one of @racket[#\(],
@racket[#\[], @racket[#\{], all elements in this list would have same indent.
@racketblock[
  (1 2
   3 4)
  #[v1 v2
    v3 v4]
]
}
@item{If the opening parenthesis ends with @racket[#\[], the second element of this form would have same indent.
@racketblock[
  [a
   (expt 2 10)]
]
}
@item{If the head element is a list, the second element of this form would have same indent.
@racketblock[
  ([a 1]
   [b 2])
]
}
@item{If the head element is not a list, the second element would have 2 extra spaces indented.
@racketblock[
  (cond 
    [...])
]
}
@item{If it hits a rule, it would follow the rule.}
@item{Otherwise, elements will follow the indent of the second element.}
]

@section{Config file}

fixw support read user defined rules from config file @filepath{.lispwords} that compatible with 
@hyperlink["https://github.com/ds26gte/scmindent"]{scmindent's config}. Here are some examples, they are equivalent.

@racketblock[
(lambda 1)
(define 1)
@code:comment2{or}
(1 define lambda)
@code:comment2{or}
((define lambda) 1)
]

For a file that need to be formatted, fixw will try to read the @filepath{.lispwords} file
at the same directory. If not found, then its parent directory, ..., until the root directory.

The builtin rules are always used. User defined rules can override them.

@section{Enable/Disable in code}

Use @literal{(fixw off)} in comment to disable fixw temporarily. 
And @literal{(fixw on)} to enable it.

For example,

@racketblock[
@code:comment2{(fixw off)}

@code:comment2{your code}

@code:comment2{(fixw on)}
]

