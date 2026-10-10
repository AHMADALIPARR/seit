/*
 * ledge.c — LEDGE (SEIT product recreation)
 * Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
 * SPDX-License-Identifier: LicenseRef-SEIT-FSL-Donation-1.0
 *
 * Functional source, donation-gated runtime: you may read, share, and
 * modify this source freely; running it requires a qualifying donation
 * to the licensor. See LICENSE.txt for the full terms. No warranty.
 */
/*
 * LEDGE - compact recreation of SEIT's LEDGE product:
 * "Open-source cryptographic WORM chain - every AI decision sealed and
 *  auditable in under 10ms."
 *
 * Append-only hash chain. Each entry: index, timestamp, text, prev_hash, hash
 * where hash = SHA-256(prev_hash || timestamp || text).
 *
 * SHA-256 below is implemented fresh from the FIPS 180-4 specification.
 * Chain format and design decisions are documented in README.md.
 */
#define _POSIX_C_SOURCE 199309L

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* ------------------------------------------------------------------ */
/* SHA-256 (FIPS 180-4), implemented from the spec.                    */
/* ------------------------------------------------------------------ */

static uint32_t sha256_rotr(uint32_t x, unsigned n) {
    return (x >> n) | (x << (32u - n));
}

/* First 64 prime numbers' cube-root fractional parts (FIPS 180-4 4.2.2). */
static const uint32_t sha256_k[64] = {
    0x428a2f98u, 0x71374491u, 0xb5c0fbcfu, 0xe9b5dba5u,
    0x3956c25bu, 0x59f111f1u, 0x923f82a4u, 0xab1c5ed5u,
    0xd807aa98u, 0x12835b01u, 0x243185beu, 0x550c7dc3u,
    0x72be5d74u, 0x80deb1feu, 0x9bdc06a7u, 0xc19bf174u,
    0xe49b69c1u, 0xefbe4786u, 0x0fc19dc6u, 0x240ca1ccu,
    0x2de92c6fu, 0x4a7484aau, 0x5cb0a9dcu, 0x76f988dau,
    0x983e5152u, 0xa831c66du, 0xb00327c8u, 0xbf597fc7u,
    0xc6e00bf3u, 0xd5a79147u, 0x06ca6351u, 0x14292967u,
    0x27b70a85u, 0x2e1b2138u, 0x4d2c6dfcu, 0x53380d13u,
    0x650a7354u, 0x766a0abbu, 0x81c2c92eu, 0x92722c85u,
    0xa2bfe8a1u, 0xa81a664bu, 0xc24b8b70u, 0xc76c51a3u,
    0xd192e819u, 0xd6990624u, 0xf40e3585u, 0x106aa070u,
    0x19a4c116u, 0x1e376c08u, 0x2748774cu, 0x34b0bcb5u,
    0x391c0cb3u, 0x4ed8aa4au, 0x5b9cca4fu, 0x682e6ff3u,
    0x748f82eeu, 0x78a5636fu, 0x84c87814u, 0x8cc70208u,
    0x90befffau, 0xa4506cebu, 0xbef9a3f7u, 0xc67178f2u
};

/* Initial hash value H(0): square-root fractional parts of first 8 primes. */
static const uint32_t sha256_h0[8] = {
    0x6a09e667u, 0xbb67ae85u, 0x3c6ef372u, 0xa54ff53au,
    0x510e527fu, 0x9b05688cu, 0x1f83d9abu, 0x5be0cd19u
};

typedef struct {
    uint32_t h[8];
    uint64_t total_len;   /* bytes hashed so far */
    uint8_t  buf[64];     /* partial block */
    size_t   buf_len;
} sha256_ctx;

static void sha256_block(sha256_ctx *c, const uint8_t blk[64]) {
    uint32_t w[64];
    uint32_t a, b, cc, d, e, f, g, hh, t1, t2;
    int t;

    for (t = 0; t < 16; t++) {
        w[t] = ((uint32_t)blk[t * 4] << 24) | ((uint32_t)blk[t * 4 + 1] << 16) |
               ((uint32_t)blk[t * 4 + 2] << 8) | (uint32_t)blk[t * 4 + 3];
    }
    for (t = 16; t < 64; t++) {
        uint32_t s0 = sha256_rotr(w[t - 15], 7) ^ sha256_rotr(w[t - 15], 18) ^
                      (w[t - 15] >> 3);
        uint32_t s1 = sha256_rotr(w[t - 2], 17) ^ sha256_rotr(w[t - 2], 19) ^
                      (w[t - 2] >> 10);
        w[t] = w[t - 16] + s0 + w[t - 7] + s1;
    }

    a = c->h[0]; b = c->h[1]; cc = c->h[2]; d = c->h[3];
    e = c->h[4]; f = c->h[5]; g = c->h[6]; hh = c->h[7];

    for (t = 0; t < 64; t++) {
        uint32_t S1 = sha256_rotr(e, 6) ^ sha256_rotr(e, 11) ^ sha256_rotr(e, 25);
        uint32_t ch = (e & f) ^ (~e & g);
        t1 = hh + S1 + ch + sha256_k[t] + w[t];
        uint32_t S0 = sha256_rotr(a, 2) ^ sha256_rotr(a, 13) ^ sha256_rotr(a, 22);
        uint32_t maj = (a & b) ^ (a & cc) ^ (b & cc);
        t2 = S0 + maj;
        hh = g; g = f; f = e; e = d + t1;
        d = cc; cc = b; b = a; a = t1 + t2;
    }

    c->h[0] += a; c->h[1] += b; c->h[2] += cc; c->h[3] += d;
    c->h[4] += e; c->h[5] += f; c->h[6] += g; c->h[7] += hh;
}

static void sha256_init(sha256_ctx *c) {
    memcpy(c->h, sha256_h0, sizeof(c->h));
    c->total_len = 0;
    c->buf_len = 0;
}

static void sha256_update(sha256_ctx *c, const void *data, size_t len) {
    const uint8_t *p = (const uint8_t *)data;
    c->total_len += len;
    while (len > 0) {
        size_t take = 64 - c->buf_len;
        if (take > len) {
            take = len;
        }
        memcpy(c->buf + c->buf_len, p, take);
        c->buf_len += take;
        p += take;
        len -= take;
        if (c->buf_len == 64) {
            sha256_block(c, c->buf);
            c->buf_len = 0;
        }
    }
}

/* FIPS 180-4 padding: 0x80, zeros, then 64-bit big-endian bit length. */
static void sha256_final(sha256_ctx *c, uint8_t out[32]) {
    uint8_t pad[64];
    uint64_t bit_len = c->total_len * 8u;
    size_t pad_len;
    int i;

    pad[0] = 0x80u;
    memset(pad + 1, 0, sizeof(pad) - 1);
    /* We need buf_len + 1 + k to leave exactly 8 bytes for the length. */
    pad_len = (c->buf_len < 56) ? (56 - c->buf_len) : (120 - c->buf_len);
    sha256_update(c, pad, pad_len);

    for (i = 7; i >= 0; i--) {
        pad[i] = (uint8_t)(bit_len & 0xffu);
        bit_len >>= 8;
    }
    sha256_update(c, pad, 8);

    for (i = 0; i < 8; i++) {
        out[i * 4]     = (uint8_t)(c->h[i] >> 24);
        out[i * 4 + 1] = (uint8_t)(c->h[i] >> 16);
        out[i * 4 + 2] = (uint8_t)(c->h[i] >> 8);
        out[i * 4 + 3] = (uint8_t)c->h[i];
    }
}

static void sha256(const void *data, size_t len, uint8_t out[32]) {
    sha256_ctx c;
    sha256_init(&c);
    sha256_update(&c, data, len);
    sha256_final(&c, out);
}

/* ------------------------------------------------------------------ */
/* Chain storage.                                                      */
/* ------------------------------------------------------------------ */

#define CHAIN_FILE "chain.dat"
#define HASH_LEN 32

typedef struct {
    uint32_t index;
    int64_t  ts_ns;              /* CLOCK_REALTIME, nanoseconds since epoch */
    uint32_t text_len;
    uint8_t *text;
    uint8_t  prev_hash[HASH_LEN];
    uint8_t  hash[HASH_LEN];
} entry_t;

static void write_u32_be(uint8_t *p, uint32_t v) {
    p[0] = (uint8_t)(v >> 24); p[1] = (uint8_t)(v >> 16);
    p[2] = (uint8_t)(v >> 8);  p[3] = (uint8_t)v;
}

static uint32_t read_u32_be(const uint8_t *p) {
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) |
           ((uint32_t)p[2] << 8) | (uint32_t)p[3];
}

static void write_i64_be(uint8_t *p, int64_t v) {
    int i;
    for (i = 7; i >= 0; i--) {
        p[i] = (uint8_t)(v & 0xff);
        v >>= 8;
    }
}

static int64_t read_i64_be(const uint8_t *p) {
    uint64_t v = 0;
    int i;
    for (i = 0; i < 8; i++) {
        v = (v << 8) | p[i];
    }
    return (int64_t)v;
}

/* Entry serialization:
 *   u32be index | i64be ts_ns | u32be text_len | text | 32B prev_hash | 32B hash
 */
static int write_entry(FILE *f, const entry_t *e) {
    uint8_t hdr[16];
    write_u32_be(hdr, e->index);
    write_i64_be(hdr + 4, e->ts_ns);
    write_u32_be(hdr + 12, e->text_len);
    if (fwrite(hdr, 1, sizeof(hdr), f) != sizeof(hdr)) {
        return -1;
    }
    if (e->text_len > 0 &&
        fwrite(e->text, 1, e->text_len, f) != e->text_len) {
        return -1;
    }
    if (fwrite(e->prev_hash, 1, HASH_LEN, f) != HASH_LEN) {
        return -1;
    }
    if (fwrite(e->hash, 1, HASH_LEN, f) != HASH_LEN) {
        return -1;
    }
    return 0;
}

static void entry_free(entry_t *e) {
    free(e->text);
    e->text = NULL;
}

/* Returns: 1 = entry read, 0 = clean EOF, -1 = corrupt/truncated. */
static int read_entry(FILE *f, entry_t *e) {
    uint8_t hdr[16];
    size_t n = fread(hdr, 1, sizeof(hdr), f);
    if (n == 0) {
        return 0;
    }
    if (n != sizeof(hdr)) {
        return -1;
    }
    e->index = read_u32_be(hdr);
    e->ts_ns = read_i64_be(hdr + 4);
    e->text_len = read_u32_be(hdr + 12);
    if (e->text_len > 1024 * 1024) { /* sanity cap: 1 MiB decision text */
        return -1;
    }
    e->text = e->text_len ? malloc(e->text_len) : NULL;
    if (e->text_len && !e->text) {
        return -1;
    }
    if (e->text_len > 0 &&
        fread(e->text, 1, e->text_len, f) != e->text_len) {
        entry_free(e);
        return -1;
    }
    if (fread(e->prev_hash, 1, HASH_LEN, f) != HASH_LEN ||
        fread(e->hash, 1, HASH_LEN, f) != HASH_LEN) {
        entry_free(e);
        return -1;
    }
    return 1;
}

/* hash = SHA-256(prev_hash || ts_ns_be || text) */
static void seal_hash(const uint8_t prev[HASH_LEN], int64_t ts_ns,
                      const uint8_t *text, uint32_t text_len,
                      uint8_t out[HASH_LEN]) {
    sha256_ctx c;
    uint8_t tsbuf[8];
    sha256_init(&c);
    sha256_update(&c, prev, HASH_LEN);
    write_i64_be(tsbuf, ts_ns);
    sha256_update(&c, tsbuf, sizeof(tsbuf));
    sha256_update(&c, text, text_len);
    sha256_final(&c, out);
}

static void hex_of(const uint8_t in[HASH_LEN], char out[2 * HASH_LEN + 1]) {
    static const char digits[] = "0123456789abcdef";
    int i;
    for (i = 0; i < HASH_LEN; i++) {
        out[2 * i]     = digits[in[i] >> 4];
        out[2 * i + 1] = digits[in[i] & 0xfu];
    }
    out[2 * HASH_LEN] = '\0';
}

static double elapsed_ms(const struct timespec *a, const struct timespec *b) {
    return (double)(b->tv_sec - a->tv_sec) * 1000.0 +
           (double)(b->tv_nsec - a->tv_nsec) / 1e6;
}

static int cmd_append(const char *text) {
    FILE *f;
    entry_t last = { 0 };
    entry_t e;    struct timespec t0, t1;
    char hex[2 * HASH_LEN + 1];
    int have_last = 0;
    int rc;

    f = fopen(CHAIN_FILE, "rb");
    if (f) {
        entry_t cur;
        for (;;) {
            rc = read_entry(f, &cur);
            if (rc < 0) {
                fclose(f);
                fprintf(stderr, "error: chain.dat is corrupt\n");
                return 1;
            }
            if (rc == 0) {
                break;
            }
            entry_free(&last);
            last = cur;
            have_last = 1;
        }
        fclose(f);
    }

    e.index = have_last ? last.index + 1 : 0;
    e.text = (uint8_t *)text;
    e.text_len = (uint32_t)strlen(text);
    if (have_last) {
        memcpy(e.prev_hash, last.hash, HASH_LEN);
        entry_free(&last);
    } else {
        memset(e.prev_hash, 0, HASH_LEN); /* genesis */
    }

    clock_gettime(CLOCK_REALTIME, &t0); /* latency window starts */
    e.ts_ns = (int64_t)t0.tv_sec * 1000000000LL + (int64_t)t0.tv_nsec;

    seal_hash(e.prev_hash, e.ts_ns, e.text, e.text_len, e.hash);

    f = fopen(CHAIN_FILE, "ab");
    if (!f) {
        fprintf(stderr, "error: cannot open chain.dat for append\n");
        return 1;
    }
    if (write_entry(f, &e) != 0) {
        fprintf(stderr, "error: failed to write entry\n");
        fclose(f);
        return 1;
    }
    fflush(f);
    fclose(f);
    clock_gettime(CLOCK_REALTIME, &t1); /* latency window ends */

    hex_of(e.hash, hex);
    printf("sealed index=%u hash=%s latency=%.3fms\n",
           e.index, hex, elapsed_ms(&t0, &t1));
    return 0;
}

static int cmd_verify(void) {
    FILE *f = fopen(CHAIN_FILE, "rb");
    uint32_t expect_index = 0;
    uint8_t expect_prev[HASH_LEN];
    unsigned long count = 0;
    int r = 0;

    if (!f) {
        printf("VERIFY FAIL: no chain file found\n");
        return 1;
    }
    memset(expect_prev, 0, HASH_LEN); /* genesis prev_hash is all zeros */

    for (;;) {
        entry_t e;
        uint8_t expect[HASH_LEN];
        int rc = read_entry(f, &e);
        if (rc < 0) {
            printf("VERIFY FAIL: truncated/corrupt chain at entry %lu\n",
                   count);
            r = 1;
            break;
        }
        if (rc == 0) {
            break;
        }
        if (e.index != expect_index) {
            printf("VERIFY FAIL: index gap at entry %lu (got %u, want %u)\n",
                   count, e.index, expect_index);
            entry_free(&e);
            r = 1;
            break;
        }
        if (memcmp(e.prev_hash, expect_prev, HASH_LEN) != 0) {
            printf("VERIFY FAIL: prev_hash mismatch at index %u\n", e.index);
            entry_free(&e);
            r = 1;
            break;
        }
        seal_hash(e.prev_hash, e.ts_ns, e.text, e.text_len, expect);
        if (memcmp(e.hash, expect, HASH_LEN) != 0) {
            printf("VERIFY FAIL: hash mismatch at index %u\n", e.index);
            entry_free(&e);
            r = 1;
            break;
        }
        memcpy(expect_prev, e.hash, HASH_LEN);
        expect_index = e.index + 1;
        count++;
        entry_free(&e);
    }
    fclose(f);
    if (r == 0) {
        printf("VERIFY OK: %lu entries, chain intact\n", count);
    }
    return r;
}

static int cmd_selftest(void) {
    /* FIPS 180-4 / standard test vectors for SHA-256. */
    static const struct { const char *msg; const char *want; } vecs[] = {
        { "", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" },
        { "abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" },
        { "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
          "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1" }
    };
    size_t i;
    for (i = 0; i < sizeof(vecs) / sizeof(vecs[0]); i++) {
        uint8_t out[HASH_LEN];
        char hex[2 * HASH_LEN + 1];
        sha256(vecs[i].msg, strlen(vecs[i].msg), out);
        hex_of(out, hex);
        if (strcmp(hex, vecs[i].want) != 0) {
            printf("SELFTEST FAIL: vector %zu\n  got  %s\n  want %s\n",
                   i, hex, vecs[i].want);
            return 1;
        }
    }
    printf("SELFTEST OK: SHA-256 matches %zu standard test vectors\n",
           sizeof(vecs) / sizeof(vecs[0]));
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr,
                "usage: %s append <text> | verify | selftest\n", argv[0]);
        return 2;
    }
    if (strcmp(argv[1], "append") == 0) {
        if (argc < 3) {
            fprintf(stderr, "usage: %s append <text>\n", argv[0]);
            return 2;
        }
        return cmd_append(argv[2]);
    }
    if (strcmp(argv[1], "verify") == 0) {
        return cmd_verify();
    }
    if (strcmp(argv[1], "selftest") == 0) {
        return cmd_selftest();
    }
    fprintf(stderr, "unknown command: %s\n", argv[1]);
    return 2;
}
