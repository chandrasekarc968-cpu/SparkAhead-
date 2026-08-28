# ==============================================================================
# scripts/Makefile — VELTRAXX'26 PS02 Multi-Master AXI4-Lite Arbiter
# ==============================================================================
#
# ROOT_DIR is derived from the location of this Makefile, ensuring correct path
# resolution regardless of the caller's working directory.
#
# ==============================================================================

SHELL       := /bin/bash

# Derive scripts directory and repo root directory from this Makefile's path.
# Handle paths with spaces by passing $(MAKEFILE_LIST) as a single quoted argument.
THIS_MAKEFILE := $(MAKEFILE_LIST)
ROOT_DIR      := $(shell python3 -c "import os, sys; print(os.path.abspath(os.path.join(os.path.dirname(sys.argv[1].strip()), '..')))" '$(THIS_MAKEFILE)' 2>/dev/null || (cd "$$(dirname "$(THIS_MAKEFILE)")/.." 2>/dev/null && pwd) || pwd)

# Configurable top-level module
TOP         ?= axi4lite_arbiter_top

# Directory layout
RTL_DIR     := $(ROOT_DIR)/src/rtl
TB_SIM_DIR  := $(ROOT_DIR)/tb/sim
TB_TEST_DIR := $(ROOT_DIR)/tb/tests
SDC         := $(ROOT_DIR)/constraints/timing.sdc
LOG_DIR     := $(ROOT_DIR)/logs
OUT_DIR     := $(ROOT_DIR)/outputs
SCRIPT_DIR  := $(ROOT_DIR)/scripts

# ==============================================================================
# Targets
# ==============================================================================
.PHONY: lint sim formal synth clean

lint:
	@mkdir -p '$(LOG_DIR)'
	@echo "=== Running RTL lint ==="
	@bash '$(SCRIPT_DIR)/lint.sh' '$(RTL_DIR)' 2>&1 | tee '$(LOG_DIR)/lint.log'

sim:
	@mkdir -p '$(LOG_DIR)' '$(OUT_DIR)'
	@echo "=== Running simulation ==="
	@bash '$(SCRIPT_DIR)/sim.sh' '$(TOP)' '$(RTL_DIR)' '$(TB_SIM_DIR)' '$(TB_TEST_DIR)' '$(OUT_DIR)' 2>&1 | tee '$(LOG_DIR)/sim.log'

formal:
	@mkdir -p '$(LOG_DIR)'
	@echo "=== Running formal verification ==="
	@bash '$(SCRIPT_DIR)/formal.sh' '$(TOP)' '$(RTL_DIR)' '$(ROOT_DIR)' 2>&1 | tee '$(LOG_DIR)/formal.log'

synth:
	@mkdir -p '$(LOG_DIR)' '$(OUT_DIR)'
	@echo "=== Running synthesis ==="
	@bash '$(SCRIPT_DIR)/synth.sh' '$(TOP)' '$(RTL_DIR)' '$(SDC)' '$(OUT_DIR)' 2>&1 | tee '$(LOG_DIR)/synth.log'

clean:
	@echo "=== Cleaning build artifacts ==="
	@rm -rf '$(LOG_DIR)'/*
	@rm -rf '$(OUT_DIR)'/*
	@echo "Done."
