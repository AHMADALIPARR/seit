# Makefile — Finance OS (SEIT product recreation)
# Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
# SPDX-License-Identifier: LicenseRef-SEIT-FSL-Donation-1.0
#
# Functional source, donation-gated runtime: you may read, share, and
# modify this source freely; running it requires a qualifying donation
# to the licensor. See LICENSE.txt for the full terms. No warranty.
GHC = ghc
FLAGS = -Wall -O2

all: finance_os

finance_os: Main.hs Ledger.hs Receipt.hs
	$(GHC) $(FLAGS) -o finance_os Main.hs

run: finance_os
	./finance_os

clean:
	rm -f finance_os *.o *.hi
