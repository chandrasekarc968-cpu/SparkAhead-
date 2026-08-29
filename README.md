# VELTRAXX'26 — PS02: Multi-Master AXI4-Lite Arbiter

## Overview

A synthesizable, fully verified **4-master, 2-slave shared-bus AXI4-Lite interconnect** designed for the VELTRAXX'26 hardware hackathon (Problem Statement 02).

The arbiter bridges four independent AXI4-Lite master ports and two AXI4-Lite slave ports, multiplexing requests onto a shared interconnect with decoupled read and write arbitration, anti-starvation aging, and internal decode error (`DECERR`) handling in strict compliance with the ARM AXI4-Lite specification (ARM IHI 0022E).

---

## Key Micro-Architecture Features

| Feature | Description |
|---|---|
| **Decoupled Read/Write Paths** | Independent write arbiter/FSM and read arbiter/FSM operate concurrently. Write (AW/W/B) and Read (AR/R) channels can grant different masters in the same cycle. |
| **Weighted Round-Robin (WRR)** | Masters M1–M3 are scheduled with runtime-configurable budget quotas (`cfg_weight_m1`=3, `cfg_weight_m2`=2, `cfg_weight_m3`=1). Quotas decrement on transaction completion. |
| **Per-Master AW/W Skid Buffers** | Each master has independent AW and W buffers that decouple VALID/READY timing. AW and W can arrive in any order without deadlock. |
| **Locked Transaction Ownership** | Once a transaction is accepted, the arbiter locks ownership until the final response handshake (B for writes, R for reads). |
| **Master 0 Priority with Burst Limiting** | M0 has highest priority but is subject to a configurable burst limit (`cfg_master0_burst_limit`). After the limit, M0 is suppressed for one WRR round. |
| **Per-Master Anti-Starvation Aging** | Independent 8-bit saturating age counters for M1, M2, M3. When any master's age exceeds `cfg_age_threshold`, it is promoted above M0 priority. |
| **Combinational Address Decoding** | Zero-latency decode: Slave 0 (`0x0000_0000`–`0x0000_FFFF`), Slave 1 (`0x0001_0000`–`0x0001_FFFF`). |
| **Internal DECERR Generation** | Out-of-bounds accesses return `DECERR` (`2'b11`) with `RDATA=0` internally, isolating external slaves. |
| **Strict Single-Beat Architecture** | AXI4-Lite only — no burst signals or counters. |
| **Frozen 4M/2S Parameterization** | Compile-time assertions enforce `NUM_MASTERS == 4` and `NUM_SLAVES == 2`. |

---

## Directory Layout

```
.
├── README.md                    ← This file
├── Makefile                     ← Top-level wrapper (delegates to scripts/Makefile)
├── .gitignore                   ← Build artifacts, PDK, runs, VCDs
├── docs/
│   ├── architecture.md          ← Detailed micro-architecture specification
│   ├── design-decisions.md      ← Frozen MVP scope & invariants
│   └── verification-plan.md     ← Verification strategy & test matrix
├── src/rtl/                     ← Synthesizable SystemVerilog RTL
│   ├── axi4lite_pkg.sv          ← Package with FSM state types
│   ├── axi4lite_address_decoder.sv ← Combinational address decoder
│   ├── axi4lite_qos_scheduler.sv  ← QoS arbiter (WRR + Aging + M0 Priority)
│   ├── axi4lite_response_router.sv ← Response mux/demux with DECERR generation
│   ├── axi4lite_write_arbiter.sv   ← Write path (AW/W buffers + FSM)
│   ├── axi4lite_read_arbiter.sv    ← Read path (FSM + ownership)
│   └── axi4lite_arbiter_top.sv     ← Top-level interconnect
├── tb/
│   └── sim/                     ← Integration testbenches
│       ├── tb_axi4lite_arbiter.sv   ← 46 directed regression tests
│       └── tb_axi4lite_stress.sv    ← 10,000-txn randomized stress test
├── formal/                      ← SymbiYosys formal verification
│   ├── arbiter.sby              ← SBY config (BMC depth 40 + cover mode)
│   └── arbiter_formal.sv        ← 22 assertion/cover property groups
├── constraints/
│   └── timing.sdc               ← SDC timing constraints (100 MHz)
├── openlane/
│   └── config.json              ← OpenLane2 ASIC flow config (SKY130)
├── scripts/
│   ├── Makefile                 ← Core build targets
│   ├── run_rtl_to_gds.sh       ← Complete RTL-to-GDS flow runner
│   ├── check_config.sh         ← Config sanity checker
│   ├── openlane.sh              ← OpenLane2 Docker wrapper
│   ├── lint.sh                  ← Verilator/iverilog lint wrapper
│   ├── sim.sh                   ← Simulation runner
│   ├── formal.sh                ← Formal verification runner
│   └── synth.sh                 ← Yosys synthesis (with sky130 tech mapping)
├── logs/                        ← Generated execution logs
└── outputs/                     ← Generated netlists, GDS, LEF, DEF
```

---

## Quick Start

```bash
# Run RTL lint check
make lint

# Run 46-test regression suite
make sim

# Run lightweight showcase (lint + sim + display metrics)
make showcase

# Run full RTL-to-GDS flow (requires Docker)
make rtl-to-gds
```

---

## Toolchain & Build Instructions

All build targets are driven via GNU Make and use open-source EDA tools.

### Required Open-Source Tools
- **RTL Lint**: Verilator ≥5.0 (preferred) or Icarus Verilog ≥12.0
- **Simulation**: Icarus Verilog (`iverilog`, `vvp`)
- **Formal Verification**: SymbiYosys (`sby`) with Z3 SMT solver
- **Logic Synthesis**: Yosys ≥0.40
- **ASIC Flow**: OpenLane2 v2.0.4+ with SKY130 PDK (via Docker)

### Ubuntu Setup

#### Option 1: Docker-based OpenLane (Recommended)

This is the simplest path — Docker handles the PDK and all OpenLane dependencies.

```bash
# 1. Install Docker
sudo apt-get update
sudo apt-get install -y docker.io
sudo usermod -aG docker $USER
# Log out and back in for group change to take effect

# 2. Install verification tools (oss-cad-suite)
# Download from https://github.com/YosysHQ/oss-cad-suite-build/releases
# Or install individually:
sudo apt-get install -y verilator iverilog

# 3. Run the flow
make lint           # Lint check
make sim            # Simulation
make openlane       # Full RTL-to-GDS via Docker
```

#### Option 2: Python venv + OpenLane (--dockerized)

> **Note**: OpenLane2's Python package (`openlane`) requires Python 3.10–3.12.
> Python 3.14 is NOT supported due to `libparse` build failures.

```bash
# 1. Create virtual environment
python3.12 -m venv .venv
source .venv/bin/activate

# 2. Install OpenLane
pip install openlane

# 3. Run via Docker backend
python -m openlane --dockerized openlane/config.json

# 4. Or use the provided script
bash scripts/openlane.sh
```

#### Option 3: Nix-based OpenLane

```bash
# 1. Install Nix (multi-user)
sh <(curl -L https://nixos.org/nix/install) --daemon

# 2. Enable flakes
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# 3. Run OpenLane
nix run github:efabless/openlane2 -- openlane/config.json
```

### PDK_ROOT Setup

If running OpenLane natively (not via Docker), set `PDK_ROOT`:

```bash
export PDK_ROOT=$HOME/.volare
# Or wherever your sky130A PDK is installed
```

The Docker-based flow handles PDK installation automatically.

### Build Commands

```bash
# Run RTL Lint
make lint

# Run 46-test directed regression suite
make sim

# Run 10,000-transaction randomized stress test
make sim-stress

# Run formal verification (BMC depth 40 + cover mode)
make formal

# Run Yosys gate-level synthesis
make synth

# Run OpenLane 2 RTL-to-GDS flow via Docker
make openlane
# or equivalently:
make pnr

# Run complete RTL-to-GDS pipeline (lint + sim + formal + OpenLane)
make rtl-to-gds

# Lightweight demo: lint + sim + display design metrics
make showcase

# Validate OpenLane config
make check-config

# Run all checks (CI)
make check

# Clean generated outputs
make clean
```

---

## Verification Summary

| Target | Tool | Scope | Status |
|---|---|---|---|
| **Lint** | Verilator 5.032 | 7 RTL source files, -Wall | ✅ **PASS** (0 warnings) |
| **Simulation** | Icarus Verilog | 46 directed tests + 10K stress | ✅ **PASS** |
| **Formal** | SymbiYosys / Z3 | 22 assertion/cover groups, BMC depth 40 | ✅ **PASS** |
| **Synthesis** | Yosys (OpenLane2) | sky130_fd_sc_hd tech mapping | ✅ **PASS** (0 unmapped cells) |
| **ASIC Flow** | OpenLane2 v2.0.4 | SKY130 RTL-to-GDSII | ✅ **PASS** (DRC ✅, LVS ✅) |

---

## Physical Design Results

| Metric | Value |
|---|---|
| **Target Clock** | 100 MHz (10 ns) |
| **Cell Count** | 16,393 |
| **Area** | 58,311 μm² |
| **Setup Slack** | +1.63 ns (worst corner) |
| **DRC** | 0 errors (Magic + KLayout) |
| **LVS** | 0 errors |
| **Antenna Violations** | 22 pins / 21 nets (non-blocking) |

---

## Known Limitations

1. **Single Outstanding Transaction Per Channel**: 1 outstanding write + 1 outstanding read at any time.
2. **Fixed Address Map**: Compile-time parameters, no software-remappable registers.
3. **Frozen 4M/2S**: Hardcoded to 4 masters and 2 slaves. Changing triggers `$fatal`.
4. **Hold Timing**: Marginal hold violations (~30 ps) on the slowest signoff corner (max_ss_100C_1v60). Non-blocking for tapeout preparation.
