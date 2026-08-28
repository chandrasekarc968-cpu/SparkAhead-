# ==============================================================================
# VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter (Root Makefile)
# ==============================================================================
# Convenience wrapper — delegates to scripts/Makefile
# ==============================================================================

SCRIPTS_DIR := scripts

.PHONY: lint sim sim-stress formal synth wave clean all check

# Default target
all: lint sim sim-stress

# Run all checks (CI target)
check: lint sim sim-stress synth

lint:
	$(MAKE) -C $(SCRIPTS_DIR) lint

sim:
	$(MAKE) -C $(SCRIPTS_DIR) sim

sim-stress:
	$(MAKE) -C $(SCRIPTS_DIR) sim-stress

formal:
	$(MAKE) -C $(SCRIPTS_DIR) formal

synth:
	$(MAKE) -C $(SCRIPTS_DIR) synth

wave:
	$(MAKE) -C $(SCRIPTS_DIR) wave

clean:
	$(MAKE) -C $(SCRIPTS_DIR) clean
