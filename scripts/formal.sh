#!/usr/bin/env bash
# ==============================================================================
# formal.sh — Formal verification wrapper
# Project : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
# Usage   : bash scripts/formal.sh <top> <rtl_dir>
# Tool    : SymbiYosys (sby)
# ==============================================================================
set -euo pipefail

TOP="${1:-axi4lite_arbiter_top}"
RTL_DIR="${2:-.}"

# ---- collect .sv files, excluding placeholders ----
shopt -s nullglob
RTL_FILES=()
for f in "$RTL_DIR"/*.sv; do
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

echo "--- Formal: top=${TOP}, ${#RTL_FILES[@]} source file(s) ---"
for f in "${RTL_FILES[@]}"; do echo "  $f"; done

# ---- try SymbiYosys ----
if command -v sby &>/dev/null; then
    echo "[INFO] Using SymbiYosys for formal verification."

    # Build read commands and file list for the .sby job
    READ_CMDS=""
    FILE_LIST=""
    for src in "${RTL_FILES[@]}"; do
        READ_CMDS="${READ_CMDS}read -formal -sv $(basename "$src")"$'\n'
        FILE_LIST="${FILE_LIST}${src}"$'\n'
    done

    SBY_FILE="/tmp/veltraxx_formal_${TOP}.sby"
    cat > "$SBY_FILE" <<EOF
[options]
mode bmc
depth 20

[engines]
smtbmc z3

[script]
${READ_CMDS}prep -top ${TOP}

[files]
${FILE_LIST}
EOF
    sby -f "$SBY_FILE"
    echo "--- Formal (SymbiYosys): DONE ---"
    exit 0
fi

# ---- nothing available ----
echo "[ERROR] RTL sources exist but SymbiYosys (sby) is not installed."
echo "        Install the oss-cad-suite to enable formal verification:"
echo "          • SymbiYosys    : https://github.com/YosysHQ/sby"
echo "          • oss-cad-suite : https://github.com/YosysHQ/oss-cad-suite-build"
echo "        Requires: yosys, sby, and an SMT solver (z3 or yices2)."
exit 1
