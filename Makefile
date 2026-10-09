PREFIX ?= /usr
BINDIR ?= $(PREFIX)/bin
DATADIR ?= $(PREFIX)/share
LIBDIR ?= $(PREFIX)/lib
SYSCONFDIR ?= /etc
DESTDIR ?=

APP_ID = io.mgalgs.FortGalgs

.PHONY: all check install

all:

check:
	python3 -c 'import ast, sys; [ast.parse(open(f).read(), f) for f in sys.argv[1:]]' fortctl fort-galgs
	desktop-file-validate $(APP_ID).desktop

# fortctl and the sudoers rule must name the same path: sudo runs exactly
# the file the rule names, as root, so both are rewritten from BINDIR here.
install:
	install -Dm755 fort-galgs $(DESTDIR)$(BINDIR)/fort-galgs
	install -Dm755 fortctl $(DESTDIR)$(BINDIR)/fortctl
	sed -i 's|^INSTALLED = .*|INSTALLED = "$(BINDIR)/fortctl"|' \
		$(DESTDIR)$(BINDIR)/fortctl
	install -Dm644 $(APP_ID).desktop \
		$(DESTDIR)$(DATADIR)/applications/$(APP_ID).desktop
	install -Dm644 $(APP_ID).svg \
		$(DESTDIR)$(DATADIR)/icons/hicolor/scalable/apps/$(APP_ID).svg
	install -Dm644 fort-galgs.toml $(DESTDIR)$(SYSCONFDIR)/fort-galgs.toml
	install -dm750 $(DESTDIR)$(SYSCONFDIR)/sudoers.d
	sed 's|@BINDIR@|$(BINDIR)|g' sudoers.in > sudoers.out
	install -Dm440 sudoers.out $(DESTDIR)$(SYSCONFDIR)/sudoers.d/fort-galgs
	rm -f sudoers.out
	install -Dm644 sysusers.conf $(DESTDIR)$(LIBDIR)/sysusers.d/fort-galgs.conf
	install -Dm644 systemd/fort-galgs-cpuset.conf \
		$(DESTDIR)$(LIBDIR)/systemd/system/user@.service.d/fort-galgs-cpuset.conf
	sed 's|@BINDIR@|$(BINDIR)|g' systemd/fort-galgs-watch.service > watch.out
	install -Dm644 watch.out \
		$(DESTDIR)$(LIBDIR)/systemd/user/fort-galgs-watch.service
	rm -f watch.out
