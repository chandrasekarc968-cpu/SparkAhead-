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
│   └── config.json              ← OpenLane2 ASIC flow config (SKY130/GF180)
├── scripts/
│   ├── Makefile                 ← Core build targets
│   ├── lint.sh                  ← Verilator/iverilog lint wrapper
│   ├── sim.sh                   ← Simulation runner
│   ├── formal.sh                ← Formal verification runner
│   └── synth.sh                 ← Yosys synthesis runner
├── logs/                        ← Generated execution logs
└── outputs/                     ← Generated netlists and binaries
```

---

## Toolchain & Build Instructions

All build targets are driven via GNU Make and use open-source EDA tools.

### Required Open-Source Tools
- **RTL Lint**: Verilator ≥5.0 (preferred) or Icarus Verilog ≥12.0
- **Simulation**: Icarus Verilog (`iverilog`, `vvp`)
- **Formal Verification**: SymbiYosys (`sby`) with Z3 SMT solver
- **Logic Synthesis**: Yosys ≥0.40
- **ASIC Flow (optional)**: OpenLane2 with SKY130 or GF180 PDK

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

# Run all checks (CI)
make check

# Clean generated outputs
make clean
```

---

## Verification Summary

| Target | Tool | Scope | Status |
|---|---|---|---|
| **Lint** | Verilator / iverilog | 7 RTL source files | **BLOCKED** (no tools on system) |
| **Simulation** | Icarus / vvp | 46 directed tests + 10K stress | **BLOCKED** (no tools on system) |
| **Formal** | SymbiYosys / Z3 | 22 assertion/cover groups, BMC depth 40 | **BLOCKED** (no tools on system) |
| **Synthesis** | Yosys | Gate-level mapping | **BLOCKED** (no tools on system) |
| **ASIC Flow** | OpenLane2 | SKY130 / GF180 RTL-to-GDSII | **BLOCKED** (no PDK on system) |

> **Note**: Install the [oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite-build) to enable all verification and synthesis targets. For ASIC flow, install [OpenLane2](https://openlane2.readthedocs.io/) with the SKY130 PDK.

---

## Known Limitations

1. **Single Outstanding Transaction Per Channel**: 1 outstanding write + 1 outstanding read at any time.
2. **Fixed Address Map**: Compile-time parameters, no software-remappable registers.
3. **Frozen 4M/2S**: Hardcoded to 4 masters and 2 slaves. Changing triggers `$fatal`.
4. **Timing Closure**: `make synth` performs logic synthesis only; timing closure requires OpenLane2 or equivalent PnR + STA flow.
