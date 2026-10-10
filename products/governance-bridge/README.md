# Quantum Governance Bridge

A compact, **working** recreation of the SEIT *Quantum Governance Bridge*
product: a four-layer sovereign decision pipeline that turns quantum entropy
into a certified, tamper-evident decision receipt.

All code in this directory was written fresh for this product. No network
access is used or needed ($0 budget, zero dependencies beyond GHC's `base`).

## The four layers

1. **Entropy source** — 32 bytes drawn from the OS: `/dev/urandom`.
   (Not the ANU quantum RNG; at this scale the source is the operating
   system's CSPRNG, documented here rather than claimed otherwise.)
2. **One-shot consumption** — the sample is wrapped in a phantom-typed
   `Token Fresh` and threaded through `consume :: Token Fresh ->
   (Token Consumed, ConsumptionProof, DecisionBits)`. The pipeline binds the
   `Fresh` token exactly once; afterwards only the `Consumed` token (good for
   audit, useless for re-entry) exists.
   **Honest statement: this is modeled, NOT compiler-enforced.** GHC's type
   system tracks the phantom state, but nothing stops a program from
   minting a second `Token Fresh` from the same bytes. Real linearity needs
   the `LinearTypes` extension; the real product would use that.
3. **Four watchtowers** — pure predicates voting APPROVE/DENY on the
   decision bits (four quadrant parities of the sample):
   - East / Air   (weight 3): APPROVE iff all four quadrant parities are even
   - South / Fire (weight 2): APPROVE iff the lead byte's high bit is set ("spark lit")
   - West / Water (weight 2): APPROVE iff the byte-sum mod 256 is >= 128 ("deep water")
   - North / Earth (weight 1): APPROVE iff the trail byte is even ("grounded")

   **Certification rule (METATRON-style): strict weighted majority.**
   Total weight is 8; the decision certifies only if approvals weigh more
   than half, i.e. a threshold of 5 of 8 weight.
4. **WORM receipt** — the certified decision is sealed with a hand-written
   FNV-1a 64-bit hash (offset basis 14695981039346656037, prime
   1099511628211) chained over the previous receipt's hash, and appended to
   `receipts.log`. Append-only file + hash chain: each receipt attests to
   the whole history before it.

## Build & run

```sh
make        # ghc -Wall -O2 -o governance_bridge Main.hs  (zero warnings)
make run    # one decision, end-to-end, non-interactive
make clean
```

`make run` prints the final receipt with each layer's contribution: entropy
sample id, consumption proof, the four watchtower votes, the certification
verdict, and the receipt hash.

## Modeled vs. simplified (honesty section)

| Aspect | Status |
|---|---|
| Entropy from `/dev/urandom` | Real, used |
| One-shot token consumption | Modeled in types; not compiler-enforced (see layer 2) |
| Watchtower predicates | Real pure functions, votes printed |
| Weighted-majority certification rule | Real, threshold 5/8 |
| FNV-1a-64 hash, written by hand | Real |
| WORM log | Append-only file + hash chain (filesystem WORM, not hardware WORM) |
| ANU quantum source, Prolog superposition, Rust components | Not present — outside the recreated scope |

## Files

- `Main.hs` — the whole product (~280 lines)
- `Makefile` — `all`, `clean`, `run`
- `receipts.log` — created on first run (append-only receipt chain)

## License

SEIT Functional Source License — Donation-Gated Runtime v1.0
Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab

Functional, viable source: read, share, and modify freely. Running this
software requires a qualifying donation to the licensor. See
[LICENSE.txt](LICENSE.txt) for the full terms. No warranty.
