# Makefile — Quantum Governance Bridge (SEIT product recreation)
# Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
# SPDX-License-Identifier: LicenseRef-SEIT-FSL-Donation-1.0
#
# Functional source, donation-gated runtime: you may read, share, and
# modify this source freely; running it requires a qualifying donation
# to the licensor. See LICENSE.txt for the full terms. No warranty.
GHCFLAGS = -Wall -O2

all: governance_bridge

governance_bridge: Main.hs
	ghc $(GHCFLAGS) -o governance_bridge Main.hs

run: all
	./governance_bridge

clean:
	rm -f governance_bridge Main.hi Main.o receipts.log

.PHONY: all run clean
