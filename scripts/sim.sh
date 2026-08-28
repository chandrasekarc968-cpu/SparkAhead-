#!/usr/bin/env bash
# ==============================================================================
# sim.sh — Simulation wrapper
# Project : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
# Usage   : bash scripts/sim.sh <top> <rtl_dir> <tb_sim_dir> <tb_test_dir> <out_dir>
# Tool    : Icarus Verilog (iverilog + vvp)
# ==============================================================================
set -euo pipefail

TOP="${1:-axi4lite_arbiter_top}"
RTL_DIR="${2:-.}"
TB_SIM_DIR="${3:-.}"
TB_TEST_DIR="${4:-.}"
OUT_DIR="${5:-outputs}"

# ---- collect all .sv sources, excluding placeholders ----
shopt -s nullglob
ALL_SRCS=()
for dir in "$RTL_DIR" "$TB_SIM_DIR" "$TB_TEST_DIR"; do
    for f in "$dir"/*.sv; do
        [[ "$(basename "$f")" == .gitkeep* ]] && continue
        ALL_SRCS+=("$f")
    done
done
shopt -u nullglob

# ---- guard: no sources ----
if [ ${#ALL_SRCS[@]} -eq 0 ]; then
    echo "SKIPPED: no RTL or testbench sources found."
    echo "         Add .sv files to src/rtl/ and tb/ then re-run."
    exit 0
fi

echo "--- Simulation: top=${TOP}, ${#ALL_SRCS[@]} source file(s) ---"
for f in "${ALL_SRCS[@]}"; do echo "  $f"; done

# ---- try Icarus Verilog ----
if command -v iverilog &>/dev/null; then
    echo "[INFO] Using Icarus Verilog for simulation."
    mkdir -p "$OUT_DIR"
    iverilog -g2012 -o "$OUT_DIR/${TOP}.vvp" "${ALL_SRCS[@]}"
    if command -v vvp &>/dev/null; then
        vvp "$OUT_DIR/${TOP}.vvp"
    else
        echo "[WARNING] iverilog compiled OK but 'vvp' not found — cannot execute."
    fi
    echo "--- Simulation (Icarus): DONE ---"
    exit 0
fi

# ---- nothing available ----
echo "[ERROR] Sources exist but Icarus Verilog (iverilog) is not installed."
echo "        Install it to enable simulation:"
echo "          • Icarus Verilog: https://steveicarus.github.io/iverilog/"
exit 1
