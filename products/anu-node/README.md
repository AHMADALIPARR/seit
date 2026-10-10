# ANU Quantum Node

A compact, working recreation of the SEIT product **ANU Quantum Node**
(slug: `anu-node`, language: C11).

SEIT's description: *"Temperature sourced from the Australian National
University quantum vacuum fluctuation generator. Physically real
randomness — not seeded, not simulated. Every agent decision runs at a
temperature that has never existed before and will never exist again."*

## Mechanism

Each run draws 32 bytes of entropy ("temperature") from a two-tier source:

1. **Live ANU QRNG JSON API** — `curl` fetches 16-byte hex strings from
   `https://qrng.anu.edu.au/API/jsonI.php?length=16&type=hex`. The JSON
   `data` array is parsed by hand (string search + `strchr`, no JSON
   library). Every string is validated strictly: exactly 32 hex characters,
   all valid hex digits; the wrong count or malformed JSON is a failure.
2. **Fallback: `getrandom()`** — used on *any* Tier 1 failure: curl
   missing, non-zero curl exit, timeout (`--max-time 10`), malformed
   JSON, wrong string length, or non-hex characters.

The program prints which tier supplied the bytes and the drawn bytes as
hex.

## Build & run

```
make        # builds anu_node with gcc -std=c11 -Wall -Wextra -O2
make run    # draws 32 bytes, prints source label + hex temperature
make clean
```

Example output:

```
source: ANU QRNG (live)
temperature: 9f3a7c1e02b84d6f51a2c930e8f47d1a
```

## What is modeled vs simplified

- **Modeled faithfully:** the two-tier entropy sourcing (live ANU QRNG
  preferred, `getrandom()` fallback on any failure), strict hand-parsing
  and validation of the ANU JSON `data` array, explicit source labeling,
  and the non-repeatability property (no seeding anywhere).
- **Simplified / stubbed:** SEIT's full product feeds this temperature
  into per-agent decisions; this node is the raw randomness source only.
  There is no agent framework, no temperature-scheduling semantics, and
  no caching or reuse of draws. The network path is `curl` via `popen`
  only — the one network call the spec allows.

All code was written fresh for this recreation. No external libraries,
no paid dependencies.

## License

SEIT Functional Source License — Donation-Gated Runtime v1.0
Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab

Functional, viable source: read, share, and modify freely. Running this
software requires a qualifying donation to the licensor. See
[LICENSE.txt](LICENSE.txt) for the full terms. No warranty.
