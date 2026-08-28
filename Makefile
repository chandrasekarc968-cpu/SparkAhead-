# ==============================================================================
# Root Makefile — VELTRAXX'26 PS02 Multi-Master AXI4-Lite Arbiter
# ==============================================================================
# Delegates all targets to scripts/Makefile so the build flow works from
# the repository root via: make lint | sim | formal | synth | clean
# ==============================================================================

SHELL := /bin/bash

TARGETS := lint sim formal synth clean

.PHONY: $(TARGETS)

$(TARGETS):
	@$(MAKE) -f scripts/Makefile $@
