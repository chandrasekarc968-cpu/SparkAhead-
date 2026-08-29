#!/usr/bin/env bash
# ==============================================================================
# check_config.sh — OpenLane config.json sanity checker
# Project : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
# Usage   : bash scripts/check_config.sh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG="${PROJ_ROOT}/openlane/config.json"

echo "=== OpenLane Config Sanity Check ==="
echo "  Config: ${CONFIG}"
echo ""

ERRORS=0
WARNS=0

check_key() {
    local key="$1"
    local required="${2:-true}"
    if grep -q "\"${key}\"" "$CONFIG" 2>/dev/null; then
        local val
        val=$(grep "\"${key}\"" "$CONFIG" | head -1 | sed 's/.*: *//;s/[",]//g;s/^ *//;s/ *$//')
        echo "  [OK]   ${key} = ${val}"
    elif [ "$required" = "true" ]; then
        echo "  [FAIL] ${key} is MISSING (required)"
        ERRORS=$((ERRORS + 1))
    else
        echo "  [WARN] ${key} is not set (optional)"
        WARNS=$((WARNS + 1))
    fi
}

# Check config file exists
if [ ! -f "$CONFIG" ]; then
    echo "[FAIL] Config file not found: $CONFIG"
    exit 1
fi

# Check required keys
echo "Required fields:"
check_key "DESIGN_NAME"
check_key "VERILOG_FILES"
check_key "CLOCK_PORT"
check_key "CLOCK_PERIOD"

echo ""
echo "PDK fields:"
check_key "PDK" "false"
check_key "STD_CELL_LIBRARY" "false"

echo ""
echo "Signoff settings:"
check_key "QUIT_ON_SETUP_VIOLATIONS" "false"
check_key "QUIT_ON_HOLD_VIOLATIONS" "false"
check_key "QUIT_ON_LVS_ERROR" "false"
check_key "QUIT_ON_DRC_ERROR" "false"

# Check SDC file
echo ""
echo "Constraint files:"
SDC_REL=$(grep '"SDC_FILE"' "$CONFIG" 2>/dev/null | sed 's/.*"dir::\(.*\)".*/\1/' | head -1)
if [ -n "$SDC_REL" ]; then
    SDC_ABS="${PROJ_ROOT}/openlane/${SDC_REL}"
    if [ -f "$SDC_ABS" ]; then
        echo "  [OK]   SDC_FILE resolves to: ${SDC_ABS}"
    else
        echo "  [FAIL] SDC_FILE '${SDC_REL}' does not resolve to a file"
        echo "         Expected: ${SDC_ABS}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "  [WARN] SDC_FILE not found in config"
    WARNS=$((WARNS + 1))
fi

# Check sv2v output
echo ""
echo "Preprocessed Verilog:"
SV2V_FILE="${PROJ_ROOT}/openlane/axi4lite_arbiter_top_sv2v.v"
if [ -f "$SV2V_FILE" ]; then
    local_size=$(stat -c%s "$SV2V_FILE" 2>/dev/null || stat -f%z "$SV2V_FILE" 2>/dev/null || echo "?")
    echo "  [OK]   sv2v output exists: ${SV2V_FILE} (${local_size} bytes)"
else
    echo "  [WARN] sv2v output not found: ${SV2V_FILE}"
    echo "         The OpenLane script (openlane.sh) will generate it automatically."
    WARNS=$((WARNS + 1))
fi

# Summary
echo ""
echo "=== Summary: ${ERRORS} error(s), ${WARNS} warning(s) ==="
if [ "$ERRORS" -gt 0 ]; then
    echo "[FAIL] Config has errors. Fix them before running OpenLane."
    exit 1
else
    echo "[PASS] Config looks good."
    exit 0
fi
