# LEDGE

Compact recreation of SEIT's LEDGE product: *"Open-source cryptographic WORM
chain — every AI decision sealed and auditable in under 10ms."*

A single-file C11 program (`ledge`) that seals decision records into an
append-only SHA-256 hash chain and replays the chain to audit it. SHA-256 is
implemented from scratch in `ledge.c` from the FIPS 180-4 spec — no crypto
libraries, no network, zero dependencies beyond a C11 compiler and libc.

## Build & run

```sh
make            # builds ./ledge with: gcc -std=c11 -Wall -Wextra -O2
make run        # seals 5 demo decisions, prints each seal latency, then verify
make clean      # removes ./ledge and chain.dat
./ledge selftest  # checks SHA-256 against 3 standard test vectors
```

## CLI

```sh
./ledge append <text>   # seal one decision; prints index, hash, seal latency
./ledge verify          # replay whole chain; OK, or FAIL with the bad index
./ledge selftest        # validate the SHA-256 implementation
```

Seal latency covers timestamping + hashing + the append write, measured with
`clock_gettime` — target is <10ms per entry.

## Chain format (`chain.dat`, in the working directory)

Plain binary file, entries appended one after another. Each entry is:

| field      | bytes | layout                                   |
|------------|-------|------------------------------------------|
| index      | 4     | big-endian uint32, 0-based, gapless      |
| ts_ns      | 8     | big-endian int64, CLOCK_REALTIME ns      |
| text_len   | 4     | big-endian uint32 (max 1 MiB)            |
| text       | N     | decision text, raw bytes                 |
| prev_hash  | 32    | raw SHA-256 of previous entry (genesis: all zeros) |
| hash       | 32    | raw SHA-256(prev_hash \|\| ts_ns_be \|\| text)     |

`verify` replays every entry and recomputes each hash from the stored
`prev_hash`, timestamp, and text, so any tampering with any byte of any entry
(or any deletion/reorder) is detected at the first affected index.

## Modeled vs. simplified

- **Modeled faithfully:** append-only hash chain; `hash = SHA-256(prev_hash ||
  timestamp || text)`; per-entry seal latency printed against the 10ms
  target; full-chain replay audit that pinpoints the failing index; WORM
  semantics at the application level (only appends are ever written).
- **Simplified:** `chain.dat` lives in the current working directory (no
  configurable path, no log rotation); timestamps are wall-clock
  (CLOCK_REALTIME) with no trusted-timestamp authority; text is limited to
  1 MiB per entry; WORM enforcement is by design, not by filesystem/ACL
  immutability — on a hostile disk a rewritten file is caught by `verify`,
  not prevented; no networking, no key management, no multi-writer locking.
- **Not invented:** the mechanism above is exactly the described one
  (index/timestamp/text/prev_hash/hash, SHA-256 from FIPS 180-4, CLI
  `append`/`verify`, latency printout). Nothing else was added.

## Demo output (typical)

```
sealed index=0 hash=9f2c… latency=0.312ms
sealed index=1 hash=41ab… latency=0.287ms
…
VERIFY OK: 5 entries, chain intact
```

## License

SEIT Functional Source License — Donation-Gated Runtime v1.0
Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab

Functional, viable source: read, share, and modify freely. Running this
software requires a qualifying donation to the licensor. See
[LICENSE.txt](LICENSE.txt) for the full terms. No warranty.
