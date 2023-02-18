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

For example, A rule `("func" 1)` specifies a form whose first argument is `func`, should have 1 argument, then body. So `fixw` will format `func` as this:

```racket
(func (function-name n ...)
      (types ...)
  body ...)
```

Except these two strategy, `fixw` also use these heuristics strategies:

* If the first argument of a list is a number, boolean, character, string, or keyword literal, it will format it as a list:
  ```racket
  (1 2 3
   4 5 6)
  ```
* If the opening parenthese ends with `[` or not a normal parenthese, it will format it as a list:
  ```racket
  #[name1 name2
    name3 name4]
  #hash((...)
        (...))
  ```
* If the first argument is a list, it will format it as a list:
  ```racket
  ((fn ...)
   arg1
   arg2)
  (let ([...]
        [...])
    body ...)
  ```
* If only one argument of a list at its first line, other arguments will have 2 extra spaces indented:
  ```racket
  (cond
    [...])
  ```

