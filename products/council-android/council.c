/*
 * council.c — Council Android (SEIT product recreation)
 * Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
 * SPDX-License-Identifier: LicenseRef-SEIT-FSL-Donation-1.0
 *
 * Functional source, donation-gated runtime: you may read, share, and
 * modify this source freely; running it requires a qualifying donation
 * to the licensor. See LICENSE.txt for the full terms. No warranty.
 */
/*
 * council.c -- Council Android: a terminal REPL speaking a tiny text protocol
 *              to a mock agent-mesh server.
 *
 * The real Council product is a Kotlin mobile app ("The OS in your pocket").
 * This is a faithful-at-small-scale recreation of its essence: a mesh client
 * that issues commands to a mesh and receives signed receipts. Written fresh
 * in C11; no code copied from anywhere.
 *
 * Architecture: a forked child process acts as the mock mesh server. The
 * parent (REPL) and child communicate over a Unix socketpair. This is a MOCK
 * mesh -- there is no network, no remote peers, no real consensus.
 *
 * Protocol (client -> server, one line each):
 *   DECIDE <text>   server returns a decision receipt: id, unix time, text
 *   SEAL <text>     server returns a sealed receipt: id, chained hash, text
 *   QUIT            server says BYE and both sides exit
 *   anything else   server returns an ERR line; the REPL continues
 *
 * Seal chain: each SEAL receipt carries hash = FNV-1a(id bytes || text)
 * seeded with the previous seal's hash, so every receipt links to the one
 * before it -- a miniature hash chain. The chain starts from the FNV-1a
 * 64-bit offset basis ("genesis").
 */

#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

/* ---- FNV-1a, 64-bit, written by hand for this demo --------------------- */
#define FNV64_OFFSET 14695981039346656037ULL
#define FNV64_PRIME  1099511628211ULL

static uint64_t fnv1a64(const void *data, size_t len, uint64_t seed)
{
    const unsigned char *p = (const unsigned char *)data;
    uint64_t h = seed;
    for (size_t i = 0; i < len; i++) {
        h ^= (uint64_t)p[i];
        h *= FNV64_PRIME;
    }
    return h;
}

/* ---- small I/O helpers ------------------------------------------------ */
static int write_all(int fd, const char *buf, size_t len)
{
    size_t done = 0;
    while (done < len) {
        ssize_t n = write(fd, buf + done, len - done);
        if (n <= 0)
            return -1;
        done += (size_t)n;
    }
    return 0;
}

/* Read one \n-terminated line from fd; returns a heap string with no
 * trailing newline (also strips a trailing \r), or NULL on EOF/error
 * before any data. */
static char *read_line(int fd)
{
    size_t cap = 128, len = 0;
    char *buf = malloc(cap);
    if (!buf)
        return NULL;
    for (;;) {
        char c;
        ssize_t n = read(fd, &c, 1);
        if (n <= 0) {
            if (len == 0) {
                free(buf);
                return NULL;
            }
            break;
        }
        if (c == '\n')
            break;
        if (len + 1 >= cap) {
            size_t ncap = cap * 2;
            char *nb = realloc(buf, ncap);
            if (!nb) {
                free(buf);
                return NULL;
            }
            buf = nb;
            cap = ncap;
        }
        buf[len++] = c;
    }
    while (len > 0 && buf[len - 1] == '\r')
        len--;
    buf[len] = '\0';
    return buf;
}

static void send_line(int fd, const char *s)
{
    size_t n = strlen(s);
    char *out = malloc(n + 2);
    if (!out)
        return;
    memcpy(out, s, n);
    out[n] = '\n';
    out[n + 1] = '\0';
    (void)write_all(fd, out, n + 1);
    free(out);
}

/* ---- mock mesh server (runs in the forked child) ---------------------- */
static void mesh_server(int fd)
{
    uint64_t next_id = 1;
    uint64_t chain = FNV64_OFFSET; /* previous seal hash; genesis = offset basis */

    for (;;) {
        char *line = read_line(fd);
        if (!line)
            break; /* client went away */

        char resp[4096];
        if (strcmp(line, "QUIT") == 0) {
            send_line(fd, "OK BYE");
            free(line);
            break;
        } else if (strncmp(line, "DECIDE ", 7) == 0) {
            const char *text = line + 7;
            if (*text == '\0') {
                send_line(fd, "ERR DECIDE requires text");
            } else {
                uint64_t id = next_id++;
                long long ts = (long long)time(NULL);
                int r = snprintf(resp, sizeof(resp),
                                 "OK DECIDE id=%" PRIu64 " ts=%lld text=%s",
                                 id, ts, text);
                send_line(fd, r >= 0 ? resp : "ERR internal");
            }
        } else if (strncmp(line, "SEAL ", 5) == 0) {
            const char *text = line + 5;
            if (*text == '\0') {
                send_line(fd, "ERR SEAL requires text");
            } else {
                uint64_t id = next_id++;
                unsigned char idb[8];
                for (int i = 0; i < 8; i++)
                    idb[i] = (unsigned char)((id >> (8 * i)) & 0xff);
                uint64_t h = fnv1a64(idb, 8, chain);
                h = fnv1a64(text, strlen(text), h);
                int r = snprintf(resp, sizeof(resp),
                                 "OK SEAL id=%" PRIu64 " hash=%016" PRIx64
                                 " prev=%016" PRIx64 " text=%s",
                                 id, h, chain, text);
                chain = h;
                send_line(fd, r >= 0 ? resp : "ERR internal");
            }
        } else {
            send_line(fd, "ERR unknown command");
        }
        free(line);
    }
    close(fd);
}

/* ---- mesh client / REPL (runs in the parent) -------------------------- */
static int mesh_client(int fd)
{
    char *line = NULL;
    size_t cap = 0;
    ssize_t n;

    while ((n = getline(&line, &cap, stdin)) != -1) {
        while (n > 0 && (line[n - 1] == '\n' || line[n - 1] == '\r'))
            line[--n] = '\0';
        if (n == 0)
            continue; /* skip blank lines */

        size_t len = (size_t)n;
        char *req = malloc(len + 2);
        if (!req) {
            free(line);
            return 1;
        }
        memcpy(req, line, len);
        req[len] = '\n';
        req[len + 1] = '\0';
        if (write_all(fd, req, len + 1) != 0) {
            free(req);
            free(line);
            return 1;
        }
        free(req);

        char *resp = read_line(fd);
        if (!resp)
            break;
        printf("%s\n", resp);
        fflush(stdout);
        int bye = (strcmp(resp, "OK BYE") == 0);
        free(resp);
        if (bye)
            break;
    }
    free(line);
    close(fd);
    return 0;
}

int main(void)
{
    int sv[2];
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, sv) != 0) {
        perror("socketpair");
        return 1;
    }

    pid_t pid = fork();
    if (pid < 0) {
        perror("fork");
        return 1;
    }
    if (pid == 0) {
        close(sv[0]);
        mesh_server(sv[1]);
        _exit(0);
    }

    close(sv[1]);
    int rc = mesh_client(sv[0]);

    int status = 0;
    if (waitpid(pid, &status, 0) < 0 && errno != EINTR) {
        perror("waitpid");
        return 1;
    }
    if (WIFEXITED(status))
        return WEXITSTATUS(status);
    return rc;
}
