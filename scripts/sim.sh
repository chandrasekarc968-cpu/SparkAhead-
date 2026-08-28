#!/usr/bin/env bash
# ==============================================================================
# sim.sh — Simulation wrapper
# Project : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
# Usage   : bash scripts/sim.sh <top_module> "<source_files>"
# ==============================================================================
set -euo pipefail

TOP="$1"
SRCS="$2"

echo "--- Simulation: top=${TOP} ---"

# TODO: Replace the commands below with your simulator invocation.
# Examples (Verilator):
#   verilator --cc --exe --build -Wall ${SRCS} --top-module ${TOP}
#   ./obj_dir/V${TOP}
#
# Examples (Icarus Verilog):
#   iverilog -g2012 -o outputs/${TOP}.vvp ${SRCS}
#   vvp outputs/${TOP}.vvp
#
# Examples (Synopsys VCS):
#   vcs -sverilog -full64 -debug_access+all ${SRCS} -top ${TOP} -o outputs/${TOP}.simv
#   ./outputs/${TOP}.simv
#
# Examples (Cadence Xcelium):
#   xrun -sv -access +rwc ${SRCS} -top ${TOP}
echo "[TODO] Insert simulation tool commands here."

echo "--- Simulation: complete ---"
