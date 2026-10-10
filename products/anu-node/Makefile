# Makefile — ANU Quantum Node (SEIT product recreation)
# Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
# SPDX-License-Identifier: LicenseRef-SEIT-FSL-Donation-1.0
#
# Functional source, donation-gated runtime: you may read, share, and
# modify this source freely; running it requires a qualifying donation
# to the licensor. See LICENSE.txt for the full terms. No warranty.
CC = gcc
CFLAGS = -std=c11 -Wall -Wextra -O2
TARGET = anu_node

all: $(TARGET)

$(TARGET): anu_node.c
	$(CC) $(CFLAGS) -o $(TARGET) anu_node.c

run: $(TARGET)
	./$(TARGET)

clean:
	rm -f $(TARGET)

.PHONY: all clean run
