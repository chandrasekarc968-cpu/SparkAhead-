#!/usr/bin/env bash
# ==============================================================================
# sim.sh — Run directed or stress simulation
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_ROOT="$(dirname "$SCRIPT_DIR")"

SIM_TOP="${1:-tb_axi4lite_arbiter}"
OUT_DIR="$PROJ_ROOT/build"

mkdir -p "$OUT_DIR"

RTL_FILES=(
    "$PROJ_ROOT/src/rtl/axi4lite_pkg.sv"
    "$PROJ_ROOT/src/rtl/age_counter.sv"
    "$PROJ_ROOT/src/rtl/write_mux.sv"
    "$PROJ_ROOT/src/rtl/read_mux.sv"
    "$PROJ_ROOT/src/rtl/default_slave.sv"
    "$PROJ_ROOT/src/rtl/addr_decoder.sv"
    "$PROJ_ROOT/src/rtl/wrr_scheduler.sv"
    "$PROJ_ROOT/src/rtl/resp_demux.sv"
    "$PROJ_ROOT/src/rtl/write_arbiter.sv"
    "$PROJ_ROOT/src/rtl/read_arbiter.sv"
    "$PROJ_ROOT/src/rtl/axi4lite_arbiter_top.sv"
)

# Find testbench file
TB_FILE=""
for dir in "$PROJ_ROOT/tb/sim" "$PROJ_ROOT/tb/tests"; do
    if [ -f "$dir/${SIM_TOP}.sv" ]; then
        TB_FILE="$dir/${SIM_TOP}.sv"
        break
    fi
done

if [ -z "$TB_FILE" ]; then
    echo "ERROR: Testbench '$SIM_TOP.sv' not found in tb/sim/ or tb/tests/"
    exit 1
fi

echo "=== AXI4-Lite Arbiter Simulation ==="
echo "  Top:  $SIM_TOP"
echo "  TB:   $TB_FILE"

if command -v iverilog &>/dev/null; then
    echo "Compiling with iverilog..."
    iverilog -g2012 -Wall -o "$OUT_DIR/${SIM_TOP}.vvp" \
        "${RTL_FILES[@]}" "$TB_FILE"
    echo "Running simulation..."
    cd "$PROJ_ROOT"
    vvp "$OUT_DIR/${SIM_TOP}.vvp"
    echo "Simulation complete."
else
    echo "ERROR: iverilog not found. Install Icarus Verilog."
    echo "  Ubuntu/Debian: sudo apt install iverilog"
    echo "  macOS:         brew install icarus-verilog"
    echo "  Windows:       https://bleyer.org/icarus/"
    echo "  oss-cad-suite: https://github.com/YosysHQ/oss-cad-suite-build"
    exit 1
fi
