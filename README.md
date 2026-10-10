# SEIT — SnapKitty External Intelligence Team

Recreations of the SEIT collective page and its research artifacts,
built in C11, Haskell, and Unlambda.

- `index.html` — structural recreation of the SEIT page
  (masthead, mission, research lines, shipped products, curriculum,
  team, funding, SACM axioms)
- `thermodynamic-loop/` — Thermodynamic Feedback Loop in C11
  (EWMA friction battery, adaptive sampling window)
- `products/` — the eight shipped SEIT products, recreated:
  - `ledge/` — append-only SHA-256 WORM chain (C11)
  - `finance-os/` — triple-entry accounting (Haskell)
  - `sovereign-mesh/` — 24 agents, 10 constitutional axioms (Haskell)
  - `ere/` — five-pass language constraint engine (Haskell)
  - `purple-team/` — adversarial prompt scanner (C11)
  - `anu-node/` — quantum entropy node, ANU QRNG + fallback (C11)
  - `governance-bridge/` — entropy-to-certification pipeline (Haskell)
  - `council-android/` — terminal mesh client (C11)
  - `unlambda-seal/` — LEDGE seal ritual in Unlambda (C11 interpreter)

Each product builds with its real toolchain (`make` in each directory)
and ships with a README mapping the mechanism and honest notes on what
is modeled vs. simplified.

## License

Each product directory carries its own `LICENSE.txt`:
SEIT Functional Source License — Donation-Gated Runtime v1.0.
Functional, viable source — read, share, modify freely; running the
software requires a qualifying donation to the licensor.
Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab.
