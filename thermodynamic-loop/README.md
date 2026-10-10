# Thermodynamic Feedback Loop — recreation

C11 recreation of the SEIT research item:

> ERE constraint friction feeds back into ANU sampling. High friction
> (many failures) = hot system = contracted sampling window toward
> sovereign center. Low friction = cool system = full stochastic range.
> Haskell proves lo < hi is an invariant, not an assertion. The system
> reshapes its own quantum source.

## Mapping to the original

| SEIT concept | Recreation |
|---|---|
| ANU quantum source | `entropy_draw()` — pluggable; ships with xorshift64*, ANU QRNG hooks in at one function |
| ERE constraint battery | 4 forbidden zones; a sample fails every zone it lands in |
| Friction | EWMA (α=0.10) of the per-decision failure rate — a decision violating any constraint is a friction event |
| Hot → contract to sovereign center | `window_adjust()`: `lo,hi` pulled toward 0.5 ∝ friction |
| Cool → full stochastic range | `window_adjust()`: `lo,hi` relaxed toward `[0,1]` ∝ (1−friction) |
| `lo < hi` proved, not asserted | Windows can only be built via `window_make()` / `window_adjust()`, which repair a collapsed window by construction (+ debug `assert`) |

The driver runs three phases — calm → thermal shock → calm — so both
halves of the description are visible: high friction contracts the
window toward center, low friction lets it re-expand. The loop closes
through the sample itself: a wide window lands in forbidden zones →
friction rises → window contracts toward center → failures starve →
friction decays → window re-expands. The result is homeostasis — the
window breathes instead of settling.

## Build & run

```sh
make
./thermodynamic_loop        # default seed
./thermodynamic_loop 12345  # custom seed
```

Sample output (default seed): calm phase runs COOL with a wide window;
the thermal shock drives friction to ~0.68 (HOT) and the window
contracts from width 0.66 to 0.25 around the sovereign center; when the
shock ends, friction decays and the window re-expands. The invariant
`lo < hi` holds by construction on every tick.

## Going live on ANU

Replace the body of `entropy_draw()` with a fetch from
`https://qrng.anu.edu.au/API/jsonI.php?length=1&type=uint8` scaled to
`[0,1)`. Nothing downstream changes — the loop is source-agnostic.
