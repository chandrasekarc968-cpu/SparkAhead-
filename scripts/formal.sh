#!/usr/bin/env bash
# ==============================================================================
# formal.sh — Formal verification wrapper
# Project : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
# Usage   : bash scripts/formal.sh <top_module> "<rtl_files>"
# ==============================================================================
set -euo pipefail

TOP="$1"
SRCS="$2"

echo "--- Formal: top=${TOP} ---"

# TODO: Replace the commands below with your formal verification tool invocation.
# Examples (Synopsys VC Formal):
#   vcf -sverilog ${SRCS} -top ${TOP} -assert
#
# Examples (Cadence JasperGold):
#   jg -batch -tcl formal_run.tcl
#
# Examples (SymbiYosys — open-source):
#   sby -f formal.sby
echo "[TODO] Insert formal verification tool commands here."

echo "--- Formal: complete ---"
