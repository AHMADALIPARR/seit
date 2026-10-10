# ERE v1.0 — Enochian Reconstruction Engine (five-pass core)

A compact, working recreation of the ERE five-pass core in Haskell:
a token stream, where each token is tagged with a script, is checked
across five language passes simultaneously — Enochian, Latin, Hebrew,
Arabic, and Aramaic. Each pass is a **pure predicate**. METATRON certifies
the input **only when all five passes agree** (all `True`); otherwise the
input is **REJECTED**, naming the failed pass(es).

This is a **constraint-checking demo, not a decipherment**. No linguistic
claims are made about any ancient script.

## The mechanism

```
tokens ──► Enochian pass (pure) ──┐
         ──► Latin    pass (pure) ─┤
         ──► Hebrew   pass (pure) ─┼──► METATRON ──► CERTIFIED | REJECTED [pass…]
         ──► Arabic   pass (pure) ─┤
         ──► Aramaic  pass (pure) ─┘   (root layer)
```

- `Token` = a script tag plus a text (`Main.hs`).
- `Pass` = a name plus a pure `[Token] -> Bool` predicate.
- A pass inspects only the tokens tagged with its own script; every such
  token must satisfy that script's text predicate.
- METATRON = `and` over the five passes, collecting failures by name.

## The five passes — exact rules

| Pass     | Rule (exact) |
|----------|--------------|
| Latin    | Every Latin-tagged token uses only ASCII letters `a–z`, `A–Z`. |
| Hebrew   | Every Hebrew-tagged token uses only codepoints U+0590–U+05FF. |
| Arabic   | Every Arabic-tagged token uses only codepoints U+0600–U+06FF. |
| Aramaic (root layer) | Every Aramaic-tagged token is a **triliteral consonantal root**: exactly 3 glyphs, each in the Imperial Aramaic block U+10840–U+1085F. |
| Enochian | Every Enochian-tagged token uses only codepoints U+E000–U+E0FF. |

## Modeled vs. simplified (honest scope)

- **Modeled faithfully:** five simultaneous pure predicates; METATRON
  certifies only on unanimous agreement; REJECTED names every failed pass;
  the Aramaic root-layer rule (triliteral root) as stated above.
- **Simplified:** scripts are abstract as character sets — no lexicons,
  no grammar, no cross-script correspondence tables. Latin is ASCII-only
  (no diacritics); Hebrew/Arabic use their main Unicode blocks only.
  Enochian has no assigned Unicode block, so the Private Use Area
  U+E000–U+E0FF stands in for Enochian glyphs in this demo.
- **Known limitation:** a script with zero tokens in the stream passes
  vacuously (`all p [] == True`). The certified demo input includes one
  token per script so all five passes do real work.
- **Not modeled:** the remaining four languages of the nine-language engine,
  and any actual decoding of undeciphered scripts.

## Build & run

Requirements: GHC (tested with GHC 9.10.3). No dependencies, no network.

```
make        # ghc -Wall -O2 -o ere Main.hs  (zero warnings)
make run    # run the non-interactive demo
make clean
```

## Demo

`make run` checks three inputs:

- **Input A** — one valid token per script → `CERTIFIED`.
- **Input B** — Latin token `Lux4` carries a digit → `REJECTED`, failed
  pass named: **Latin**.
- **Input C** — Aramaic token of four glyphs is not a triliteral root →
  `REJECTED`, failed pass named: **Aramaic**.

## Files

- `Main.hs` — scripts, tokens, codepoint predicates, the five passes,
  METATRON, and the non-interactive demo. Written fresh for this product.
- `Makefile` — `all`, `clean`, `run` targets.

## Verification status

Built and run with the real toolchain: GHC 9.10.3, `ghc -Wall -O2`,
zero warnings. See the demo output in the build report.

## License

SEIT Functional Source License — Donation-Gated Runtime v1.0
Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab

Functional, viable source: read, share, and modify freely. Running this
software requires a qualifying donation to the licensor. See
[LICENSE.txt](LICENSE.txt) for the full terms. No warranty.
