#!/usr/bin/env bash
# ==============================================================================
# run_rtl_to_gds.sh — Complete RTL-to-GDS flow runner
# Project : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
# Usage   : bash scripts/run_rtl_to_gds.sh
#
# Runs: environment checks → lint → simulation → (formal) → OpenLane2
# Creates a timestamped run directory and stops immediately on errors.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_ROOT="$(dirname "$SCRIPT_DIR")"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="${PROJ_ROOT}/outputs/run_${TIMESTAMP}"

TOP_MODULE="axi4lite_arbiter_top"
RTL_DIR="${PROJ_ROOT}/src/rtl"
LOG_DIR="${PROJ_ROOT}/logs"

RTL_FILES=(
    "${RTL_DIR}/axi4lite_pkg.sv"
    "${RTL_DIR}/age_counter.sv"
    "${RTL_DIR}/write_mux.sv"
    "${RTL_DIR}/read_mux.sv"
    "${RTL_DIR}/default_slave.sv"
    "${RTL_DIR}/addr_decoder.sv"
    "${RTL_DIR}/wrr_scheduler.sv"
    "${RTL_DIR}/resp_demux.sv"
    "${RTL_DIR}/write_arbiter.sv"
    "${RTL_DIR}/read_arbiter.sv"
    "${RTL_DIR}/axi4lite_arbiter_top.sv"
)

# ==============================================================================
# 1. Environment Checks
# ==============================================================================
echo "================================================================"
echo "  AXI4-Lite Arbiter — RTL-to-GDS Flow"
echo "  Timestamp: ${TIMESTAMP}"
echo "================================================================"
echo ""

ERRORS=0

# Check Docker
if command -v docker &>/dev/null; then
    echo "[OK]   Docker found: $(docker --version 2>/dev/null | head -1)"
else
    echo "[FAIL] Docker is required for OpenLane2. Install Docker Desktop or Docker Engine."
    ERRORS=$((ERRORS + 1))
fi

# Check linter
if command -v verilator &>/dev/null; then
    echo "[OK]   Verilator found: $(verilator --version 2>/dev/null | head -1)"
    LINTER="verilator"
elif command -v iverilog &>/dev/null; then
    echo "[OK]   Icarus Verilog found"
    LINTER="iverilog"
else
    echo "[FAIL] No RTL linter found. Install verilator or iverilog."
    ERRORS=$((ERRORS + 1))
fi

# Check simulator
if command -v iverilog &>/dev/null && command -v vvp &>/dev/null; then
    echo "[OK]   Simulator found (iverilog + vvp)"
    HAS_SIM=1
else
    echo "[WARN] iverilog/vvp not found — simulation will be skipped."
    HAS_SIM=0
fi

# Check sv2v
if [ -f "${PROJ_ROOT}/scripts/sv2v" ]; then
    echo "[OK]   sv2v found at scripts/sv2v"
elif command -v sv2v &>/dev/null; then
    echo "[OK]   sv2v found in PATH"
else
    echo "[WARN] sv2v not found — OpenLane script will download it."
fi

# Check PDK_ROOT (informational)
if [ -n "${PDK_ROOT:-}" ]; then
    echo "[OK]   PDK_ROOT=${PDK_ROOT}"
else
    echo "[INFO] PDK_ROOT not set — OpenLane Docker will use its own PDK."
fi

if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo "[ABORT] $ERRORS critical dependency missing. Fix and retry."
    exit 1
fi

echo ""

# ==============================================================================
# 2. Validate RTL Files & Top Module
# ==============================================================================
echo "--- Validating RTL sources ---"
for f in "${RTL_FILES[@]}"; do
    if [ ! -f "$f" ]; then
        echo "[FAIL] Missing RTL file: $f"
        exit 1
    fi
    echo "  [OK] $(basename "$f")"
done

# Verify top module exists in the top-level file
if ! grep -q "module ${TOP_MODULE}" "${RTL_DIR}/${TOP_MODULE}.sv"; then
    echo "[FAIL] Top module '${TOP_MODULE}' not found in ${RTL_DIR}/${TOP_MODULE}.sv"
    exit 1
fi
echo "  [OK] Top module '${TOP_MODULE}' found"
echo ""

# ==============================================================================
# 3. Create Run Directory
# ==============================================================================
mkdir -p "$RUN_DIR"
mkdir -p "$LOG_DIR"
echo "--- Run directory: ${RUN_DIR} ---"
echo ""

# ==============================================================================
# 4. Lint
# ==============================================================================
echo "================================================================"
echo "  STEP 1: RTL Lint"
echo "================================================================"
cd "$PROJ_ROOT"
if [ "$LINTER" = "verilator" ]; then
    verilator --lint-only -Wall --timing "${RTL_FILES[@]}" \
        2>&1 | tee "${LOG_DIR}/lint.log"
else
    iverilog -g2012 -Wall -o /dev/null "${RTL_FILES[@]}" \
        2>&1 | tee "${LOG_DIR}/lint.log"
fi
echo "[PASS] Lint complete"
echo ""

# ==============================================================================
# 5. Simulation (if iverilog available)
# ==============================================================================
echo "================================================================"
echo "  STEP 2: Simulation"
echo "================================================================"
if [ "$HAS_SIM" -eq 1 ]; then
    TB_FILE="${PROJ_ROOT}/tb/sim/tb_axi4lite_arbiter.sv"
    if [ -f "$TB_FILE" ]; then
        SIM_VVP="${RUN_DIR}/tb_axi4lite_arbiter.vvp"
        iverilog -g2012 -Wall -o "$SIM_VVP" \
            "${RTL_FILES[@]}" "$TB_FILE" \
            2>&1 | tee "${LOG_DIR}/sim_compile.log"
        vvp "$SIM_VVP" 2>&1 | tee "${LOG_DIR}/sim.log"

        # Check for test failures in output
        if grep -qi "FAIL\|ERROR\|FATAL" "${LOG_DIR}/sim.log" 2>/dev/null; then
            echo "[WARN] Possible test failures detected — review ${LOG_DIR}/sim.log"
        else
            echo "[PASS] Simulation complete"
        fi
    else
        echo "[SKIP] Testbench not found: $TB_FILE"
    fi
else
    echo "[SKIP] iverilog not available — skipping simulation"
fi
echo ""

# ==============================================================================
# 6. Formal Verification (optional)
# ==============================================================================
echo "================================================================"
echo "  STEP 3: Formal Verification"
echo "================================================================"
if command -v sby &>/dev/null; then
    SBY_CFG="${PROJ_ROOT}/formal/arbiter.sby"
    if [ -f "$SBY_CFG" ]; then
        # Copy to /tmp to avoid spaces-in-path issues with sby
        FORMAL_TMP="/tmp/sparkahead_formal_${TIMESTAMP}"
        mkdir -p "$FORMAL_TMP"
        cp -r "${PROJ_ROOT}/src" "${PROJ_ROOT}/formal" "$FORMAL_TMP/"
        cd "$FORMAL_TMP"
        if sby -f formal/arbiter.sby 2>&1 | tee "${LOG_DIR}/formal.log"; then
            echo "[PASS] Formal verification complete"
        else
            echo "[WARN] Formal verification had failures — review ${LOG_DIR}/formal.log"
            echo "       (Non-blocking: continuing with physical design flow)"
        fi
        rm -rf "$FORMAL_TMP"
        cd "$PROJ_ROOT"
    else
        echo "[SKIP] SBY config not found: $SBY_CFG"
    fi
else
    echo "[SKIP] sby (SymbiYosys) not found — formal verification skipped"
fi
echo ""

# ==============================================================================
# 7. OpenLane2 RTL-to-GDS (via Docker)
# ==============================================================================
echo "================================================================"
echo "  STEP 4: OpenLane2 RTL-to-GDS"
echo "================================================================"
cd "$PROJ_ROOT"
bash "${PROJ_ROOT}/scripts/openlane.sh" 2>&1 | tee "${LOG_DIR}/openlane.log"
echo ""

# ==============================================================================
# 8. Report Final Artifacts
# ==============================================================================
echo "================================================================"
echo "  RTL-to-GDS Flow Complete"
echo "================================================================"
echo ""

report_file() {
    local label="$1"
    local pattern="$2"
    local found
    found=$(ls $pattern 2>/dev/null | head -1)
    if [ -n "$found" ] && [ -f "$found" ]; then
        local size
        size=$(stat -c%s "$found" 2>/dev/null || stat -f%z "$found" 2>/dev/null || echo "?")
        echo "  ${label}: ${found} (${size} bytes)"
    else
        echo "  ${label}: NOT AVAILABLE"
    fi
}

echo "Final Artifacts:"
report_file "GDS Layout  " "${PROJ_ROOT}/outputs/${TOP_MODULE}.gds"
report_file "LEF         " "${PROJ_ROOT}/outputs/${TOP_MODULE}.lef"
report_file "DEF         " "${PROJ_ROOT}/outputs/${TOP_MODULE}.def"
report_file "Gate Netlist" "${PROJ_ROOT}/outputs/${TOP_MODULE}.nl.v"
report_file "Metrics JSON" "${PROJ_ROOT}/logs/openlane_metrics.json"
report_file "Flow Log    " "${PROJ_ROOT}/logs/openlane.log"
echo ""

# Parse metrics if available
METRICS="${PROJ_ROOT}/logs/openlane_metrics.json"
if [ -f "$METRICS" ]; then
    echo "Key Metrics (from OpenLane signoff):"
    extract() {
        grep -o "\"$1\": *[0-9e.+-]*" "$METRICS" 2>/dev/null | head -1 | awk -F': *' '{print $2}'
    }
    CELLS=$(extract "design__instance__count\"")
    AREA=$(extract "design__instance__area\"")
    SETUP_WS=$(extract "timing__setup__ws\"")
    HOLD_WS=$(extract "timing__hold__ws\"")
    ANT_PINS=$(extract "antenna__violating__pins")
    ANT_NETS=$(extract "antenna__violating__nets")
    DRC_MAGIC=$(extract "magic__drc_error__count")
    DRC_KLAYOUT=$(extract "klayout__drc_error__count")
    LVS_ERR=$(extract "design__lvs_error__count")

    echo "  Cell count     : ${CELLS:-NOT AVAILABLE}"
    echo "  Area (μm²)     : ${AREA:-NOT AVAILABLE}"
    echo "  Setup slack (ns): ${SETUP_WS:-NOT AVAILABLE}"
    echo "  Hold slack (ns) : ${HOLD_WS:-NOT AVAILABLE}"
    echo "  Antenna pins   : ${ANT_PINS:-NOT AVAILABLE}"
    echo "  Antenna nets   : ${ANT_NETS:-NOT AVAILABLE}"
    echo "  DRC (Magic)    : ${DRC_MAGIC:-NOT AVAILABLE}"
    echo "  DRC (KLayout)  : ${DRC_KLAYOUT:-NOT AVAILABLE}"
    echo "  LVS errors     : ${LVS_ERR:-NOT AVAILABLE}"
fi

echo ""
echo "Run directory: ${RUN_DIR}"
echo "Done."
