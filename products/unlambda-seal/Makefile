# Makefile — Unlambda Seal (SEIT product recreation)
# Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
# SPDX-License-Identifier: LicenseRef-SEIT-FSL-Donation-1.0
#
# Functional source, donation-gated runtime: you may read, share, and
# modify this source freely; running it requires a qualifying donation
# to the licensor. See LICENSE.txt for the full terms. No warranty.
CC = gcc
CFLAGS = -std=c11 -Wall -Wextra -O2

all: unlambda

unlambda: unlambda.c
	$(CC) $(CFLAGS) -o $@ $<

run: unlambda
	@echo "=== seal receipt ==="
	./unlambda seal.unl
	@echo "=== call/cc: continuation invoked, print abandoned (expect empty) ==="
	./unlambda cc_invoke.unl; echo "[exit $$?]"
	@echo "=== echo: input Q (expect Q) ==="
	@printf 'Q' | ./unlambda echo.unl; echo

clean:
	rm -f unlambda

.PHONY: all run clean
