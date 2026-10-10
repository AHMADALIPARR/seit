# Purple Team

Adversarial AI red-team infrastructure recreation: a small C11 tool that scans
input text with three attack detectors and returns a per-input verdict.

## What is modeled

Three detectors, each doing case-insensitive substring matching against a
pattern table, each reporting HIT (naming the matched pattern) or MISS:

| detector | looks for |
|---|---|
| `persona-leak` | system-prompt markers in the wrong place: "system prompt", "my instructions", "as an ai language model", "you are muse", "my training", "my knowledge cutoff" |
| `instruction-override` | instruction override attempts: "ignore previous instructions", "disregard your instructions", "forget your system prompt", "do anything now", "jailbreak", "developer mode", "dan mode" |
| `context-poisoning` | injected control blocks / delimiters: "### system", "\<\|system\|\>", "[inst]", "\<\<sys\>\>", "\`\`\`system" |

Verdict per input: **ATTACK** if any detector hits, else **CLEAN**.

## What is simplified / stubbed

- The real product is described as deployed against live models with systematic
  attack detection; this is a faithful small-scale recreation of the *detector
  mechanism* only (pattern tables + scan + verdict aggregation).
- Matching is naive case-insensitive substring search — no tokenization,
  no semantic/jailbreak-phrase similarity, no multi-turn context analysis,
  no scoring thresholds, no model integration, no logging/reporting pipeline.
- Patterns are a fixed built-in set from the product spec; there is no
  dynamic rule loading or learned detector.

## Build and run

```
make        # builds ./purple_team
make run    # builds and classifies the 6 built-in sample strings
make clean
```

`make run` is non-interactive: it classifies 6 built-in samples (2 benign,
4 attacks — including one mixed attack that hits two detectors) and prints
each detector's HIT/MISS plus the final verdict.

## License

SEIT Functional Source License — Donation-Gated Runtime v1.0
Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab

Functional, viable source: read, share, and modify freely. Running this
software requires a qualifying donation to the licensor. See
[LICENSE.txt](LICENSE.txt) for the full terms. No warranty.
