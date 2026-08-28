#!/usr/bin/env bash
# ==============================================================================
# synth.sh — Synthesis wrapper
# Project : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
# Usage   : bash scripts/synth.sh <top_module> "<rtl_files>" <sdc_file> <output_dir>
# ==============================================================================
set -euo pipefail

TOP="$1"
SRCS="$2"
SDC="$3"
OUT_DIR="$4"

echo "--- Synthesis: top=${TOP} ---"

# TODO: Replace the commands below with your synthesis tool invocation.
# Examples (Yosys — open-source):
#   yosys -p "read_verilog -sv ${SRCS}; synth -top ${TOP}; write_verilog ${OUT_DIR}/${TOP}_netlist.v"
#
# Examples (Synopsys Design Compiler):
#   dc_shell -f synth.tcl
#
# Examples (Vivado):
#   vivado -mode batch -source synth.tcl
echo "[TODO] Insert synthesis tool commands here."
echo "       SDC file: ${SDC}"
echo "       Output  : ${OUT_DIR}"

echo "--- Synthesis: complete ---"
