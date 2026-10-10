# Sovereign Mesh (SACM)

A compact, working recreation of the SEIT **Stochastic Autonomous Compute Mesh**:
a 24-agent system where every decision is checked against 10 constitutional
axioms before acceptance, and accepted decisions are appended to a hash-chained
WORM log. No unsigned output is authoritative.

## Build & run

```sh
make        # ghc -Wall -O2 -o sovereign_mesh Main.hs (zero warnings)
make run    # build, then run the non-interactive demo
make clean
```

GHC 9.10.3 via `~/.ghcup`. $0 budget: no dependencies, no network, no packages
beyond what ships with GHC.

## What is modeled

- **24 agents** (`buildAgents`): id, name, trust level. Trust level doubles as
  the agent's clearance level (1–4, cycling across the roster).
- **The 10 constitutional axioms** as a Haskell ADT, exactly as named in the
  SEIT description: `NO_MAGMA_EXPOSURE`, `NO_EXTERNAL_AI_DEP`,
  `WORM_IMMUTABILITY`, `NO_CLEARANCE_ESCALATION`,
  `SOVEREIGN_INFRASTRUCTURE`, `ACCOUNTABLE_AUTHORITY`,
  `ENTROPY_IS_CATALYST`, `SIGN_BEFORE_STORE`, `MARINATE_BEFORE_EXECUTE`,
  `ISOLATION_BY_DEFAULT`.
- **Axiom checking**: each axiom is a pure predicate over `(Agent, Decision)`.
  All 10 are evaluated for every decision; any violation **rejects** the
  decision and the output names each violated axiom. Examples of the small-scale
  modeling choices:
  - `SIGN_BEFORE_STORE`: the decision must carry a signature that verifies.
  - `NO_CLEARANCE_ESCALATION`: `decClearance <= agent trustLevel`.
  - `ISOLATION_BY_DEFAULT`: the decision must carry an explicit grant.
  - `ENTROPY_IS_CATALYST`: the decision must carry a positive entropy draw.
  - `MARINATE_BEFORE_EXECUTE`: at least one marination round declared.
  - `ACCOUNTABLE_AUTHORITY`: a named authority must be present.
  - `NO_MAGMA_EXPOSURE` / `NO_EXTERNAL_AI_DEP` / `SOVEREIGN_INFRASTRUCTURE`:
    modeled as decision flags/targets, rejected when set to the forbidden value.
  - `WORM_IMMUTABILITY`: the decision must carry a non-empty payload hash,
    binding it to immutable content before storage.
- **Signatures — honestly not Ed25519**: a signature here is a keyed hash,
  `SHA-256(secret || canonical-decision-bytes)`, with a per-agent secret held
  by the mesh (symmetric, HMAC-style). Verification recomputes and compares.
  A missing or tampered signature fails `SIGN_BEFORE_STORE`. The SHA-256 is a
  self-contained implementation in `Sha256.hs`, checked against the standard
  test vectors (empty string and `"abc"` match `sha256sum`).
- **WORM log**: accepted decisions are appended to a hash-chained log
  (`entryHash = SHA-256(prevHash | decision | signature)`); entries are never
  mutated. The demo prints the chain and recomputes every link
  (`verifyChain`).

## Demo (`make run`)

7 decisions are submitted:

1. valid → **accepted** (worm seq 0)
2. **unsigned** → rejected: `SIGN_BEFORE_STORE`
3. clearance 4 from a clearance-2 agent → rejected: `NO_CLEARANCE_ESCALATION`
4. missing isolation grant → rejected: `ISOLATION_BY_DEFAULT`
5. missing authority → rejected: `ACCOUNTABLE_AUTHORITY`
6. valid → **accepted** (worm seq 1)
7. tampered signature → rejected: `SIGN_BEFORE_STORE`

The final WORM log (2 entries) is printed with its hash chain, verified intact.

## Simplified / stubbed vs the full SACM vision

- Signatures are symmetric keyed hashes, not Ed25519 (no asymmetric crypto).
- No actual networking, concurrency, or stochastic scheduling — the "mesh" is a
  roster checked in a single-threaded demo fold.
- The WORM log is in-memory for the run (printed to stdout), not a persisted
  append-only store; the hash chain is real, the durability is not.
- Axiom predicates are small-scale encodings (flags, clearance comparison,
  presence checks) of what in the full system would be policy engines.
- Entropy is a declared value on the decision, not a live entropy source.
- All code written fresh for this recreation; nothing copied from anywhere.

## License

SEIT Functional Source License — Donation-Gated Runtime v1.0
Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab

Functional, viable source: read, share, and modify freely. Running this
software requires a qualifying donation to the licensor. See
[LICENSE.txt](LICENSE.txt) for the full terms. No warranty.
