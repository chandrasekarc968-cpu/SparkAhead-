#!/usr/bin/env bash
# ==============================================================================
# formal.sh — Formal verification wrapper
# Project : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
# Usage   : bash scripts/formal.sh <top_module> "<rtl_files>"
# Fallback: SymbiYosys → clear install message
# ==============================================================================
set -euo pipefail

TOP="${1:-}"
SRCS="${2:-}"

# ---------- guard: no sources ----------
if [ -z "$SRCS" ] || [ -z "$(echo "$SRCS" | xargs)" ]; then
    echo "[SKIPPED] formal — no RTL source files found."
    echo "          Add .sv files to src/rtl/ and re-run."
    exit 0
fi

echo "--- Formal: top=${TOP} ---"
echo "    Sources: ${SRCS}"

# ---------- try SymbiYosys ----------
if command -v sby &>/dev/null; then
    echo "[INFO] Using SymbiYosys for formal verification."
    # SymbiYosys expects a .sby job file. Generate a minimal one on the fly.
    SBY_FILE="/tmp/veltraxx_formal_${TOP}.sby"
    cat > "${SBY_FILE}" <<-EOF
	[options]
	mode bmc
	depth 20

	[engines]
	smtbmc z3

	[script]
	read -formal -sv ${SRCS}
	prep -top ${TOP}

	[files]
	${SRCS}
	EOF
    sby -f "${SBY_FILE}"
    echo "--- Formal (SymbiYosys): DONE ---"
    exit 0
fi

# ---------- nothing available ----------
echo "[SKIPPED] formal — SymbiYosys (sby) not found on PATH."
echo "          Install the oss-cad-suite to enable formal verification:"
echo "            • SymbiYosys : https://github.com/YosysHQ/sby"
echo "            • oss-cad-suite: https://github.com/YosysHQ/oss-cad-suite-build"
echo "          Requires: yosys, sby, and an SMT solver (z3 or yices2)."
exit 0
