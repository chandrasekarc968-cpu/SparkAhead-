# ==============================================================================
# VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter Makefile (scripts/)
# ==============================================================================
# Targets: lint, sim, sim-stress, formal, synth, wave, clean
# ==============================================================================

SHELL      := /bin/bash
PROJ_ROOT  := $(shell cd .. && pwd)
RTL_DIR    := $(PROJ_ROOT)/src/rtl
TB_DIR     := $(PROJ_ROOT)/tb/sim
FORMAL_DIR := $(PROJ_ROOT)/formal
OUT_DIR    := $(PROJ_ROOT)/build
LOG_DIR    := $(PROJ_ROOT)/logs

# RTL files (order matters: leaf modules first)
RTL_FILES  := "$(RTL_DIR)/axi4lite_pkg.sv" \
              "$(RTL_DIR)/axi4lite_address_decoder.sv" \
              "$(RTL_DIR)/axi4lite_qos_scheduler.sv" \
              "$(RTL_DIR)/axi4lite_response_router.sv" \
              "$(RTL_DIR)/axi4lite_write_arbiter.sv" \
              "$(RTL_DIR)/axi4lite_read_arbiter.sv" \
              "$(RTL_DIR)/axi4lite_arbiter_top.sv"

# Default simulation top
SIM_TOP    ?= tb_axi4lite_arbiter

.PHONY: lint sim sim-stress formal synth openlane wave clean

# --------------------------------------------------------------------------
# Lint: Verilator --lint-only or iverilog syntax-only
# --------------------------------------------------------------------------
lint:
	@mkdir -p $(OUT_DIR) $(LOG_DIR)
	@echo "=== LINT ==="
	@if command -v verilator &>/dev/null; then \
		cd "$(PROJ_ROOT)" && verilator --lint-only -Wall --timing \
			src/rtl/axi4lite_pkg.sv \
			src/rtl/axi4lite_address_decoder.sv \
			src/rtl/axi4lite_qos_scheduler.sv \
			src/rtl/axi4lite_response_router.sv \
			src/rtl/axi4lite_write_arbiter.sv \
			src/rtl/axi4lite_read_arbiter.sv \
			src/rtl/axi4lite_arbiter_top.sv \
			2>&1 | tee "$(LOG_DIR)/lint.log"; \
	elif command -v iverilog &>/dev/null; then \
		iverilog -g2012 -Wall -o /dev/null \
			$(RTL_FILES) \
			2>&1 | tee $(LOG_DIR)/lint.log; \
	else \
		echo "ERROR: No linter found (need verilator or iverilog)"; exit 1; \
	fi
	@echo "=== LINT COMPLETE ==="

# --------------------------------------------------------------------------
# Simulation: Directed regression (46 tests)
# --------------------------------------------------------------------------
sim:
	@mkdir -p $(OUT_DIR) $(LOG_DIR)
	@echo "=== SIMULATION: $(SIM_TOP) ==="
	@if command -v iverilog &>/dev/null; then \
		iverilog -g2012 -Wall -o $(OUT_DIR)/$(SIM_TOP).vvp \
			$(RTL_FILES) $(TB_DIR)/$(SIM_TOP).sv \
			2>&1 | tee $(LOG_DIR)/sim_compile.log; \
		vvp $(OUT_DIR)/$(SIM_TOP).vvp \
			2>&1 | tee $(LOG_DIR)/sim.log; \
	else \
		echo "ERROR: iverilog not found"; exit 1; \
	fi
	@echo "=== SIMULATION COMPLETE ==="

# --------------------------------------------------------------------------
# Stress Simulation: 10,000 random transactions
# --------------------------------------------------------------------------
sim-stress:
	@mkdir -p $(OUT_DIR) $(LOG_DIR)
	@echo "=== STRESS SIMULATION ==="
	@if command -v iverilog &>/dev/null; then \
		iverilog -g2012 -Wall -o $(OUT_DIR)/tb_axi4lite_stress.vvp \
			$(RTL_FILES) $(TB_DIR)/tb_axi4lite_stress.sv \
			2>&1 | tee $(LOG_DIR)/stress_compile.log; \
		vvp $(OUT_DIR)/tb_axi4lite_stress.vvp \
			2>&1 | tee $(LOG_DIR)/stress.log; \
	else \
		echo "ERROR: iverilog not found"; exit 1; \
	fi
	@echo "=== STRESS SIMULATION COMPLETE ==="

# --------------------------------------------------------------------------
# Formal: SymbiYosys BMC
# --------------------------------------------------------------------------
formal:
	@mkdir -p $(OUT_DIR) $(LOG_DIR)
	@echo "=== FORMAL VERIFICATION ==="
	@if command -v sby &>/dev/null; then \
		cd "$(PROJ_ROOT)" && sby -f "$(FORMAL_DIR)/arbiter.sby" \
			2>&1 | tee "$(LOG_DIR)/formal.log"; \
	else \
		echo "ERROR: sby (SymbiYosys) not found"; exit 1; \
	fi
	@echo "=== FORMAL COMPLETE ==="

# --------------------------------------------------------------------------
# Synthesis: Yosys gate-level synthesis
# --------------------------------------------------------------------------
synth:
	@mkdir -p $(OUT_DIR) $(LOG_DIR)
	@echo "=== SYNTHESIS ==="
	@if command -v yosys &>/dev/null; then \
		yosys -p "read_verilog -sv $(RTL_FILES); \
			synth -top axi4lite_arbiter_top; \
			stat; \
			write_verilog $(PROJ_ROOT)/outputs/axi4lite_arbiter_top_netlist.v" \
			2>&1 | tee $(LOG_DIR)/synth.log; \
	else \
		echo "ERROR: yosys not found"; exit 1; \
	fi
	@echo "=== SYNTHESIS COMPLETE ==="

# --------------------------------------------------------------------------
# OpenLane: RTL to GDS Flow via Docker
# --------------------------------------------------------------------------
openlane:
	@mkdir -p "$(OUT_DIR)" "$(LOG_DIR)"
	@echo "=== OPENLANE RTL-TO-GDS ==="
	@bash "$(PROJ_ROOT)/scripts/openlane.sh" 2>&1 | tee "$(LOG_DIR)/openlane.log"
	@echo "=== OPENLANE COMPLETE ==="

# --------------------------------------------------------------------------
# Wave: Open waveform viewer
# --------------------------------------------------------------------------
wave:
	@echo "=== OPENING WAVEFORMS ==="
	@if command -v gtkwave &>/dev/null; then \
		gtkwave $(SIM_TOP).vcd &; \
	else \
		echo "VCD file available: $(SIM_TOP).vcd"; \
		echo "Use gtkwave or similar viewer to open it."; \
	fi

# --------------------------------------------------------------------------
# Clean
# --------------------------------------------------------------------------
clean:
	@echo "=== CLEANING ==="
	rm -rf $(OUT_DIR) *.vcd *.vvp arbiter_bmc arbiter_cover
	rm -f $(PROJ_ROOT)/logs/*.log
	rm -f $(PROJ_ROOT)/outputs/*.v $(PROJ_ROOT)/outputs/*.vvp $(PROJ_ROOT)/outputs/*.log
	@echo "=== CLEAN COMPLETE ==="
