# Indent

`fixw` indenter has a basic assumption: user defined procedure is more common than macros. It will perform procedure indent by default.

The procedure indent look like this:

```racket
(fn arg1
    arg2
    ...)
```

Macros as special cases. They are assumed to be like this:

```racket
(macro parg_1
       parg_2
       ...
       parg_n
  body ...)
```

The number of `parg` of a macro is specified by a rule.

For example, A rule `("func" 2)` specifies a form whose first argument is `func`, should have 2 argument, then body. So `fixw` will format `func` as this:

```racket
(func (function-name n ...)
      (types ...)
  body ...)
```

Except these two strategy, `fixw` also use some heuristics strategies. Here are the full details:

* If the head element of the form need indent, it would have 1 extra space.
  ```racket
  (
   head)
  ```
* If the form is considered a list literal whose head element is a string, boolean, number, character, keyword, `#&` or the opening parenthesis is not one of `(`, `[`, `{`, all elements in this list would have same indent.
  ```racket
  (1 2
   3 4)
  #[v1 v2
    v3 v4]
  ```
* If the opening parenthesis ends with `[`, the second element of this form would have same indent.
  ```racket
  [a
   (expt 2 10)]
  ```
* If the head element is a list, the second element of this form would have same indent.
  ```racket
  ([a 1]
   [b 2])
  ```
* If the head element is not a list, the second element would have 2 extra spaces indented.
  ```racket
  (cond 
    [...])
  ```
* If it hits a rule, it would follow the rule.
* Otherwise, elements will follow the indent of the second element.

