# ==============================================================================
# VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter (Root Makefile)
# ==============================================================================
# Convenience wrapper — delegates to scripts/Makefile
# ==============================================================================

SCRIPTS_DIR := scripts

.PHONY: lint sim sim-stress formal synth pnr openlane rtl-to-gds showcase check-config wave clean all check

# Default target
all: lint sim sim-stress

# Run all checks (CI target)
check: lint sim sim-stress formal synth openlane

# --------------------------------------------------------------------------
# Verification targets
# --------------------------------------------------------------------------
lint:
	$(MAKE) -C $(SCRIPTS_DIR) lint

sim:
	$(MAKE) -C $(SCRIPTS_DIR) sim

sim-stress:
	$(MAKE) -C $(SCRIPTS_DIR) sim-stress

formal:
	$(MAKE) -C $(SCRIPTS_DIR) formal

# --------------------------------------------------------------------------
# Synthesis & Physical Design
# --------------------------------------------------------------------------
synth:
	$(MAKE) -C $(SCRIPTS_DIR) synth

pnr:
	$(MAKE) -C $(SCRIPTS_DIR) pnr

openlane:
	$(MAKE) -C $(SCRIPTS_DIR) openlane

rtl-to-gds:
	$(MAKE) -C $(SCRIPTS_DIR) rtl-to-gds

# --------------------------------------------------------------------------
# Demo & Utilities
# --------------------------------------------------------------------------
showcase:
	$(MAKE) -C $(SCRIPTS_DIR) showcase

check-config:
	$(MAKE) -C $(SCRIPTS_DIR) check-config

wave:
	$(MAKE) -C $(SCRIPTS_DIR) wave

clean:
	$(MAKE) -C $(SCRIPTS_DIR) clean
