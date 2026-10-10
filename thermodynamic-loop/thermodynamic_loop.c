/*
 * thermodynamic_loop.c — Recreation of the SEIT Thermodynamic Feedback Loop.
 *
 * SEIT: "ERE constraint friction feeds back into ANU sampling. High friction
 * (many failures) = hot system = contracted sampling window toward sovereign
 * center. Low friction = cool system = full stochastic range. Haskell proves
 * lo < hi is an invariant, not an assertion. The system reshapes its own
 * quantum source."
 *
 * Model:
 *   - Sampling window [lo, hi] subset of [0,1], sovereign center c = 0.5.
 *   - Invariant lo < hi holds BY CONSTRUCTION: the only way to build or
 *     adjust a window is through window_make()/window_adjust(), which repair
 *     a collapsed window instead of returning it. (In the Haskell original
 *     this is a type-level proof; here it is a constructor-level guarantee
 *     plus a debug assert.)
 *   - Friction f in [0,1] is an EWMA of the per-decision failure rate: a
 *     decision that violates any constraint is a friction event.
 *   - Hot (f -> 1): window contracts toward center.
 *     Cool (f -> 0): window relaxes toward the full [0,1] range.
 *   - The loop closes through the sample itself: the constraint battery
 *     rejects samples landing in forbidden zones, so a wide window breeds
 *     friction, friction contracts the window, contraction starves friction,
 *     and the window re-expands. Homeostasis, not a fixed point.
 *
 * The driver runs three phases: calm -> thermal shock -> calm, so both the
 * hot contraction and the cool re-expansion are visible.
 *
 * Entropy source: pluggable. Default is xorshift64* (deterministic, seeded).
 * The ANU quantum node plugs in at entropy_draw() — see README.
 *
 * Build:  make
 * Run:    ./thermodynamic_loop [seed]
 */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

/* ------------------------------------------------------------------ */
/* Entropy source                                                      */
/* ------------------------------------------------------------------ */
static uint64_t rng_state = 0x9E3779B97F4A7C15ULL;

static uint64_t xorshift64star(void) {
    uint64_t x = rng_state;
    x ^= x >> 12;
    x ^= x << 25;
    x ^= x >> 27;
    rng_state = x;
    return x * 0x2545F4914F6CDD1DULL;
}

/*
 * Uniform double in [0,1). To go live on the ANU QRNG, replace this body
 * with a fetch from https://qrng.anu.edu.au/API/jsonI.php and scale the
 * returned uint to [0,1). Everything downstream is source-agnostic.
 */
static double entropy_draw(void) {
    return (xorshift64star() >> 11) * (1.0 / 9007199254740992.0);
}

/* ------------------------------------------------------------------ */
/* Sampling window — invariant lo < hi by construction                 */
/* ------------------------------------------------------------------ */
#define CENTER        0.5
#define MIN_WIDTH     0.02
#define CONTRACT_RATE 0.08
#define EXPAND_RATE   0.05

typedef struct {
    double lo, hi; /* invariant: lo < hi */
} Window;

static Window window_make(double lo, double hi) {
    if (lo < 0.0) lo = 0.0;
    if (hi > 1.0) hi = 1.0;
    if (hi - lo < MIN_WIDTH) {
        lo = CENTER - MIN_WIDTH / 2.0;
        hi = CENTER + MIN_WIDTH / 2.0;
    }
    Window w = { lo, hi };
    assert(w.lo < w.hi);
    return w;
}

/*
 * One thermodynamic tick of the window. friction in [0,1].
 * Returns a valid window by construction — never a collapsed one.
 */
static Window window_adjust(Window w, double friction) {
    double lo = w.lo, hi = w.hi;

    /* hot: contract toward the sovereign center */
    lo += friction * CONTRACT_RATE * (CENTER - lo);
    hi -= friction * CONTRACT_RATE * (hi - CENTER);

    /* cool: relax toward the full stochastic range */
    double cool = 1.0 - friction;
    lo -= cool * EXPAND_RATE * lo;
    hi += cool * EXPAND_RATE * (1.0 - hi);

    return window_make(lo, hi);
}

/* ------------------------------------------------------------------ */
/* ERE-style constraint battery                                        */
/* ------------------------------------------------------------------ */
#define NCHECKS 4

/* Calm regime: narrow forbidden zones (total width 0.22). */
static const double calm_lo[NCHECKS] = { 0.05, 0.30, 0.66, 0.88 };
static const double calm_hi[NCHECKS] = { 0.12, 0.34, 0.70, 0.95 };

/* Thermal shock regime: wide forbidden zones (total width 0.70). */
static const double shock_lo[NCHECKS] = { 0.02, 0.28, 0.58, 0.78 };
static const double shock_hi[NCHECKS] = { 0.22, 0.42, 0.74, 0.98 };

#define SHOCK_START 150
#define SHOCK_END   300
#define TICKS       450

/* Returns the number of failed checks, in [0, NCHECKS]. */
static int constraint_battery(double x, const double *zlo, const double *zhi) {
    int failed = 0;
    for (int i = 0; i < NCHECKS; i++) {
        if (x >= zlo[i] && x <= zhi[i])
            failed++;
    }
    return failed;
}

/* ------------------------------------------------------------------ */
/* Driver                                                              */
/* ------------------------------------------------------------------ */
#define FRICTION_ALPHA 0.10
#define BAR_WIDTH      40

static const char *temp_label(double f) {
    if (f > 0.60) return "HOT ";
    if (f > 0.30) return "WARM";
    return "COOL";
}

static void print_bar(Window w) {
    putchar('[');
    for (int i = 0; i < BAR_WIDTH; i++) {
        double x = (i + 0.5) / BAR_WIDTH;
        putchar((x >= w.lo && x <= w.hi) ? '#' : '-');
    }
    putchar(']');
}

int main(int argc, char **argv) {
    if (argc > 1)
        rng_state = (uint64_t)strtoull(argv[1], NULL, 0) | 1ULL;

    Window w = window_make(0.0, 1.0); /* start at full stochastic range */
    double friction = 0.0;
    long decisions = 0, friction_events = 0;

    printf("tick  fric  temp  lo      hi      width   window\n");
    for (int t = 0; t < TICKS; t++) {
        int shock = (t >= SHOCK_START && t < SHOCK_END);
        const double *zlo = shock ? shock_lo : calm_lo;
        const double *zhi = shock ? shock_hi : calm_hi;

        double x = w.lo + entropy_draw() * (w.hi - w.lo);
        int failed = constraint_battery(x, zlo, zhi);
        decisions++;
        if (failed > 0)
            friction_events++;

        /* a decision violating any constraint is a friction event */
        double tick_friction = (failed > 0) ? 1.0 : 0.0;
        friction = FRICTION_ALPHA * tick_friction + (1.0 - FRICTION_ALPHA) * friction;

        w = window_adjust(w, friction);

        if (t == SHOCK_START)
            printf("  --- thermal shock: forbidden zones widen ---\n");
        if (t == SHOCK_END)
            printf("  --- shock over: zones narrow, system cools ---\n");
        if (t < 3 || t % 25 == 24 || t == SHOCK_START || t == SHOCK_END - 1) {
            printf("%4d  %.3f %s  %.4f  %.4f  %.4f  ", t, friction, temp_label(friction),
                   w.lo, w.hi, w.hi - w.lo);
            print_bar(w);
            putchar('\n');
        }
    }

    printf("\nfinal: friction=%.3f (%s) window=[%.4f, %.4f] width=%.4f\n",
           friction, temp_label(friction), w.lo, w.hi, w.hi - w.lo);
    printf("friction events: %ld of %ld decisions (%.1f%%)\n",
           friction_events, decisions, 100.0 * friction_events / decisions);
    printf("invariant lo < hi held by construction on all %d ticks.\n", TICKS);
    return 0;
}
