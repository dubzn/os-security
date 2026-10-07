CC ?= cc
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic -Werror -O2
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

PROGRAMS = tp2-reader tp2-event

.PHONY: all clean install uninstall test

all: $(PROGRAMS)

tp2-reader: src/tp2_reader.c
	$(CC) $(CFLAGS) -o $@ $<

tp2-event: src/tp2_event.c
	$(CC) $(CFLAGS) -o $@ $<

install: all
	install -d "$(DESTDIR)$(BINDIR)"
	install -m 0755 tp2-reader "$(DESTDIR)$(BINDIR)/tp2-reader"
	install -m 0755 tp2-event "$(DESTDIR)$(BINDIR)/tp2-event"

uninstall:
	rm -f "$(DESTDIR)$(BINDIR)/tp2-reader" "$(DESTDIR)$(BINDIR)/tp2-event"

test: all
	./tp2-reader --archivo-inexistente >/dev/null 2>&1; test $$? -eq 2
	@echo "Pruebas basicas de binarios: OK"

clean:
	rm -f $(PROGRAMS)
