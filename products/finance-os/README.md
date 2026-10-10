# Finance OS

SEIT description: *"Triple-entry accounting with Plaid-powered cash flow
underwriting. Built for communities traditional banks exclude. Every
transaction cryptographically sealed."*

This is a compact, working recreation of that mechanism, built in Haskell
with no dependencies beyond GHC's `base` libraries.

## What's modeled

- **Pure-functional ledger core** (`Ledger.hs`) — zero IO. A `Ledger` maps
  accounts to signed balances in integer cents (no floats, no rounding).
- **Chart of accounts** covering all five classes: Cash (Assets),
  Member Deposits (Liabilities), Capital (Equity), Fee Income (Income),
  Operating Expenses (Expenses).
- **Balanced double-entry**: every `Posting` is a set of debit/credit legs.
  `post` **rejects** any posting whose total debits ≠ total credits
  (`Unbalanced`), any posting with non-positive amounts, and any posting
  with no legs. The demo deliberately submits an unbalanced posting to
  prove the rejection path works.
- **Third entry** (`Receipt.hs`): every *accepted* posting is issued a
  receipt chained to the previous one:
  `receipt_n = hash(receipt_{n-1} || posting)`.
  Postings are deterministically byte-encoded (length-prefixed,
  big-endian), so equal postings always encode identically and different
  postings encode differently.

## Hash choice (required disclosure)

This build uses **FNV-1a (64-bit), written from scratch in this repo** —
not SHA-256. FNV-1a is a fast, *non-cryptographic* hash. The receipt chain
therefore provides **tamper-evidence** (any alteration to a posted
transaction invalidates every receipt after it), not cryptographic
sealing in the strong sense. Replacing `fnv1a64` with a real SHA-256
would be a drop-in change to `Receipt.hs`.

## Stubbed / simplified (required disclosure)

- **No Plaid integration.** There is no network access, no bank API, no
  cash-flow underwriting model — that entire subsystem is stubbed (absent).
  The demo posts hand-written community-finance transactions instead.
- Single-currency (integer cents), no dates/timestamps on postings, no
  persistence (the ledger is in-memory), no multi-user auth. The receipt
  chain is verified implicitly by construction; there is no separate
  auditor tool.

## Build and run

```sh
make        # ghc -Wall -O2 -o finance_os Main.hs  (zero warnings)
make run    # posts 4 demo transactions, prints trial balance + receipt chain
make clean
```

`make run` output: one rejected unbalanced posting, 4 accepted postings,
a balanced trial balance (total debits = total credits = 1580.00), and
the 4-receipt hash chain.

All code written fresh for this product. No external code was copied.

## License

SEIT Functional Source License — Donation-Gated Runtime v1.0
Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab

Functional, viable source: read, share, and modify freely. Running this
software requires a qualifying donation to the licensor. See
[LICENSE.txt](LICENSE.txt) for the full terms. No warranty.
