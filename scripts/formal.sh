#!/usr/bin/env bash
# ==============================================================================
# formal.sh — Run SymbiYosys formal verification
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== AXI4-Lite Arbiter Formal Verification ==="
echo "  Config:    formal/arbiter.sby"
echo "  BMC depth: 40 cycles"
echo "  Solver:    Z3"

if command -v sby &>/dev/null; then
    cd "$PROJ_ROOT"
    sby -f formal/arbiter.sby
    echo "Formal verification complete."
else
    echo "ERROR: sby (SymbiYosys) not found."
    echo ""
    echo "Required commands:"
    echo "  sby -f formal/arbiter.sby"
    echo ""
    echo "Install SymbiYosys:"
    echo "  oss-cad-suite: https://github.com/YosysHQ/oss-cad-suite-build"
    echo "  Manual:        https://github.com/YosysHQ/sby"
    echo ""
    echo "Formal verification was NOT run. This is NOT a pass."
    exit 1
fi
