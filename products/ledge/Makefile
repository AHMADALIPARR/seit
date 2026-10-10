# Makefile — LEDGE (SEIT product recreation)
# Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
# SPDX-License-Identifier: LicenseRef-SEIT-FSL-Donation-1.0
#
# Functional source, donation-gated runtime: you may read, share, and
# modify this source freely; running it requires a qualifying donation
# to the licensor. See LICENSE.txt for the full terms. No warranty.
CC = gcc
CFLAGS = -std=c11 -Wall -Wextra -O2

all: ledge

ledge: ledge.c
	$(CC) $(CFLAGS) -o ledge ledge.c

run: ledge
	rm -f chain.dat
	./ledge append "DECISION model=v3.2: approve loan application #481516 (risk_score=0.12, below 0.20 threshold)"
	./ledge append "DECISION model=v3.2: flag transaction #8841 for manual review (anomaly_score=0.87)"
	./ledge append "DECISION model=v3.2: escalate ticket #22904 to human agent (confidence=0.41 < 0.60)"
	./ledge append "DECISION policy=eng-117: auto-merge PR #3392 (all checks green, 2 approvals)"
	./ledge append "DECISION model=v3.2: deny loan application #481517 (risk_score=0.78, above 0.75 threshold)"
	./ledge verify

clean:
	rm -f ledge chain.dat

.PHONY: all run clean
