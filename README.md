# VELTRAXX'26 — PS02: Multi-Master AXI4-Lite Arbiter

## Overview

A synthesizable, fully verified **4-master, 2-slave shared-bus AXI4-Lite interconnect** designed for the VELTRAXX'26 hardware hackathon (Problem Statement 02).

The arbiter bridges four independent AXI4-Lite master ports and two AXI4-Lite slave ports, multiplexing requests onto a shared interconnect with decoupled read and write arbitration, anti-starvation aging, and internal decode error (`DECERR`) handling in strict compliance with the ARM AXI4-Lite specification (ARM IHI 0022E).

---

## Key Micro-Architecture Features

| Feature | Description |
|---|---|
| **Decoupled Read/Write Paths** | Two dedicated `qos_arbiter` instances operate concurrently. Write (AW/W/B) and Read (AR/R) channels can grant different masters in the exact same cycle. |
| **Weighted Round-Robin (WRR)** | Masters M1, M2, and M3 are scheduled with configurable quotas ($3:2:1$). Quotas decrement upon completed transactions. |
| **Transaction Boundary Preemption** | Master 0 holds highest priority but can only preempt when arbitrating a new transaction in `IDLE`. In-flight transactions are never interrupted. |
| **Anti-Starvation Aging** | Starvation counters track pending lower-priority requests while M0 is active. At the 64-cycle threshold, M0 is suppressed to serve pending masters. |
| **Combinational Address Decoding** | Hardcoded address map with zero pipeline latency: Slave 0 (`0x0000_0000`–`0x0000_FFFF`), Slave 1 (`0x0001_0000`–`0x0001_FFFF`). |
| **Internal DECERR Generation** | Out-of-bounds accesses return AXI `DECERR` (`2'b11`) with zero read data (`RDATA=0`) internally, isolating external slaves. |
| **Strict Single-Beat Architecture** | Designed exclusively for single-beat AXI4-Lite (no burst counters or burst signals). |

---

## Directory Layout

```
.
├── README.md                  ← Top-level documentation & quickstart
├── Makefile                   ← Top-level Makefile wrapper
├── docs/
│   ├── architecture.md        ← Detailed micro-architecture specification
│   ├── design-decisions.md    ← Frozen MVP architectural scope & invariants
│   └── verification-plan.md   ← Verification strategy, assertions & test matrix
├── src/
│   └── rtl/                   ← Synthesizable SystemVerilog RTL
│       ├── addr_decoder.sv    ← Combinational address decoder with DECERR detection
│       ├── qos_arbiter.sv     ← Parameterized QoS arbiter (WRR + Aging + M0 Priority)
│       └── axi4lite_arbiter_top.sv ← Top-level 4M-2S AXI4-Lite Interconnect
├── tb/
│   ├── sim/                   ← Comprehensive top-level integration testbench
│   │   └── tb_axi4lite_arbiter.sv
│   └── tests/                 ← Unit & subsystem directed testbenches
│       ├── tb_addr_decoder.sv
│       ├── tb_qos_arbiter.sv
│       ├── tb_axi4lite_write_path.sv
│       ├── tb_axi4lite_read_path.sv
│       └── tb_axi4lite_concurrent_rw.sv
├── formal/                    ← SymbiYosys formal verification suite
│   ├── arbiter.sby            ← SBY configuration (BMC depth 20, Z3 solver)
│   └── arbiter_formal.sv      ← Formal property harness and assumptions
├── constraints/
│   └── timing.sdc             ← Informational SDC timing constraints template
├── scripts/
│   ├── Makefile               ← Core build flow rules
│   ├── lint.sh                ← Verilator / Icarus lint wrapper
│   ├── sim.sh                 ← Icarus / vvp simulation runner
│   ├── formal.sh              ← SymbiYosys formal runner
│   └── synth.sh               ← Yosys synthesis & netlist generator
├── logs/                      ← Reproducible execution logs (synth.log, etc.)
└── outputs/                   ← Generated gate netlists and VVP binaries
```

---

## Toolchain & Build Instructions

All build targets are driven via GNU Make and use open-source EDA tools.

### Supported Open-Source Tools
- **RTL Lint**: Verilator `5.032` (or Icarus Verilog `12.0`)
- **Simulation**: Icarus Verilog (`iverilog 12.0`) and `vvp` runtime
- **Formal Verification**: SymbiYosys `0.68` (`sby`) with `Z3 5.1.0` SMT solver
- **Logic Synthesis**: Yosys `0.52`

### Exact Build Commands

```bash
# 1. Run RTL Lint (Verilator)
make lint

# 2. Run Comprehensive Simulation Suite (13 tests, 29 assertions)
make sim

# 3. Run Formal Verification (Bounded Model Checking, depth 20)
make formal

# 4. Run RTL Gate Synthesis (Yosys)
make synth

# 5. Clean Generated Outputs and Logs
make clean
```

### Running Specific Testbenches

```bash
TOP=tb_addr_decoder make sim
TOP=tb_qos_arbiter make sim
TOP=tb_axi4lite_write_path make sim
TOP=tb_axi4lite_read_path make sim
TOP=tb_axi4lite_concurrent_rw make sim
```

---

## Verification & Synthesis Results Summary

| Target | Tool | Scope / Test Count | Status |
|---|---|---|---|
| **Lint** | Verilator 5.032 | All RTL files (`src/rtl/*.sv`) | **PASSED** (0 errors, 0 warnings) |
| **Simulation** | Icarus / vvp | 13 Directed Tests (`tb_axi4lite_arbiter.sv`) | **PASSED** (29 assertions checked) |
| **Formal** | SymbiYosys / Z3 | Bounded Model Checking (Depth 20) | **PASSED** (All properties proved) |
| **Synthesis** | Yosys 0.52 | `axi4lite_arbiter_top` Gate Mapping | **SUCCESS** (5384 cells mapped) |

---

## Generated Artifacts

- **Synthesized Netlist**: `outputs/axi4lite_arbiter_top_netlist.v`
- **Simulation Binary**: `outputs/tb_axi4lite_arbiter.vvp`
- **Synthesis Log**: `logs/synth.log`
- **Design Decisions**: `docs/design-decisions.md`

---

## Known Limitations

1. **Single Outstanding Transaction Per Channel**: 1 outstanding write (AW/W/B) and 1 outstanding read (AR/R) at any time. Burst transfers and multiple outstanding addresses on a single channel are not supported by the AXI4-Lite standard.
2. **Fixed Address Map**: Address decoding regions are compile-time parameters without dynamic software remap registers.
3. **Timing Closure**: `make synth` performs standard logic synthesis and cell mapping; SDC timing closure requires physical design (PnR) / static timing analysis (STA) tooling.

---

## Proprietary EDA Tools Note

Proprietary commercial EDA tools (Synopsys VCS / Design Compiler, Cadence Xcelium / Genus, Siemens Questa) are **not required** for this baseline flow. They serve solely as potential downstream integration points for commercial tapeout flows.
