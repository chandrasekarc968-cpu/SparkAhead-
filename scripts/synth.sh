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
LOG_DIR="${ROOT_DIR:-.}/logs"

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
if [ -n "${SDC}" ] && [ -f "${SDC}" ]; then
    echo "    SDC (Informational) : ${SDC}"
else
    echo "    SDC                 : ${SDC:-<none>}"
fi
echo "    Output Directory    : ${OUT_DIR}"

# ---- try Yosys ----
if command -v yosys &>/dev/null; then
    echo "[INFO] Using Yosys for synthesis."
    mkdir -p "$OUT_DIR"
    mkdir -p "$LOG_DIR"

    # Build explicit synthesis command chain
    YOSYS_CMDS=""
    for src in "${RTL_FILES[@]}"; do
        YOSYS_CMDS="${YOSYS_CMDS}read_verilog -sv \"${src}\"; "
    done
    YOSYS_CMDS="${YOSYS_CMDS}hierarchy -check -top ${TOP}; "
    YOSYS_CMDS="${YOSYS_CMDS}proc; opt; synth -top ${TOP}; "
    YOSYS_CMDS="${YOSYS_CMDS}stat; "
    YOSYS_CMDS="${YOSYS_CMDS}write_verilog \"${OUT_DIR}/${TOP}_netlist.v\""

    # Execute Yosys synthesis and capture full statistics log
    yosys -l "${LOG_DIR}/synth.log" -p "$YOSYS_CMDS"

    # Verify generated artifact
    NETLIST="${OUT_DIR}/${TOP}_netlist.v"
    if [ ! -f "$NETLIST" ]; then
        echo "[ERROR] Yosys synthesis failed: expected netlist '$NETLIST' was not generated."
        exit 1
    fi

    # Verify that the netlist contains the top module definition
    if ! grep -Eq "module +(\\\\?${TOP}|${TOP}) *[\\(;]" "$NETLIST"; then
        echo "[ERROR] Netlist '$NETLIST' was generated but does not contain top module '${TOP}'."
        exit 1
    fi

    echo "--- Synthesis (Yosys): SUCCESS ---"
    echo "    Netlist : ${NETLIST}"
    echo "    Log     : ${LOG_DIR}/synth.log"
    echo "    Note    : Logic synthesis completed; SDC timing closure is not claimed."
    exit 0
fi

# ---- nothing available ----
echo "[ERROR] RTL sources exist but Yosys is not installed."
echo "        Install the oss-cad-suite to enable synthesis:"
echo "          • Yosys         : https://github.com/YosysHQ/yosys"
echo "          • oss-cad-suite : https://github.com/YosysHQ/oss-cad-suite-build"
exit 1
