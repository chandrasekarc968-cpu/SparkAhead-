# VELTRAXX'26 — PS02: Multi-Master AXI4-Lite Arbiter

## Overview

A synthesisable **4-master, 2-slave shared-bus AXI4-Lite interconnect** designed for the VELTRAXX'26 hardware hackathon (Problem Statement 02).

The arbiter sits between four AXI4-Lite master ports and two AXI4-Lite slave ports, multiplexing requests onto a single shared bus with full protocol compliance (ARM IHI 0022E).

## Key Micro-Architecture Features

| Feature | Description |
|---|---|
| **Independent Read/Write Arbitration** | Separate arbiters for the read channel (AR/R) and write channel (AW/W/B), allowing concurrent read and write grants to different masters. |
| **Weighted Round-Robin Scheduling** | Each master carries a programmable weight; the scheduler cycles through masters proportionally. |
| **Master 0 Preemption** | Master 0 can preempt an in-progress arbitration round when its priority flag is asserted (low-latency path for a real-time controller). |
| **Anti-Starvation Aging** | Waiting masters accumulate age credits every cycle; once a threshold is reached the aged master is promoted to highest priority, preventing indefinite starvation. |
| **Hardcoded Address Decoding** | Slave address regions are compile-time parameters — no register-based remapping — yielding zero-latency decode. |
| **DECERR Handling** | Accesses that fall outside any valid slave region receive an AXI `DECERR` (decode error) response generated internally by a default-slave shim. |

## Directory Layout

```
.
├── README.md                  ← You are here
├── docs/
│   ├── architecture.md        ← Micro-architecture specification
│   └── verification-plan.md   ← Verification & coverage strategy
├── src/
│   └── rtl/                   ← Synthesisable RTL (SystemVerilog)
├── tb/
│   ├── sim/                   ← Simulation infrastructure (drivers, monitors, scoreboards)
│   └── tests/                 ← Directed & constrained-random test sequences
├── constraints/
│   └── timing.sdc             ← SDC timing constraints template
├── scripts/
│   ├── Makefile               ← Top-level build targets
│   ├── lint.sh                ← RTL lint wrapper
│   ├── sim.sh                 ← Simulation wrapper
│   ├── formal.sh              ← Formal verification wrapper
│   └── synth.sh               ← Synthesis wrapper
├── logs/                      ← Tool log outputs (git-ignored)
├── outputs/                   ← Synthesis / sim artefacts (git-ignored)
└── presentation/              ← Final hackathon presentation material
```

## Quick Start

```bash
# Lint the RTL
make lint

# Run simulation
make sim

# Run formal checks
make formal

# Synthesise
make synth

# Clean all outputs
make clean
```

> **Status:** Skeleton only — RTL, testbench, and tooling commands are TODO.

## Licence

This project is developed for the VELTRAXX'26 hackathon and is provided as-is for educational purposes.
