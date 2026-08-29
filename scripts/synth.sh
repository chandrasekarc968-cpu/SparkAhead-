#!/usr/bin/env bash
# ==============================================================================
# synth.sh — Synthesis wrapper with optional sky130 technology mapping
# Project : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
# Usage   : bash scripts/synth.sh <top> <rtl_dir> <sdc_file> <out_dir>
# Tool    : Yosys
#
# When PDK_ROOT is set and points to a sky130A PDK installation, the script
# performs full technology mapping (dfflibmap + abc -liberty) so that all
# flip-flops are mapped to real sky130_fd_sc_hd cells — zero unmapped cells.
#
# When PDK_ROOT is NOT set, generic (technology-independent) synthesis is
# performed and a clear warning is printed about unmapped cells.
# ==============================================================================
set -euo pipefail

TOP="${1:-axi4lite_arbiter_top}"
RTL_DIR="${2:-.}"
SDC="${3:-}"
OUT_DIR="${4:-outputs}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${PROJ_ROOT}/logs"

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
if ! command -v yosys &>/dev/null; then
    echo "[ERROR] RTL sources exist but Yosys is not installed."
    echo "        Install the oss-cad-suite to enable synthesis:"
    echo "          • Yosys         : https://github.com/YosysHQ/yosys"
    echo "          • oss-cad-suite : https://github.com/YosysHQ/oss-cad-suite-build"
    exit 1
fi

echo "[INFO] Using Yosys for synthesis."
mkdir -p "$OUT_DIR"
mkdir -p "$LOG_DIR"

# ---- Locate sky130 liberty file for technology mapping ----
LIBERTY_FILE=""
if [ -n "${PDK_ROOT:-}" ]; then
    # Standard volare / OpenLane PDK layout
    CANDIDATE="${PDK_ROOT}/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
    if [ -f "$CANDIDATE" ]; then
        LIBERTY_FILE="$CANDIDATE"
        echo "[INFO] Found sky130 liberty: $LIBERTY_FILE"
    else
        echo "[WARN] PDK_ROOT is set ($PDK_ROOT) but liberty file not found at:"
        echo "       $CANDIDATE"
        echo "       Falling back to generic (unmapped) synthesis."
    fi
fi

# ---- Build Yosys command sequence ----
YOSYS_CMDS=""
for src in "${RTL_FILES[@]}"; do
    YOSYS_CMDS="${YOSYS_CMDS}read_verilog -sv \"${src}\"; "
done
YOSYS_CMDS="${YOSYS_CMDS}hierarchy -check -top ${TOP}; "
YOSYS_CMDS="${YOSYS_CMDS}proc; opt; synth -top ${TOP}; "

if [ -n "$LIBERTY_FILE" ]; then
    # Technology mapping: eliminates $_DFF_PN0_, $_DFF_PN1_, $_DFFSR_* etc.
    YOSYS_CMDS="${YOSYS_CMDS}dfflibmap -liberty \"${LIBERTY_FILE}\"; "
    YOSYS_CMDS="${YOSYS_CMDS}abc -liberty \"${LIBERTY_FILE}\"; "
    YOSYS_CMDS="${YOSYS_CMDS}opt_clean -purge; "
    echo "[INFO] Technology mapping to sky130_fd_sc_hd cells enabled."
else
    echo "[WARN] No PDK liberty file found. Performing GENERIC synthesis."
    echo "       The netlist will contain unmapped cells (\$_DFF_PN0_ etc.)."
    echo "       Set PDK_ROOT to enable technology mapping."
fi

YOSYS_CMDS="${YOSYS_CMDS}stat; "
YOSYS_CMDS="${YOSYS_CMDS}write_verilog \"${OUT_DIR}/${TOP}_netlist.v\""

# ---- Execute Yosys synthesis ----
yosys -l "${LOG_DIR}/synth.log" -p "$YOSYS_CMDS"

# ---- Verify generated artifact ----
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

# ---- Check for unmapped cells ----
UNMAPPED=$(grep -c '^\s*\$_DFF_\|^\s*\$_DFFSR_\|^\s*\$_DLATCH_' "$NETLIST" 2>/dev/null || true)
if [ "${UNMAPPED:-0}" -gt 0 ]; then
    echo "[WARN] Netlist contains $UNMAPPED unmapped generic cell instance(s)."
    echo "       Root cause: synthesis ran without technology mapping (no PDK_ROOT)."
    echo "       The OpenLane flow handles this automatically."
else
    echo "[INFO] All cells mapped — zero unmapped instances."
fi

echo "--- Synthesis (Yosys): SUCCESS ---"
echo "    Netlist : ${NETLIST}"
echo "    Log     : ${LOG_DIR}/synth.log"
if [ -n "$LIBERTY_FILE" ]; then
    echo "    Mapping : sky130_fd_sc_hd (full technology mapping)"
else
    echo "    Mapping : GENERIC (no PDK — unmapped cells expected)"
fi
echo "    Note    : Logic synthesis completed; SDC timing closure is not claimed."
exit 0
