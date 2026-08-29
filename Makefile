# Root Makefile for VELTRAXX'26 PS02
# Forwards all targets to scripts/Makefile

.DEFAULT_GOAL := help

%:
	@$(MAKE) -f scripts/Makefile $@

help:
	@echo "VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter"
	@echo ""
	@echo "Available targets:"
	@echo "  lint        - Run syntax checks (Verilator/Icarus)"
	@echo "  sim         - Run directed simulation testbench"
	@echo "  sim-stress  - Run random stress simulation"
	@echo "  formal      - Run SymbiYosys formal verification"
	@echo "  synth       - Run Yosys synthesis"
	@echo "  pnr         - Run OpenLane PnR flow"
	@echo "  showcase    - Run lightweight demo"
	@echo "  clean       - Remove generated files"
