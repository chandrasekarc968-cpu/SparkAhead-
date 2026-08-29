# ==============================================================================
# VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter Makefile (scripts/)
# ==============================================================================
# Targets: lint, sim, sim-stress, formal, synth, pnr, openlane,
#          rtl-to-gds, showcase, check-config, wave, clean
# ==============================================================================

SHELL      := /bin/bash
PROJ_ROOT  := $(shell cd .. && pwd)
RTL_DIR    := $(PROJ_ROOT)/src/rtl
TB_DIR     := $(PROJ_ROOT)/tb/sim
FORMAL_DIR := $(PROJ_ROOT)/formal
OUT_DIR    := $(PROJ_ROOT)/outputs
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

.PHONY: lint sim sim-stress formal synth pnr openlane rtl-to-gds showcase check-config wave clean

# --------------------------------------------------------------------------
# Lint: Verilator --lint-only or iverilog syntax-only
# --------------------------------------------------------------------------
lint:
	@mkdir -p "$(OUT_DIR)" "$(LOG_DIR)"
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
			2>&1 | tee "$(LOG_DIR)/lint.log"; \
	else \
		echo "ERROR: No linter found (need verilator or iverilog)"; exit 1; \
	fi
	@echo "=== LINT COMPLETE ==="

# --------------------------------------------------------------------------
# Simulation: Directed regression (46 tests)
# --------------------------------------------------------------------------
sim:
	@mkdir -p "$(OUT_DIR)" "$(LOG_DIR)"
	@echo "=== SIMULATION: $(SIM_TOP) ==="
	@if command -v iverilog &>/dev/null; then \
		cd "$(PROJ_ROOT)" && iverilog -g2012 -Wall -o outputs/$(SIM_TOP).vvp \
			src/rtl/axi4lite_pkg.sv \
			src/rtl/axi4lite_address_decoder.sv \
			src/rtl/axi4lite_qos_scheduler.sv \
			src/rtl/axi4lite_response_router.sv \
			src/rtl/axi4lite_write_arbiter.sv \
			src/rtl/axi4lite_read_arbiter.sv \
			src/rtl/axi4lite_arbiter_top.sv \
			tb/sim/$(SIM_TOP).sv \
			2>&1 | tee "$(LOG_DIR)/sim_compile.log"; \
		cd "$(PROJ_ROOT)" && vvp outputs/$(SIM_TOP).vvp \
			2>&1 | tee "$(LOG_DIR)/sim.log"; \
	else \
		echo "ERROR: iverilog not found"; exit 1; \
	fi
	@echo "=== SIMULATION COMPLETE ==="

# --------------------------------------------------------------------------
# Stress Simulation: 10,000 random transactions
# --------------------------------------------------------------------------
sim-stress:
	@mkdir -p "$(OUT_DIR)" "$(LOG_DIR)"
	@echo "=== STRESS SIMULATION ==="
	@if command -v iverilog &>/dev/null; then \
		cd "$(PROJ_ROOT)" && iverilog -g2012 -Wall -o outputs/tb_axi4lite_stress.vvp \
			src/rtl/axi4lite_pkg.sv \
			src/rtl/axi4lite_address_decoder.sv \
			src/rtl/axi4lite_qos_scheduler.sv \
			src/rtl/axi4lite_response_router.sv \
			src/rtl/axi4lite_write_arbiter.sv \
			src/rtl/axi4lite_read_arbiter.sv \
			src/rtl/axi4lite_arbiter_top.sv \
			tb/sim/tb_axi4lite_stress.sv \
			2>&1 | tee "$(LOG_DIR)/stress_compile.log"; \
		cd "$(PROJ_ROOT)" && vvp outputs/tb_axi4lite_stress.vvp \
			2>&1 | tee "$(LOG_DIR)/stress.log"; \
	else \
		echo "ERROR: iverilog not found"; exit 1; \
	fi
	@echo "=== STRESS SIMULATION COMPLETE ==="

# --------------------------------------------------------------------------
# Formal: SymbiYosys BMC
# --------------------------------------------------------------------------
formal:
	@mkdir -p "$(OUT_DIR)" "$(LOG_DIR)"
	@echo "=== FORMAL VERIFICATION ==="
	@if command -v sby &>/dev/null; then \
		FORMAL_TMP=$$(mktemp -d /tmp/sparkahead_formal_XXXXXX); \
		cp -r "$(PROJ_ROOT)/src" "$(PROJ_ROOT)/formal" "$$FORMAL_TMP/"; \
		cd "$$FORMAL_TMP" && sby -f formal/arbiter.sby \
			2>&1 | tee "$(LOG_DIR)/formal.log"; \
		rm -rf "$$FORMAL_TMP"; \
	else \
		echo "ERROR: sby (SymbiYosys) not found"; exit 1; \
	fi
	@echo "=== FORMAL COMPLETE ==="

# --------------------------------------------------------------------------
# Synthesis: Yosys gate-level synthesis (with optional tech mapping)
# --------------------------------------------------------------------------
synth:
	@mkdir -p "$(OUT_DIR)" "$(LOG_DIR)"
	@echo "=== SYNTHESIS ==="
	@bash "$(PROJ_ROOT)/scripts/synth.sh" \
		axi4lite_arbiter_top \
		"$(RTL_DIR)" \
		"$(PROJ_ROOT)/constraints/timing.sdc" \
		"$(OUT_DIR)"
	@echo "=== SYNTHESIS COMPLETE ==="

# --------------------------------------------------------------------------
# PnR / OpenLane: RTL to GDS Flow via Docker
# --------------------------------------------------------------------------
pnr: openlane

openlane:
	@mkdir -p "$(OUT_DIR)" "$(LOG_DIR)"
	@echo "=== OPENLANE RTL-TO-GDS ==="
	@bash "$(PROJ_ROOT)/scripts/openlane.sh" 2>&1 | tee "$(LOG_DIR)/openlane.log"
	@echo "=== OPENLANE COMPLETE ==="

# --------------------------------------------------------------------------
# RTL-to-GDS: Full flow (lint + sim + formal + OpenLane)
# --------------------------------------------------------------------------
rtl-to-gds:
	@echo "=== FULL RTL-TO-GDS FLOW ==="
	@bash "$(PROJ_ROOT)/scripts/run_rtl_to_gds.sh"
	@echo "=== RTL-TO-GDS COMPLETE ==="

# --------------------------------------------------------------------------
# Check Config: Validate openlane/config.json
# --------------------------------------------------------------------------
check-config:
	@bash "$(PROJ_ROOT)/scripts/check_config.sh"

# --------------------------------------------------------------------------
# Showcase: Lightweight demo — runs lint + sim, displays metrics
# --------------------------------------------------------------------------
showcase:
	@echo "================================================================"
	@echo "  VELTRAXX'26 PS02 — AXI4-Lite Arbiter Showcase"
	@echo "================================================================"
	@echo ""
	@echo "--- Design Hierarchy ---"
	@echo "  Top Module : axi4lite_arbiter_top"
	@echo "    ├── axi4lite_write_arbiter"
	@echo "    │   ├── axi4lite_qos_scheduler"
	@echo "    │   └── axi4lite_address_decoder"
	@echo "    ├── axi4lite_read_arbiter"
	@echo "    │   ├── axi4lite_qos_scheduler"
	@echo "    │   └── axi4lite_address_decoder"
	@echo "    └── axi4lite_response_router"
	@echo ""
	@echo "--- RTL Sources ---"
	@echo "  Source files: $$(cd "$(PROJ_ROOT)" && ls -1 src/rtl/*.sv 2>/dev/null | wc -l) SystemVerilog files"
	@cd "$(PROJ_ROOT)" && ls -1 src/rtl/*.sv 2>/dev/null | while IFS= read -r f; do echo "    $$(basename "$$f")"; done
	@echo ""
	@echo "--- Lint Check ---"
	@$(MAKE) lint 2>&1 | tail -3
	@echo ""
	@echo "--- Simulation ---"
	@if command -v iverilog &>/dev/null; then \
		$(MAKE) sim 2>&1 | tail -5; \
	else \
		echo "  [SKIP] iverilog not available"; \
	fi
	@echo ""
	@echo "--- Physical Design Metrics ---"
	@METRICS="$(PROJ_ROOT)/logs/openlane_metrics.json"; \
	if [ -f "$$METRICS" ]; then \
		CELLS=$$(grep '"design__instance__count"' "$$METRICS" 2>/dev/null | head -1 | grep -o '[0-9]*' | head -1); \
		AREA=$$(grep '"design__instance__area"' "$$METRICS" 2>/dev/null | head -1 | grep -o '[0-9.]*' | head -1); \
		SETUP=$$(grep '"timing__setup__ws"' "$$METRICS" 2>/dev/null | head -1 | grep -o '[-0-9.]*' | head -1); \
		HOLD=$$(grep '"timing__hold__ws"' "$$METRICS" 2>/dev/null | head -1 | grep -o '[-0-9.]*' | head -1); \
		DRC_M=$$(grep '"magic__drc_error__count"' "$$METRICS" 2>/dev/null | head -1 | grep -o '[0-9]*' | head -1); \
		LVS=$$(grep '"design__lvs_error__count"' "$$METRICS" 2>/dev/null | head -1 | grep -o '[0-9]*' | head -1); \
		echo "  Cell count      : $${CELLS:-NOT AVAILABLE}"; \
		echo "  Area (μm²)      : $${AREA:-NOT AVAILABLE}"; \
		echo "  Setup slack (ns): $${SETUP:-NOT AVAILABLE}"; \
		echo "  Hold slack (ns) : $${HOLD:-NOT AVAILABLE}"; \
		echo "  DRC errors      : $${DRC_M:-NOT AVAILABLE}"; \
		echo "  LVS errors      : $${LVS:-NOT AVAILABLE}"; \
	else \
		echo "  Cell count      : NOT AVAILABLE (run 'make openlane' first)"; \
		echo "  Area (μm²)      : NOT AVAILABLE"; \
		echo "  Setup slack (ns): NOT AVAILABLE"; \
		echo "  Hold slack (ns) : NOT AVAILABLE"; \
		echo "  DRC errors      : NOT AVAILABLE"; \
		echo "  LVS errors      : NOT AVAILABLE"; \
	fi
	@echo ""
	@echo "--- GDS Output ---"
	@GDS="$(OUT_DIR)/axi4lite_arbiter_top.gds"; \
	if [ -f "$$GDS" ]; then \
		SIZE=$$(stat -c%s "$$GDS" 2>/dev/null || stat -f%z "$$GDS" 2>/dev/null || echo "?"); \
		echo "  GDS: $$GDS ($${SIZE} bytes)"; \
	else \
		echo "  GDS: NOT AVAILABLE (run 'make openlane' to generate)"; \
	fi
	@echo ""
	@echo "================================================================"
	@echo "  Showcase complete"
	@echo "================================================================"

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
	rm -rf "$(OUT_DIR)"/*.vvp "$(OUT_DIR)"/run_*
	rm -f *.vcd *.vvp
	rm -f "$(PROJ_ROOT)/logs"/*.log "$(PROJ_ROOT)/logs"/*.csv "$(PROJ_ROOT)/logs"/*.json
	rm -rf "$(FORMAL_DIR)"/arbiter_bmc "$(FORMAL_DIR)"/arbiter_cover "$(FORMAL_DIR)"/arbiter
	@echo "=== CLEAN COMPLETE ==="
