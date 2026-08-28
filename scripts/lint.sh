#!/usr/bin/env bash
# ==============================================================================
# lint.sh — RTL lint wrapper
# Project : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
# Usage   : bash scripts/lint.sh <rtl_dir>
# Tool    : Verilator (preferred) → Icarus syntax-check (fallback)
# ==============================================================================
set -euo pipefail

RTL_DIR="${1:-.}"

# ---- collect .sv / .v files, excluding placeholders ----
shopt -s nullglob
RTL_FILES=()
for f in "$RTL_DIR"/*.sv "$RTL_DIR"/*.v; do
    [[ "$(basename "$f")" == .gitkeep* ]] && continue
    RTL_FILES+=("$f")
done
shopt -u nullglob

# ---- guard: no real RTL sources ----
if [ ${#RTL_FILES[@]} -eq 0 ]; then
    echo "SKIPPED: no RTL sources found in ${RTL_DIR}/"
    echo "         Add .sv files to src/rtl/ and re-run."
    exit 0
fi

echo "--- Lint: checking ${#RTL_FILES[@]} file(s) ---"
for f in "${RTL_FILES[@]}"; do echo "  $f"; done

# ---- try Verilator ----
if command -v verilator &>/dev/null; then
    echo "[INFO] Using Verilator for lint."
    verilator --lint-only -Wall -Wno-fatal "${RTL_FILES[@]}"
    echo "--- Lint (Verilator): PASSED ---"
    exit 0
fi

# ---- try Icarus Verilog syntax check ----
if command -v iverilog &>/dev/null; then
    echo "[INFO] Verilator not found. Falling back to Icarus Verilog syntax check."
    iverilog -g2012 -t null -o /tmp/veltraxx_lint.vvp "${RTL_FILES[@]}"
    echo "--- Lint (Icarus syntax check): PASSED ---"
    exit 0
fi

# ---- nothing available ----
echo "[ERROR] RTL sources exist but neither Verilator nor Icarus Verilog is installed."
echo "        Install one of the following:"
echo "          • Verilator : https://verilator.org"
echo "          • Icarus    : https://steveicarus.github.io/iverilog/"
exit 1
