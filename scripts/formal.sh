#!/usr/bin/env bash
# ==============================================================================
# formal.sh — Formal verification wrapper
# Project : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
# Usage   : bash scripts/formal.sh <top> <rtl_dir> <root_dir>
# Tool    : SymbiYosys (sby) — only when a real .sby file exists
# ==============================================================================
set -euo pipefail

export PATH="/home/herald/.local/bin:$HOME/.local/bin:$PATH"

TOP="${1:-axi4lite_arbiter_top}"
RTL_DIR="${2:-.}"
ROOT_DIR="${3:-.}"

# ---- check if any real .sby file exists ----
shopt -s nullglob
SBY_FILES=(
    "$ROOT_DIR"/formal/*.sby
    "$ROOT_DIR"/*.sby
    "$ROOT_DIR"/scripts/*.sby
    "$ROOT_DIR"/tb/formal/*.sby
)
shopt -u nullglob

if [ ${#SBY_FILES[@]} -eq 0 ]; then
    echo "SKIPPED: no formal (.sby) configuration file found."
    echo "         Create a .sby file to enable SymbiYosys formal verification."
    exit 0
fi

echo "--- Formal: found ${#SBY_FILES[@]} .sby configuration(s) ---"
for f in "${SBY_FILES[@]}"; do echo "  $f"; done

# ---- try SymbiYosys ----
if command -v sby &>/dev/null; then
    echo "[INFO] Using SymbiYosys for formal verification."
    for sby_file in "${SBY_FILES[@]}"; do
        echo "[INFO] Running sby -f ${sby_file}"
        sby -f "$sby_file"
    done
    echo "--- Formal (SymbiYosys): PASSED ---"
    exit 0
fi

# ---- nothing available ----
echo "[ERROR] Formal configuration exists but SymbiYosys (sby) is not installed."
echo "        Install the oss-cad-suite to enable formal verification:"
echo "          • SymbiYosys    : https://github.com/YosysHQ/sby"
echo "          • oss-cad-suite : https://github.com/YosysHQ/oss-cad-suite-build"
echo "        Requires: yosys, sby, and an SMT solver (z3 or yices2)."
exit 1
