#!/bin/bash
# ==============================================================================
# formal.sh — Run SymbiYosys formal verification
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== AXI4-Lite Arbiter Formal Verification ==="

if command -v sby &>/dev/null; then
    cd "$PROJ_ROOT"
    sby -f formal/arbiter.sby
    echo "Formal verification complete."
else
    echo "ERROR: sby (SymbiYosys) not found."
    echo "Install: https://github.com/YosysHQ/sby"
    exit 1
fi
