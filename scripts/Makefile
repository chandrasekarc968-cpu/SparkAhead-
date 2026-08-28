# ==============================================================================
# scripts/Makefile — VELTRAXX'26 PS02 Multi-Master AXI4-Lite Arbiter
# ==============================================================================
# Uses relative paths from CURDIR (the repo root) so that paths containing
# spaces (e.g. parent directories) are never word-split by Make.
# ==============================================================================

SHELL       := /bin/bash

TOP         := axi4lite_arbiter_top
RTL_DIR     := src/rtl
TB_SIM_DIR  := tb/sim
TB_TEST_DIR := tb/tests
SDC         := constraints/timing.sdc
LOG_DIR     := logs
OUT_DIR     := outputs
SCRIPT_DIR  := scripts

# Collect all RTL sources (exclude .gitkeep placeholder) — relative paths
RTL_SRCS    := $(filter-out %/.gitkeep.sv,$(wildcard $(RTL_DIR)/*.sv))

# Collect all testbench sources (exclude .gitkeep placeholder) — relative paths
TB_SRCS     := $(filter-out %/.gitkeep.sv,$(wildcard $(TB_SIM_DIR)/*.sv) $(wildcard $(TB_TEST_DIR)/*.sv))

# ==============================================================================
# Lint — static analysis
# ==============================================================================
.PHONY: lint
lint:
	@mkdir -p $(LOG_DIR)
	@echo "=== Running RTL lint ==="
	@bash $(SCRIPT_DIR)/lint.sh $(RTL_SRCS) 2>&1 | tee $(LOG_DIR)/lint.log

# ==============================================================================
# Simulation — compile + elaborate + run
# ==============================================================================
.PHONY: sim
sim:
	@mkdir -p $(LOG_DIR) $(OUT_DIR)
	@echo "=== Running simulation ==="
	@bash $(SCRIPT_DIR)/sim.sh "$(TOP)" "$(RTL_SRCS) $(TB_SRCS)" "$(OUT_DIR)" 2>&1 | tee $(LOG_DIR)/sim.log

# ==============================================================================
# Formal verification
# ==============================================================================
.PHONY: formal
formal:
	@mkdir -p $(LOG_DIR)
	@echo "=== Running formal verification ==="
	@bash $(SCRIPT_DIR)/formal.sh "$(TOP)" "$(RTL_SRCS)" 2>&1 | tee $(LOG_DIR)/formal.log

# ==============================================================================
# Synthesis
# ==============================================================================
.PHONY: synth
synth:
	@mkdir -p $(LOG_DIR) $(OUT_DIR)
	@echo "=== Running synthesis ==="
	@bash $(SCRIPT_DIR)/synth.sh "$(TOP)" "$(RTL_SRCS)" "$(SDC)" "$(OUT_DIR)" 2>&1 | tee $(LOG_DIR)/synth.log

# ==============================================================================
# Clean
# ==============================================================================
.PHONY: clean
clean:
	@echo "=== Cleaning build artifacts ==="
	rm -rf $(LOG_DIR)/*
	rm -rf $(OUT_DIR)/*
	@echo "Done."
