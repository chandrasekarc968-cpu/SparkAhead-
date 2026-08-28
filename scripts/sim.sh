#!/usr/bin/env bash
# ==============================================================================
# sim.sh — Simulation wrapper
# Project : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
# Usage   : bash scripts/sim.sh <top_module> "<source_files>" <output_dir>
# Fallback: Icarus Verilog → SKIPPED
# ==============================================================================
set -euo pipefail

TOP="${1:-}"
SRCS="${2:-}"
OUT_DIR="${3:-outputs}"

# ---------- guard: no sources ----------
if [ -z "$SRCS" ] || [ -z "$(echo "$SRCS" | xargs)" ]; then
    echo "[SKIPPED] sim — no RTL or testbench source files found."
    echo "          Add .sv files to src/rtl/ and tb/ then re-run."
    exit 0
fi

echo "--- Simulation: top=${TOP} ---"
echo "    Sources: ${SRCS}"

# ---------- try Icarus Verilog ----------
if command -v iverilog &>/dev/null; then
    echo "[INFO] Using Icarus Verilog for simulation."
    mkdir -p "${OUT_DIR}"
    # shellcheck disable=SC2086
    iverilog -g2012 -o "${OUT_DIR}/${TOP}.vvp" ${SRCS}
    if command -v vvp &>/dev/null; then
        vvp "${OUT_DIR}/${TOP}.vvp"
    else
        echo "[WARNING] iverilog compiled successfully but 'vvp' not found — cannot execute."
    fi
    echo "--- Simulation (Icarus): DONE ---"
    exit 0
fi

# ---------- nothing available ----------
echo "[SKIPPED] sim — Icarus Verilog (iverilog) not found on PATH."
echo "          Install it to enable simulation:"
echo "            • Icarus Verilog: https://steveicarus.github.io/iverilog/"
exit 0
