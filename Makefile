SHELL := /bin/bash
CC ?= cc
PREFIX ?= $(HOME)/.local
VERSION := $(strip $(file <VERSION))
CPPFLAGS += -D_DEFAULT_SOURCE
CPPFLAGS += -DXFCE_PLASMA_VERSION=\"$(VERSION)\"
CFLAGS ?= -O2
CFLAGS += -std=c11 -Wall -Wextra -Wpedantic -Wconversion -Wshadow -Wformat=2 -Werror

BUILD_DIR := build
RENDERER := $(BUILD_DIR)/xfce-plasma-renderer
RENDERER_SOURCE := src/renderer/main.c
SETTINGS_UI := $(BUILD_DIR)/xfce-plasma-settings-ui
SETTINGS_SOURCE := src/settings/main.c

.PHONY: all renderer settings check clean install uninstall doctor \
	check-build-deps check-runtime-deps check-deps
all: check-build-deps $(RENDERER) $(SETTINGS_UI)

renderer: check-build-deps $(RENDERER)

settings: check-build-deps $(SETTINGS_UI)

$(BUILD_DIR):
	mkdir -p "$@"

$(RENDERER): $(RENDERER_SOURCE) VERSION | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $$(pkg-config --cflags raylib x11) $(CFLAGS) "$<" -o "$@" $$(pkg-config --libs raylib x11) -lm

$(SETTINGS_UI): $(SETTINGS_SOURCE) VERSION | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $$(pkg-config --cflags gtk+-3.0) $(CFLAGS) "$<" -o "$@" $$(pkg-config --libs gtk+-3.0)

check-build-deps:
	@status=0; \
	check_command() { \
		if command -v "$$1" >/dev/null 2>&1; then printf 'OK       build: %s\n' "$$2"; \
		else printf 'ERROR    build: missing %s\n' "$$2"; status=1; fi; \
	}; \
	check_package() { \
		if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists "$$1"; then \
			printf 'OK       build: %s development files\n' "$$2"; \
		else printf 'ERROR    build: missing %s development files (pkg-config: %s)\n' "$$2" "$$1"; status=1; fi; \
	}; \
	check_command "$(CC)" "C compiler ($(CC))"; \
	check_command make "GNU make"; \
	check_command pkg-config "pkg-config"; \
	check_package raylib "raylib"; \
	check_package gtk+-3.0 "GTK 3"; \
	check_package x11 "X11"; \
	exit "$$status"

check-runtime-deps:
	@status=0; \
	check_required() { \
		if command -v "$$1" >/dev/null 2>&1; then printf 'OK       required: %s\n' "$$2"; \
		else printf 'ERROR    required: missing %s\n' "$$2"; status=1; fi; \
	}; \
	check_feature() { \
		if command -v "$$1" >/dev/null 2>&1; then printf 'OK       feature: %s (%s)\n' "$$2" "$$3"; \
		else printf 'WARNING  feature: %s unavailable without %s\n' "$$3" "$$2"; fi; \
	}; \
	check_optional() { \
		if command -v "$$1" >/dev/null 2>&1; then printf 'OK       optional: %s\n' "$$2"; \
		else printf 'OPTIONAL optional: %s is not installed\n' "$$2"; fi; \
	}; \
	check_required bash "Bash"; \
	check_required systemctl "systemd user tools"; \
	check_required xwinwrap "xwinwrap"; \
	check_required xfconf-query "XFCE xfconf-query"; \
	check_required xrandr "X11 RandR tools"; \
	check_feature import "ImageMagick import" "game-mode raster capture"; \
	check_feature convert "ImageMagick convert" "game-mode raster processing"; \
	check_feature xdotool "xdotool" "game/fullscreen detection"; \
	check_feature wmctrl "wmctrl" "floating Whisker helper"; \
	check_optional notify-send "desktop notifications"; \
	if command -v zenity >/dev/null 2>&1 || command -v rofi >/dev/null 2>&1; then \
		printf 'OK       optional: graphical shell picker\n'; \
	else printf 'OPTIONAL optional: Zenity or rofi graphical picker is not installed\n'; fi; \
	exit "$$status"

check-deps: check-build-deps check-runtime-deps

check: all
	@set -e; \
	for test in tests/test-*.sh; do \
		printf '==> %s\n' "$$test"; \
		bash "$$test"; \
	done

clean:
	rm -rf "$(BUILD_DIR)"

install: all
	./install.sh --user

uninstall:
	./install.sh --uninstall

doctor:
	./bin/xfce-plasma-doctor --project-root "$(CURDIR)"
