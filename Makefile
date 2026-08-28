# ==============================================================================
# Root Makefile — VELTRAXX'26 PS02 Multi-Master AXI4-Lite Arbiter
# ==============================================================================
# Delegates all targets to scripts/Makefile.
# Usage:  make lint | make sim | make formal | make synth | make clean
# ==============================================================================

.PHONY: lint sim formal synth clean

lint sim formal synth clean:
	$(MAKE) -f scripts/Makefile $@
