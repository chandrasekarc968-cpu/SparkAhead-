#!/usr/bin/env bash
# ==============================================================================
# synth.sh — Synthesis wrapper
# Project : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
# Usage   : bash scripts/synth.sh <top_module> "<rtl_files>" <sdc_file> <output_dir>
# Fallback: Yosys → clear install message
# ==============================================================================
set -euo pipefail

TOP="${1:-}"
SRCS="${2:-}"
SDC="${3:-}"
OUT_DIR="${4:-outputs}"

# ---------- guard: no sources ----------
if [ -z "$SRCS" ] || [ -z "$(echo "$SRCS" | xargs)" ]; then
    echo "[SKIPPED] synth — no RTL source files found."
    echo "          Add .sv files to src/rtl/ and re-run."
    exit 0
fi

echo "--- Synthesis: top=${TOP} ---"
echo "    Sources: ${SRCS}"
echo "    SDC    : ${SDC}"
echo "    Output : ${OUT_DIR}"

# ---------- try Yosys ----------
if command -v yosys &>/dev/null; then
    echo "[INFO] Using Yosys for synthesis."
    mkdir -p "${OUT_DIR}"

    # Build a Yosys command string from the source list
    READ_CMDS=""
    # shellcheck disable=SC2086
    for src in ${SRCS}; do
        READ_CMDS="${READ_CMDS} read_verilog -sv ${src};"
    done

    yosys -p "${READ_CMDS} synth -top ${TOP}; write_verilog ${OUT_DIR}/${TOP}_netlist.v"
    echo "--- Synthesis (Yosys): DONE ---"
    echo "    Netlist: ${OUT_DIR}/${TOP}_netlist.v"
    exit 0
fi

# ---------- nothing available ----------
echo "[SKIPPED] synth — Yosys not found on PATH."
echo "          Install the oss-cad-suite to enable synthesis:"
echo "            • Yosys         : https://github.com/YosysHQ/yosys"
echo "            • oss-cad-suite : https://github.com/YosysHQ/oss-cad-suite-build"
exit 0
