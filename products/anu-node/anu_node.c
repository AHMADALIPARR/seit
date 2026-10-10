/*
 * anu_node.c — ANU Quantum Node (SEIT product recreation)
 * Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
 * SPDX-License-Identifier: LicenseRef-SEIT-FSL-Donation-1.0
 *
 * Functional source, donation-gated runtime: you may read, share, and
 * modify this source freely; running it requires a qualifying donation
 * to the licensor. See LICENSE.txt for the full terms. No warranty.
 */
/*
 * anu_node.c -- ANU Quantum Node (SEIT product recreation)
 *
 * Draws 32 bytes of entropy ("temperature") from one of two tiers:
 *
 *   Tier 1: the live Australian National University quantum random number
 *           generator JSON API. Vacuum-fluctuation-derived hex strings,
 *           fetched with curl and parsed by hand (no JSON library).
 *   Tier 2: getrandom() as the fallback. Used on ANY failure of Tier 1:
 *           curl missing or failing, network error, timeout, malformed
 *           JSON, wrong data length, non-hex characters.
 *
 * The program prints which tier supplied the bytes and the drawn bytes
 * as hex. Every run's temperature has never existed before and will
 * never exist again.
 */

#define _GNU_SOURCE /* getrandom(), popen() under -std=c11 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/random.h>

#define DRAW_BYTES 32u /* total bytes drawn per run */
#define CHUNK_LEN 16u  /* bytes per ANU hex string requested */
#define RESP_MAX 16384 /* largest ANU JSON response we accept */

#define ANU_URL "https://qrng.anu.edu.au/API/jsonI.php?length=16&type=hex"
#define CURL_CMD "curl -s --max-time 10 '" ANU_URL "'"

/* Return the nibble value of a hex digit, or -1 if not hex. */
static int hex_nibble(char c)
{
	if (c >= '0' && c <= '9')
		return c - '0';
	if (c >= 'a' && c <= 'f')
		return c - 'a' + 10;
	if (c >= 'A' && c <= 'F')
		return c - 'A' + 10;
	return -1;
}

/*
 * Attempt a Tier 1 draw: fetch DRAW_BYTES bytes worth of hex strings from
 * the live ANU QRNG JSON API. Returns 0 on success, -1 on any failure.
 * Each hex string must be exactly 2*CHUNK_LEN hex characters; the first
 * DRAW_BYTES/CHUNK_LEN strings are consumed in order.
 */
static int draw_anu(unsigned char *out, size_t n)
{
	char resp[RESP_MAX];
	FILE *fp;
	size_t len, got, need, i;
	const char *data, *p, *q;
	int status, hi, lo;

	if (n == 0 || n % CHUNK_LEN != 0)
		return -1;

	fp = popen(CURL_CMD, "r");
	if (fp == NULL)
		return -1;
	len = fread(resp, 1, sizeof(resp) - 1, fp);
	status = pclose(fp);
	if (status != 0)
		return -1;
	resp[len] = '\0';

	/* Locate the "data" array. */
	data = strstr(resp, "\"data\"");
	if (data == NULL)
		return -1;
	data = strchr(data, '[');
	if (data == NULL)
		return -1;
	p = data + 1;

	need = n / CHUNK_LEN;
	got = 0;
	for (i = 0; i < need; i++) {
		p = strchr(p, '"');
		if (p == NULL)
			return -1;
		p++;
		q = strchr(p, '"');
		if (q == NULL)
			return -1;
		if ((size_t)(q - p) != (size_t)(CHUNK_LEN * 2))
			return -1;
		for (size_t j = 0; j < CHUNK_LEN; j++) {
			hi = hex_nibble(p[2 * j]);
			lo = hex_nibble(p[2 * j + 1]);
			if (hi < 0 || lo < 0)
				return -1;
			*out++ = (unsigned char)((hi << 4) | lo);
		}
		got++;
		p = q + 1;
	}
	if (got != need)
		return -1;
	return 0;
}

/* Tier 2 draw: OS entropy via getrandom(). Returns 0/-1. */
static int draw_fallback(unsigned char *out, size_t n)
{
	size_t got = 0;

	while (got < n) {
		ssize_t r = getrandom(out + got, n - got, 0);

		if (r < 0)
			return -1;
		got += (size_t)r;
	}
	return 0;
}

/* Print bytes as lowercase hex on one line. */
static void print_hex(const unsigned char *buf, size_t n)
{
	for (size_t i = 0; i < n; i++)
		printf("%02x", buf[i]);
	printf("\n");
}

int main(void)
{
	unsigned char buf[DRAW_BYTES];
	const char *label;

	if (draw_anu(buf, sizeof(buf)) == 0) {
		label = "ANU QRNG (live)";
	} else if (draw_fallback(buf, sizeof(buf)) == 0) {
		label = "getrandom() (fallback)";
	} else {
		fprintf(stderr, "anu_node: both entropy tiers failed\n");
		return EXIT_FAILURE;
	}

	printf("source: %s\n", label);
	printf("temperature: ");
	print_hex(buf, sizeof(buf));
	return EXIT_SUCCESS;
}
