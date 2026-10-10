# Council Android (SEIT product recreation)

**SEIT description:** *"Kotlin mobile app. The OS in your pocket. Agent mesh access from anywhere."*

The real Council product is a Kotlin mobile app. This is a compact recreation of its
essence — **a mesh client speaking the agent-mesh protocol** — written fresh in C11.
It is not the app itself; it is the protocol interaction the app embodies, at small scale.

## What it is

A terminal REPL that talks a tiny line-based text protocol to a mock mesh server:

| Command          | Server response                                              |
|------------------|--------------------------------------------------------------|
| `DECIDE <text>`  | Decision receipt: `OK DECIDE id=<n> ts=<epoch> text=<...>`    |
| `SEAL <text>`    | Sealed receipt: `OK SEAL id=<n> hash=<hex> prev=<hex> text=<...>` |
| `QUIT`           | `OK BYE`, both sides exit                                    |
| anything else    | `ERR unknown command` (REPL continues)                      |

The **SEAL receipt carries a chained hash**: each seal hashes the receipt id plus the
text, seeded with the *previous* seal's hash — a miniature hash chain. The chain starts
from a genesis value (the FNV-1a 64-bit offset basis). The hash used is **FNV-1a 64-bit**,
written by hand in `council.c` (`fnv1a64`); it is a non-cryptographic fingerprint chosen
for its tiny code size, documented here explicitly as a demo stand-in.

## Mock, not a real mesh

- The "mesh server" is a **forked child process** inside this same program. The REPL
  (parent) and server communicate over a Unix `socketpair` — no network sockets, no
  remote peers, no discovery, no authentication, no persistence.
- There is no consensus, no quorum, no real cryptography. `DECIDE` is a timestamped
  receipt from the mock; `SEAL` chains hashes locally.

## Modeled vs simplified

- **Modeled:** the command/receipt exchange pattern; decision receipts with id +
  timestamp; sealed receipts linked by chained hash to the previous seal.
- **Simplified/stubbed:** server is in-process mock (no network); no auth or keying;
  FNV-1a instead of a cryptographic hash; receipts are not persisted; no multi-node mesh.

## Build and run

```
make        # builds ./council
make run    # non-interactive scripted demo (piped session), prints receipts
make clean
```

Interactive use:

```
./council
DECIDE Route night-shift traffic through eu-west.
SEAL Routing decision logged.
QUIT
```

## Files

- `council.c` — everything: REPL client, forked mock mesh server, FNV-1a. Fresh code, no copying.
- `Makefile` — targets `all`, `run` (scripted demo), `clean`.

Budget: $0. No dependencies, no network access.

## License

SEIT Functional Source License — Donation-Gated Runtime v1.0
Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab

Functional, viable source: read, share, and modify freely. Running this
software requires a qualifying donation to the licensor. See
[LICENSE.txt](LICENSE.txt) for the full terms. No warranty.
