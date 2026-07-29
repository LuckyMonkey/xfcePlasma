SHELL := /bin/bash
CC ?= cc
CPPFLAGS += -D_DEFAULT_SOURCE
CFLAGS ?= -O2
CFLAGS += -std=c11 -Wall -Wextra -Wpedantic -Wconversion -Wshadow -Wformat=2 -Werror
RAYLIB_CPPFLAGS := $(shell pkg-config --cflags raylib)
RAYLIB_LDLIBS := $(shell pkg-config --libs raylib) -lX11 -lm
GTK_CPPFLAGS := $(shell pkg-config --cflags gtk+-3.0)
GTK_LDLIBS := $(shell pkg-config --libs gtk+-3.0)

BUILD_DIR := build
RENDERER := $(BUILD_DIR)/xfce-plasma-renderer
RENDERER_SOURCE := src/renderer/main.c
SETTINGS_UI := $(BUILD_DIR)/xfce-plasma-settings-ui
SETTINGS_SOURCE := src/settings/main.c

.PHONY: all renderer settings check clean
all: renderer settings

renderer: $(RENDERER)

settings: $(SETTINGS_UI)

$(BUILD_DIR):
	mkdir -p "$@"

$(RENDERER): $(RENDERER_SOURCE) | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(RAYLIB_CPPFLAGS) $(CFLAGS) "$<" -o "$@" $(RAYLIB_LDLIBS)

$(SETTINGS_UI): $(SETTINGS_SOURCE) | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(GTK_CPPFLAGS) $(CFLAGS) "$<" -o "$@" $(GTK_LDLIBS)

check: all
	@set -e; \
	for test in tests/test-*.sh; do \
		printf '==> %s\n' "$$test"; \
		bash "$$test"; \
	done

clean:
	rm -rf "$(BUILD_DIR)"
