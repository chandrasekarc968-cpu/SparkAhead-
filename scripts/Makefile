# ==============================================================================
# scripts/Makefile — VELTRAXX'26 PS02 Multi-Master AXI4-Lite Arbiter
# ==============================================================================
#
# ROOT_DIR is derived from CURDIR, which GNU Make sets reliably (even with
# spaces in the path) before any variable expansion.  The root Makefile
# delegates here via $(MAKE) -f scripts/Makefile, so CURDIR is the repo root.
#
# File globbing is NOT done in Make ($(wildcard) is broken with spaces).
# Each wrapper script receives *directories* and globs internally in bash.
#
# ==============================================================================

SHELL      := /bin/bash

# ---- repository root = caller's working directory ----
ROOT_DIR   := $(CURDIR)

# ---- configurable top module ----
TOP        ?= axi4lite_arbiter_top

# ---- directory layout (all absolute via CURDIR) ----
RTL_DIR     = $(ROOT_DIR)/src/rtl
TB_SIM_DIR  = $(ROOT_DIR)/tb/sim
TB_TEST_DIR = $(ROOT_DIR)/tb/tests
SDC         = $(ROOT_DIR)/constraints/timing.sdc
LOG_DIR     = $(ROOT_DIR)/logs
OUT_DIR     = $(ROOT_DIR)/outputs
SCRIPT_DIR  = $(ROOT_DIR)/scripts

# ==============================================================================
# Lint — static analysis
# ==============================================================================
.PHONY: lint
lint:
	@mkdir -p '$(LOG_DIR)'
	@echo "=== Running RTL lint ==="
	@bash '$(SCRIPT_DIR)/lint.sh' '$(RTL_DIR)' 2>&1 | tee '$(LOG_DIR)/lint.log'

# ==============================================================================
# Simulation — compile + elaborate + run
# ==============================================================================
.PHONY: sim
sim:
	@mkdir -p '$(LOG_DIR)' '$(OUT_DIR)'
	@echo "=== Running simulation ==="
	@bash '$(SCRIPT_DIR)/sim.sh' '$(TOP)' '$(RTL_DIR)' '$(TB_SIM_DIR)' '$(TB_TEST_DIR)' '$(OUT_DIR)' 2>&1 | tee '$(LOG_DIR)/sim.log'

# ==============================================================================
# Formal verification
# ==============================================================================
.PHONY: formal
formal:
	@mkdir -p '$(LOG_DIR)'
	@echo "=== Running formal verification ==="
	@bash '$(SCRIPT_DIR)/formal.sh' '$(TOP)' '$(RTL_DIR)' 2>&1 | tee '$(LOG_DIR)/formal.log'

# ==============================================================================
# Synthesis
# ==============================================================================
.PHONY: synth
synth:
	@mkdir -p '$(LOG_DIR)' '$(OUT_DIR)'
	@echo "=== Running synthesis ==="
	@bash '$(SCRIPT_DIR)/synth.sh' '$(TOP)' '$(RTL_DIR)' '$(SDC)' '$(OUT_DIR)' 2>&1 | tee '$(LOG_DIR)/synth.log'

# ==============================================================================
# Clean
# ==============================================================================
.PHONY: clean
clean:
	@echo "=== Cleaning build artifacts ==="
	@rm -rf '$(LOG_DIR)'/*
	@rm -rf '$(OUT_DIR)'/*
	@echo "Done."
