SHELL := /bin/bash
CC ?= cc
CPPFLAGS += -D_DEFAULT_SOURCE $(shell pkg-config --cflags raylib)
CFLAGS ?= -O2
CFLAGS += -std=c11 -Wall -Wextra -Wpedantic -Wconversion -Wshadow -Wformat=2 -Werror
LDLIBS += $(shell pkg-config --libs raylib) -lX11 -lm

BUILD_DIR := build
RENDERER := $(BUILD_DIR)/xfce-plasma-renderer
RENDERER_SOURCE := src/renderer/main.c

.PHONY: all renderer check clean
all: renderer

renderer: $(RENDERER)

$(BUILD_DIR):
	mkdir -p "$@"

$(RENDERER): $(RENDERER_SOURCE) | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) "$<" -o "$@" $(LDLIBS)

check: renderer
	@set -e; \
	for test in tests/test-*.sh; do \
		printf '==> %s\n' "$$test"; \
		bash "$$test"; \
	done

clean:
	rm -rf "$(BUILD_DIR)"
