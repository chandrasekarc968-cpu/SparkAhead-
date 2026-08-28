#!/usr/bin/env bash
# ==============================================================================
# lint.sh — RTL lint wrapper
# Project : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
# Usage   : bash scripts/lint.sh <rtl_files...>
# Fallback: Verilator → Icarus syntax-check → SKIPPED
# ==============================================================================
set -euo pipefail

RTL_FILES=("$@")

# ---------- guard: no sources ----------
if [ ${#RTL_FILES[@]} -eq 0 ]; then
    echo "[SKIPPED] lint — no RTL source files found in src/rtl/."
    echo "          Add .sv files to src/rtl/ and re-run."
    exit 0
fi

echo "--- Lint: checking ${#RTL_FILES[@]} file(s) ---"
for f in "${RTL_FILES[@]}"; do echo "  $f"; done

# ---------- try Verilator ----------
if command -v verilator &>/dev/null; then
    echo "[INFO] Using Verilator for lint."
    verilator --lint-only -Wall -Wno-fatal "${RTL_FILES[@]}"
    echo "--- Lint (Verilator): PASSED ---"
    exit 0
fi

# ---------- try Icarus Verilog syntax check ----------
if command -v iverilog &>/dev/null; then
    echo "[INFO] Verilator not found. Falling back to Icarus Verilog syntax check."
    iverilog -g2012 -t null "${RTL_FILES[@]}"
    echo "--- Lint (Icarus syntax check): PASSED ---"
    exit 0
fi

# ---------- nothing available ----------
echo "[SKIPPED] lint — neither Verilator nor Icarus Verilog found on PATH."
echo "          Install one of them to enable linting:"
echo "            • Verilator : https://verilator.org"
echo "            • Icarus    : https://steveicarus.github.io/iverilog/"
exit 0
