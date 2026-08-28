#!/usr/bin/env bash
# ==============================================================================
# sim.sh — Simulation wrapper
# Project : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
# Usage   : bash scripts/sim.sh <top> <rtl_dir> <tb_sim_dir> <tb_test_dir> <out_dir>
# Tool    : Icarus Verilog (iverilog + vvp)
# ==============================================================================
set -euo pipefail

TOP="${1:-axi4lite_arbiter_top}"
RTL_DIR="${2:-.}"
TB_SIM_DIR="${3:-.}"
TB_TEST_DIR="${4:-.}"
OUT_DIR="${5:-outputs}"

# ---- determine simulation top module ----
if [[ "$TOP" == tb_* ]]; then
    SIM_TOP="$TOP"
elif [ "$TOP" = "axi4lite_arbiter_top" ]; then
    SIM_TOP="tb_axi4lite_arbiter"
elif [ -f "$TB_SIM_DIR/tb_${TOP}.sv" ] || [ -f "$TB_TEST_DIR/tb_${TOP}.sv" ]; then
    SIM_TOP="tb_${TOP}"
else
    SIM_TOP="$TOP"
fi

# ---- collect RTL sources ----
shopt -s nullglob
RTL_SRCS=()
for f in "$RTL_DIR"/*.sv "$RTL_DIR"/*.v; do
    [[ "$(basename "$f")" == .gitkeep* ]] && continue
    RTL_SRCS+=("$f")
done

# ---- collect matching testbench source ----
TB_SRCS=()
for dir in "$TB_SIM_DIR" "$TB_TEST_DIR"; do
    if [ -f "$dir/${SIM_TOP}.sv" ]; then
        TB_SRCS+=("$dir/${SIM_TOP}.sv")
        break
    fi
done

# Fallback: if no specific TB file matched SIM_TOP, include all TB files
if [ ${#TB_SRCS[@]} -eq 0 ]; then
    for dir in "$TB_SIM_DIR" "$TB_TEST_DIR"; do
        for f in "$dir"/*.sv "$dir"/*.v; do
            [[ "$(basename "$f")" == .gitkeep* ]] && continue
            TB_SRCS+=("$f")
        done
    done
fi
shopt -u nullglob

ALL_SRCS=("${RTL_SRCS[@]}" "${TB_SRCS[@]}")

# ---- guard: no sources ----
if [ ${#ALL_SRCS[@]} -eq 0 ]; then
    echo "SKIPPED: no RTL or testbench sources found."
    echo "         Add .sv files to src/rtl/ and tb/ then re-run."
    exit 0
fi

echo "--- Simulation: sim_top=${SIM_TOP} (target=${TOP}), ${#ALL_SRCS[@]} source file(s) ---"
for f in "${ALL_SRCS[@]}"; do echo "  $f"; done

# ---- try Icarus Verilog ----
if command -v iverilog &>/dev/null; then
    echo "[INFO] Using Icarus Verilog for simulation compilation."
    mkdir -p "$OUT_DIR"
    iverilog -g2012 -s "${SIM_TOP}" -o "$OUT_DIR/${SIM_TOP}.vvp" "${ALL_SRCS[@]}"

    if command -v vvp &>/dev/null; then
        echo "[INFO] Running simulation with vvp..."
        SIM_LOG="$OUT_DIR/${SIM_TOP}_sim.log"
        vvp "$OUT_DIR/${SIM_TOP}.vvp" 2>&1 | tee "$SIM_LOG"
        VVP_RC=${PIPESTATUS[0]}
        if [ $VVP_RC -ne 0 ]; then
            echo "[ERROR] Simulation exited with non-zero return code ($VVP_RC)."
            exit 1
        fi
        # Verify at least one real check ran
        if ! grep -q '\[PASS\]' "$SIM_LOG"; then
            echo "[ERROR] Simulation completed but no [PASS] check markers found in output."
            echo "        The testbench must contain assertion checks that print [PASS]."
            exit 1
        fi
        PASS_COUNT=$(grep -c '\[PASS\]' "$SIM_LOG")
        echo "--- Simulation (Icarus/vvp): PASSED ($PASS_COUNT checks verified) ---"
        exit 0
    else
        echo "[ERROR] Simulation compiled to $OUT_DIR/${SIM_TOP}.vvp but 'vvp' runtime is not installed."
        exit 1
    fi
fi

# ---- nothing available ----
echo "[ERROR] Sources exist but Icarus Verilog (iverilog) is not installed."
echo "        Install it to enable simulation:"
echo "          • Icarus Verilog: https://steveicarus.github.io/iverilog/"
exit 1
