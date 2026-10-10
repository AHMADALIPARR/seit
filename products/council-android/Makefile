# Makefile — Council Android (SEIT product recreation)
# Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
# SPDX-License-Identifier: LicenseRef-SEIT-FSL-Donation-1.0
#
# Functional source, donation-gated runtime: you may read, share, and
# modify this source freely; running it requires a qualifying donation
# to the licensor. See LICENSE.txt for the full terms. No warranty.
CC      = gcc
CFLAGS  = -std=c11 -Wall -Wextra -O2

all: council

council: council.c
	$(CC) $(CFLAGS) -o council council.c

run: council
	printf 'DECIDE Allocate 20%% of mesh capacity to edge inference.\nSEAL Council decision log opened.\nBOGUS hello?\nSEAL Capacity allocation confirmed.\nQUIT\n' | ./council

clean:
	rm -f council

.PHONY: all run clean
