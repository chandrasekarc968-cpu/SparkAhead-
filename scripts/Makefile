# ==============================================================================
# Makefile — VELTRAXX'26 PS02 Multi-Master AXI4-Lite Arbiter
# ==============================================================================
# Targets: lint, sim, formal, synth, clean
# ==============================================================================

SHELL       := /bin/bash
TOP         := axi4lite_arbiter_top
RTL_DIR     := src/rtl
TB_SIM_DIR  := tb/sim
TB_TEST_DIR := tb/tests
SDC         := constraints/timing.sdc
LOG_DIR     := logs
OUT_DIR     := outputs

# Collect all RTL sources
RTL_SRCS    := $(wildcard $(RTL_DIR)/*.sv)

# Collect all testbench sources
TB_SRCS     := $(wildcard $(TB_SIM_DIR)/*.sv) $(wildcard $(TB_TEST_DIR)/*.sv)

# ==============================================================================
# Lint — static analysis
# ==============================================================================
.PHONY: lint
lint:
	@mkdir -p $(LOG_DIR)
	@echo "=== Running RTL lint ==="
	@bash scripts/lint.sh $(RTL_SRCS) 2>&1 | tee $(LOG_DIR)/lint.log

# ==============================================================================
# Simulation — compile + elaborate + run
# ==============================================================================
.PHONY: sim
sim:
	@mkdir -p $(LOG_DIR) $(OUT_DIR)
	@echo "=== Running simulation ==="
	@bash scripts/sim.sh $(TOP) "$(RTL_SRCS) $(TB_SRCS)" 2>&1 | tee $(LOG_DIR)/sim.log

# ==============================================================================
# Formal verification
# ==============================================================================
.PHONY: formal
formal:
	@mkdir -p $(LOG_DIR)
	@echo "=== Running formal verification ==="
	@bash scripts/formal.sh $(TOP) "$(RTL_SRCS)" 2>&1 | tee $(LOG_DIR)/formal.log

# ==============================================================================
# Synthesis
# ==============================================================================
.PHONY: synth
synth:
	@mkdir -p $(LOG_DIR) $(OUT_DIR)
	@echo "=== Running synthesis ==="
	@bash scripts/synth.sh $(TOP) "$(RTL_SRCS)" $(SDC) $(OUT_DIR) 2>&1 | tee $(LOG_DIR)/synth.log

# ==============================================================================
# Clean
# ==============================================================================
.PHONY: clean
clean:
	@echo "=== Cleaning build artifacts ==="
	rm -rf $(LOG_DIR)/*
	rm -rf $(OUT_DIR)/*
	@echo "Done."
