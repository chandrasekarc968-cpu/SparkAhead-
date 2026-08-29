#!/usr/bin/env bash
# ==============================================================================
# lint.sh — Lint all RTL source files
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_ROOT="$(dirname "$SCRIPT_DIR")"

RTL_FILES=(
    "$PROJ_ROOT/src/rtl/axi4lite_pkg.sv"
    "$PROJ_ROOT/src/rtl/age_counter.sv"
    "$PROJ_ROOT/src/rtl/write_mux.sv"
    "$PROJ_ROOT/src/rtl/read_mux.sv"
    "$PROJ_ROOT/src/rtl/default_slave.sv"
    "$PROJ_ROOT/src/rtl/addr_decoder.sv"
    "$PROJ_ROOT/src/rtl/wrr_scheduler.sv"
    "$PROJ_ROOT/src/rtl/resp_demux.sv"
    "$PROJ_ROOT/src/rtl/write_arbiter.sv"
    "$PROJ_ROOT/src/rtl/read_arbiter.sv"
    "$PROJ_ROOT/src/rtl/axi4lite_arbiter_top.sv"
)

echo "=== AXI4-Lite Arbiter Lint ==="
echo "  RTL files: ${#RTL_FILES[@]}"

if command -v verilator &>/dev/null; then
    echo "Using verilator..."
    verilator --lint-only -Wall --timing "${RTL_FILES[@]}"
    echo "Lint PASSED (verilator)"
elif command -v iverilog &>/dev/null; then
    echo "Using iverilog syntax check..."
    iverilog -g2012 -Wall -o /dev/null "${RTL_FILES[@]}"
    echo "Lint PASSED (iverilog)"
else
    echo "ERROR: No linter found. Install verilator or iverilog."
    echo "  verilator: https://verilator.org"
    echo "  iverilog:  https://steveicarus.github.io/iverilog/"
    echo "  oss-cad-suite: https://github.com/YosysHQ/oss-cad-suite-build"
    exit 1
fi
