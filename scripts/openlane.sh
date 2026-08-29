#!/bin/bash
# ==============================================================================
# openlane.sh — Run OpenLane 2 RTL-to-GDS flow locally via Docker
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== AXI4-Lite Arbiter OpenLane 2 RTL-to-GDS ==="

if ! command -v docker &>/dev/null; then
    echo "[ERROR] Docker is not installed or not in PATH."
    echo "        Docker is required to run the OpenLane 2 flow locally."
    echo "        Install Docker Desktop or Docker Engine."
    exit 1
fi

# Use a default volare directory in the user's home if not set
VOLARE_DIR="${PDK_ROOT:-$HOME/.volare}"
mkdir -p "$VOLARE_DIR"

if [ ! -f "$PROJ_ROOT/scripts/sv2v" ]; then
    echo "[INFO] Downloading sv2v..."
    curl -sL https://github.com/zachjs/sv2v/releases/download/v0.0.11/sv2v-Linux.zip -o /tmp/sv2v.zip
    unzip -qo /tmp/sv2v.zip -d /tmp/sv2v_bin
    cp /tmp/sv2v_bin/sv2v-Linux/sv2v "$PROJ_ROOT/scripts/"
fi

echo "[INFO] Converting SystemVerilog to Verilog-2005 using sv2v..."
"$PROJ_ROOT/scripts/sv2v" \
    "$PROJ_ROOT/src/rtl/axi4lite_pkg.sv" \
    "$PROJ_ROOT/src/rtl/axi4lite_address_decoder.sv" \
    "$PROJ_ROOT/src/rtl/axi4lite_qos_scheduler.sv" \
    "$PROJ_ROOT/src/rtl/axi4lite_response_router.sv" \
    "$PROJ_ROOT/src/rtl/axi4lite_write_arbiter.sv" \
    "$PROJ_ROOT/src/rtl/axi4lite_read_arbiter.sv" \
    "$PROJ_ROOT/src/rtl/axi4lite_arbiter_top.sv" \
    > "$PROJ_ROOT/openlane/axi4lite_arbiter_top_sv2v.v"

echo "[INFO] Running OpenLane 2 via Docker..."
docker run --rm \
    -v "$PROJ_ROOT":/work \
    -v "$VOLARE_DIR":/root/.volare \
    ghcr.io/efabless/openlane2:2.0.4 \
    bash -c "openlane /work/openlane/config.json && chown -R $(id -u):$(id -g) /work/openlane/runs"

if [ $? -eq 0 ]; then
    echo "=== OpenLane Flow COMPLETE ==="
    echo "Outputs are available in: openlane/runs/"
else
    echo "=== OpenLane Flow FAILED ==="
    exit 1
fi
