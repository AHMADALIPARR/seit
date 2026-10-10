/*
 * unlambda.c — Unlambda Seal (SEIT product recreation)
 * Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
 * SPDX-License-Identifier: LicenseRef-SEIT-FSL-Donation-1.0
 *
 * Functional source, donation-gated runtime: you may read, share, and
 * modify this source freely; running it requires a qualifying donation
 * to the licensor. See LICENSE.txt for the full terms. No warranty.
 */
/*
 * unlambda.c — A small Unlambda (v2) interpreter in C11.
 *
 * Unlambda is a minimalist esoteric functional language: the entire language
 * is function application (written `) plus a handful of combinators and
 * I/O primitives. This interpreter implements the standard strict semantics:
 *
 *   s k i      standard combinators          `sxyz = (xz)(yz), `kxy = x, `ix = x
 *   v          void: `vx = v
 *   c          call/cc (one-shot, via setjmp/longjmp)
 *   d1         `d1x = promise of x (x not evaluated until forced)
 *   d2         ``d2xy = promise of `xy
 *   e          `ex terminates the program
 *   @          `@x: read a char c; then `x.c — on EOF, `xv
 *              (a "character value" is its own print primitive)
 *   |          like @ but echoes the character
 *   .x         `.xy: print x, return i
 *   r          `rx: print newline, return i
 *
 * Notes / honest limits:
 *  - `d` followed by 1/2 selects d1/d2; a bare `d` means d1 (original).
 *  - Whitespace and `#` comments are skipped between tokens (convenience;
 *    `.` still takes the literal next character, even a space).
 *  - call/cc continuations are ONE-SHOT: invoking a captured continuation
 *    twice is undefined (the jmp_buf is spent).
 *  - Nodes are never freed (fine for small programs).
 *
 * The classic print idiom is reversed nesting, because evaluation is
 * strict: "`.o`.l`.l`.e`.H`i" prints "Hello".
 *
 * Build:  make
 * Run:    ./unlambda seal.unl
 *         ./unlambda < prog.unl        (stdin; avoid if the program uses @)
 */
#include <stdio.h>
#include <stdlib.h>
#include <setjmp.h>

typedef enum {
    N_S, N_K, N_I, N_V, N_C, N_D1, N_D2, N_E,
    N_AT, N_PIPE, N_DOT, N_R,
    N_APP, N_PROMISE, N_CONT
} NType;

typedef struct Node {
    NType t;
    char c;                    /* N_DOT: character to print */
    struct Node *l, *r;        /* N_APP: function, argument; N_PROMISE: expr */
    jmp_buf jb;                /* N_CONT: captured continuation */
} Node;

static Node *new_node(NType t) {
    Node *n = calloc(1, sizeof *n);
    if (!n) { fprintf(stderr, "unlambda: out of memory\n"); exit(1); }
    n->t = t;
    return n;
}

/* ---------------- parser ---------------- */
static const char *src;
static int parse_error;

static void skip_ws(void) {
    for (;;) {
        char ch = *src;
        if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') { src++; continue; }
        if (ch == '#') { while (*src && *src != '\n') src++; continue; }
        break;
    }
}

static Node *parse_expr(void) {
    skip_ws();
    char ch = *src;
    if (ch == '\0') { parse_error = 1; return NULL; }
    src++;
    switch (ch) {
    case '`': {
        Node *a = parse_expr();
        Node *b = parse_expr();
        if (!a || !b) return NULL;
        Node *n = new_node(N_APP); n->l = a; n->r = b; return n;
    }
    case 's': return new_node(N_S);
    case 'k': return new_node(N_K);
    case 'i': return new_node(N_I);
    case 'v': return new_node(N_V);
    case 'c': return new_node(N_C);
    case 'd':
        if (*src == '1') { src++; return new_node(N_D1); }
        if (*src == '2') { src++; return new_node(N_D2); }
        return new_node(N_D1);
    case 'e': return new_node(N_E);
    case '@': return new_node(N_AT);
    case '|': return new_node(N_PIPE);
    case '.': {
        if (*src == '\0') { parse_error = 1; return NULL; }
        Node *n = new_node(N_DOT); n->c = *src; src++; return n;
    }
    case 'r': return new_node(N_R);
    default:
        fprintf(stderr, "unlambda: parse error at '%c'\n", ch);
        parse_error = 1;
        return NULL;
    }
}

/* ---------------- evaluator ---------------- */
static Node *cc_val;   /* value delivered when a continuation is invoked */

static Node *eval(Node *n);
static Node *apply(Node *f, Node *x);

/* Force promises in function position. */
static Node *force(Node *n) {
    while (n->t == N_PROMISE)
        n = eval(n->l);
    return n;
}

static Node *eval(Node *n) {
    switch (n->t) {
    case N_PROMISE:
        return eval(n->l);
    case N_APP: {
        Node *f = force(eval(n->l));
        if (f->t == N_D1) {           /* d1: delay the argument */
            Node *p = new_node(N_PROMISE); p->l = n->r; return p;
        }
        Node *x = eval(n->r);
        return apply(f, x);
    }
    default:
        return n;
    }
}

static Node *apply(Node *f, Node *x) {
    /* f is a forced value here */
    if (f->t == N_APP) {
        /* partial application in function position */
        Node *fl = f->l;
        if (fl->t == N_K)
            return f->r;                                  /* `kxy = x */
        if (fl->t == N_S) {                               /* `sx -> partial */
            Node *n = new_node(N_APP); n->l = f; n->r = x; return n;
        }
        if (fl->t == N_D2) {                              /* ``d2xy = promise */
            Node *a = new_node(N_APP); a->l = f->r; a->r = x;
            Node *p = new_node(N_PROMISE); p->l = a; return p;
        }
        if (fl->t == N_APP && fl->l->t == N_S) {           /* ```sxyz=(xz)(yz) */
            Node *a = fl->r, *b = f->r;
            Node *left = new_node(N_APP);  left->l = a; left->r = x;
            Node *right = new_node(N_APP); right->l = b; right->r = x;
            Node *app = new_node(N_APP);   app->l = left; app->r = right;
            return eval(app);
        }
        fprintf(stderr, "unlambda: runtime error (bad application)\n");
        exit(1);
    }
    switch (f->t) {
    case N_S:
    case N_K:
    case N_D2: {
        Node *n = new_node(N_APP); n->l = f; n->r = x; return n;
    }
    case N_I:
        return x;
    case N_V:
        return f;                                         /* `vx = v */
    case N_C: {                                           /* call/cc, one-shot */
        Node *cont = new_node(N_CONT);
        if (setjmp(cont->jb) == 0)
            return eval(apply(x, cont));
        return cc_val;                                    /* invoked: abandon */
    }
    case N_CONT:
        cc_val = x;
        longjmp(f->jb, 1);
        return x; /* unreachable */
    case N_D1: {                                          /* belt and braces */
        Node *p = new_node(N_PROMISE); p->l = x; return p;
    }
    case N_E:
        exit(0);
    case N_AT:
    case N_PIPE: {
        int ch = getchar();
        Node *arg;
        if (ch == EOF) {
            arg = new_node(N_V);
        } else {
            if (f->t == N_PIPE)
                putchar(ch);
            arg = new_node(N_DOT); arg->c = (char)ch;
        }
        return eval(apply(x, arg));
    }
    case N_DOT:
        putchar(f->c);
        return new_node(N_I);
    case N_R:
        putchar('\n');
        return new_node(N_I);
    default:
        fprintf(stderr, "unlambda: runtime error (bad function)\n");
        exit(1);
    }
    return NULL; /* unreachable */
}

/* ---------------- driver ---------------- */
static char *read_all(FILE *fp) {
    size_t cap = 1 << 16, len = 0;
    char *buf = malloc(cap);
    if (!buf) { fprintf(stderr, "unlambda: out of memory\n"); exit(1); }
    int ch;
    while ((ch = fgetc(fp)) != EOF) {
        if (len + 1 >= cap) { cap *= 2; buf = realloc(buf, cap); }
        buf[len++] = (char)ch;
    }
    buf[len] = '\0';
    return buf;
}

int main(int argc, char **argv) {
    FILE *fp = stdin;
    if (argc > 1) {
        fp = fopen(argv[1], "r");
        if (!fp) { perror("unlambda: open"); return 1; }
    }
    char *text = read_all(fp);
    if (fp != stdin)
        fclose(fp);

    src = text;
    Node *prog = parse_expr();
    if (parse_error || !prog) { fprintf(stderr, "unlambda: parse error\n"); return 1; }
    skip_ws();
    if (*src != '\0') { fprintf(stderr, "unlambda: parse error (trailing input)\n"); return 1; }

    eval(prog);
    return 0;
}
