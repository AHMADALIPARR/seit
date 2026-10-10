# unlambda-seal — LEDGE seal ritual in Unlambda

The esoteric companion to the LEDGE product: a seal ceremony written in
Unlambda, executed by a small Unlambda (v2) interpreter written in C11.

## What's here

| File | What |
|---|---|
| `unlambda.c` | Unlambda interpreter (C11, `-Wall -Wextra` clean) |
| `seal.unl` | The seal ritual — prints a WORM receipt |
| `cc_invoke.unl` | call/cc test: continuation invoked, print abandoned |
| `echo.unl` | `@` test: echoes one input character |
| `k_test.unl` | Combinator smoke test |

## The interpreter

Implements the standard strict semantics: `s k i v c d1 d2 e @ | .x r`.
Application is strict except through `d1`/`d2`, which build promises.
Key implementation points:

- **Printing is reverse-nested.** Because arguments evaluate before the
  function applies, `"`.o`.l`.l`.e`.H`i"` prints `Hello` — the innermost
  application prints first. (This bit me twice during testing; the final
  `i` needs no preceding backquote.)
- **Characters are their own print primitive.** `` `@x `` reads a char `c`
  and evaluates `` `x.c `` — on EOF, `` `xv ``. So `echo.unl` ("`` `@``si`ki ``",
  i.e. `@` applied to `S I (K I)`) reads one char and prints it.
- **call/cc is one-shot via `setjmp`/`longjmp`.** `cc_invoke.unl`
  (`` `c `` applied to `S (K .p) (S I (K I))`) invokes the captured
  continuation, abandoning a pending print — verified: the `p` never
  appears and the program exits 0. Invoking a continuation twice is
  undefined (spent `jmp_buf`); documented, not guarded.
- Whitespace and `#` comments are skipped between tokens (convenience).
  `.` takes the literal next character, even a space.

## The seal ritual

`seal.unl` prints:

```
LEDGE
SEAL
decision=42
```

Honest scope: Unlambda's I/O model is print-only — there is no hashing
here. This is the *ceremony* of `SIGN_BEFORE_STORE` (axiom 8): the seal
as a pure, auditable ritual. The cryptographic sealing lives in the C
LEDGE product (`../ledge/`); this is its esoteric shadow.

## Build & run

```sh
make          # builds ./unlambda, zero warnings
make run      # seal receipt + call/cc test + echo test
./unlambda seal.unl
printf 'Q' | ./unlambda echo.unl
```

## License

SEIT Functional Source License — Donation-Gated Runtime v1.0
Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab

Functional, viable source: read, share, and modify freely. Running this
software requires a qualifying donation to the licensor. See
[LICENSE.txt](LICENSE.txt) for the full terms. No warranty.
