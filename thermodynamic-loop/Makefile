CC = gcc
CFLAGS = -std=c11 -Wall -Wextra -O2

all: thermodynamic_loop

thermodynamic_loop: thermodynamic_loop.c
	$(CC) $(CFLAGS) -o $@ $<

run: thermodynamic_loop
	./thermodynamic_loop

clean:
	rm -f thermodynamic_loop

.PHONY: all run clean
