SHELL := /bin/bash

.PHONY: check
check:
	@set -e; \
	for test in tests/test-*.sh; do \
		printf '==> %s\n' "$$test"; \
		bash "$$test"; \
	done
