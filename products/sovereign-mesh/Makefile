# Makefile — Sovereign Mesh (SEIT product recreation)
# Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
# SPDX-License-Identifier: LicenseRef-SEIT-FSL-Donation-1.0
#
# Functional source, donation-gated runtime: you may read, share, and
# modify this source freely; running it requires a qualifying donation
# to the licensor. See LICENSE.txt for the full terms. No warranty.
all: sovereign_mesh

sovereign_mesh: Main.hs Sha256.hs
	ghc -Wall -O2 -o sovereign_mesh Main.hs

run: sovereign_mesh
	./sovereign_mesh

clean:
	rm -f sovereign_mesh *.o *.hi
