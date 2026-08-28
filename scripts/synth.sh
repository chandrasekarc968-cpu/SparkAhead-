#!/usr/bin/env bash
# ==============================================================================
# synth.sh — Synthesis wrapper
# Project : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
# Usage   : bash scripts/synth.sh <top> <rtl_dir> <sdc_file> <out_dir>
# Tool    : Yosys
# ==============================================================================
set -euo pipefail

TOP="${1:-axi4lite_arbiter_top}"
RTL_DIR="${2:-.}"
SDC="${3:-}"
OUT_DIR="${4:-outputs}"

# ---- collect .sv / .v files, excluding placeholders ----
shopt -s nullglob
RTL_FILES=()
for f in "$RTL_DIR"/*.sv "$RTL_DIR"/*.v; do
    [[ "$(basename "$f")" == .gitkeep* ]] && continue
    RTL_FILES+=("$f")
done
shopt -u nullglob

# ---- guard: no sources ----
if [ ${#RTL_FILES[@]} -eq 0 ]; then
    echo "SKIPPED: no RTL sources found in ${RTL_DIR}/"
    echo "         Add .sv files to src/rtl/ and re-run."
    exit 0
fi

echo "--- Synthesis: top=${TOP}, ${#RTL_FILES[@]} source file(s) ---"
for f in "${RTL_FILES[@]}"; do echo "  $f"; done
echo "    SDC    : ${SDC:-<none>}"
echo "    Output : ${OUT_DIR}"

# ---- try Yosys ----
if command -v yosys &>/dev/null; then
    echo "[INFO] Using Yosys for synthesis."
    mkdir -p "$OUT_DIR"

    # Build Yosys read commands
    YOSYS_CMDS=""
    for src in "${RTL_FILES[@]}"; do
        YOSYS_CMDS="${YOSYS_CMDS}read_verilog -sv \"${src}\"; "
    done
    YOSYS_CMDS="${YOSYS_CMDS}synth -top ${TOP}; write_verilog \"${OUT_DIR}/${TOP}_netlist.v\""

    yosys -p "$YOSYS_CMDS"
    if [ -f "${OUT_DIR}/${TOP}_netlist.v" ]; then
        echo "--- Synthesis (Yosys): SUCCESS ---"
        echo "    Netlist: ${OUT_DIR}/${TOP}_netlist.v"
        exit 0
    else
        echo "[ERROR] Yosys synthesis ran but failed to produce expected netlist ${OUT_DIR}/${TOP}_netlist.v"
        exit 1
    fi
fi

# ---- nothing available ----
echo "[ERROR] RTL sources exist but Yosys is not installed."
echo "        Install the oss-cad-suite to enable synthesis:"
echo "          • Yosys         : https://github.com/YosysHQ/yosys"
echo "          • oss-cad-suite : https://github.com/YosysHQ/oss-cad-suite-build"
exit 1
