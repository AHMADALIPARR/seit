# Makefile — ERE v1.0 (SEIT product recreation)
# Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
# SPDX-License-Identifier: LicenseRef-SEIT-FSL-Donation-1.0
#
# Functional source, donation-gated runtime: you may read, share, and
# modify this source freely; running it requires a qualifying donation
# to the licensor. See LICENSE.txt for the full terms. No warranty.
# ERE v1.0 — Enochian Reconstruction Engine (five-pass core)
# Builds with the real GHC toolchain; zero warnings required (-Wall).

GHC   ?= ghc
FLAGS  = -Wall -O2

all: ere

ere: Main.hs
	$(GHC) $(FLAGS) -o ere Main.hs

run: ere
	./ere

clean:
	rm -f ere Main.o Main.hi

.PHONY: all clean run
