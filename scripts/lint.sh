#!/usr/bin/env bash
# ==============================================================================
# lint.sh — RTL lint wrapper
# Project : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
# Usage   : bash scripts/lint.sh <rtl_files...>
# ==============================================================================
set -euo pipefail

RTL_FILES=("$@")

if [ ${#RTL_FILES[@]} -eq 0 ]; then
    echo "[ERROR] No RTL files provided."
    exit 1
fi

echo "--- Lint: checking ${#RTL_FILES[@]} file(s) ---"

# TODO: Replace the command below with your EDA linter invocation.
# Examples:
#   verilator --lint-only -Wall -Wno-fatal "${RTL_FILES[@]}"
#   spyglass  -goal lint_rtl -source "${RTL_FILES[@]}"
#   slang     --lint-only "${RTL_FILES[@]}"
echo "[TODO] Insert lint tool command here."

echo "--- Lint: complete ---"
