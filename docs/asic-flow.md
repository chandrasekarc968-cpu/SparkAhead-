# ASIC RTL-to-GDSII Flow — AXI4-Lite Arbiter

## Overview

This document describes the ASIC physical design flow for the AXI4-Lite arbiter using the open-source OpenLane2 flow with the SKY130 or GF180 PDK.

---

## Prerequisites

### Required Tools
| Tool | Purpose | Installation |
|---|---|---|
| [OpenLane2](https://openlane2.readthedocs.io/) | RTL-to-GDSII flow orchestration | `pip install openlane` |
| [Yosys](https://github.com/YosysHQ/yosys) | Logic synthesis | Included in oss-cad-suite |
| [OpenROAD](https://github.com/The-OpenROAD-Project) | Floorplanning, placement, CTS, routing | Included in OpenLane |
| [KLayout](https://www.klayout.de/) | DRC, GDS viewer | Included in OpenLane |
| [Magic](http://opencircuitdesign.com/magic/) | DRC, LVS, parasitic extraction | Included in OpenLane |
| [Netgen](http://opencircuitdesign.com/netgen/) | LVS | Included in OpenLane |

### Required PDK
```bash
# SKY130 PDK (recommended)
volare enable --pdk sky130 <version>

# GF180 PDK (alternative)
volare enable --pdk gf180mcu <version>
```

---

## Running the Flow

### Quick Start
```bash
cd openlane/

# SKY130 flow
openlane config.json --pdk sky130A

# GF180 flow
openlane config.json --pdk gf180mcuD
```

### Expected Output Artifacts
```
openlane/runs/<run_tag>/
├── final/
│   ├── gds/       ← GDSII layout
│   ├── lef/       ← Library Exchange Format
│   ├── def/       ← Design Exchange Format
│   ├── sdf/       ← Standard Delay Format (for gate-level sim)
│   ├── spef/      ← Parasitic Extraction
│   └── verilog/   ← Gate-level netlist (post-PnR)
├── reports/
│   ├── synthesis/
│   ├── floorplan/
│   ├── placement/
│   ├── cts/
│   ├── routing/
│   ├── signoff/
│   │   ├── sta/   ← Static Timing Analysis reports
│   │   ├── drc/   ← Design Rule Check reports
│   │   └── lvs/   ← Layout vs Schematic reports
│   └── metrics.csv
└── logs/
```

---

## Flow Stages

| Stage | Tool | Description |
|---|---|---|
| **Synthesis** | Yosys | RTL → gate-level netlist |
| **Floorplan** | OpenROAD | Die/core area, IO placement, power grid |
| **Placement** | OpenROAD | Standard cell placement + optimization |
| **CTS** | OpenROAD | Clock tree synthesis |
| **Routing** | OpenROAD | Global + detailed routing |
| **Antenna Fix** | OpenROAD | Antenna rule violation repair |
| **RC Extraction** | OpenROAD/Magic | Parasitic extraction |
| **STA** | OpenSTA | Setup/hold timing analysis |
| **DRC** | Magic + KLayout | Design rule checking |
| **LVS** | Netgen | Layout vs schematic |
| **GDSII** | Magic/KLayout | Final layout export |

---

## Design Configuration

The OpenLane configuration is in [`openlane/config.json`](../openlane/config.json).

Key settings:
- **Clock**: 100 MHz (10 ns period) on `aclk`
- **Core utilization**: 50% (SKY130: 45%)
- **Target density**: 55% (SKY130: 50%)
- **Max routing layer**: met4 / Metal4
- **Timing closure**: Strict — `QUIT_ON_TIMING_VIOLATIONS = true`
- **DRC/LVS**: Full signoff checks enabled

---

## Timing Constraints

The SDC file at [`constraints/timing.sdc`](../constraints/timing.sdc) defines:
- 100 MHz clock with 0.3 ns setup / 0.1 ns hold uncertainty
- 30% input/output delay budget (3.0 ns max)
- QoS config ports: 2-cycle multicycle path (quasi-static)
- Reset: false path (recovery/removal checked by STA)

---

## Current Status

> **BLOCKED**: No OpenLane2, PDK, or physical design tools are installed on the current system.
> All ASIC flow stages (synthesis through GDSII) require tool installation.
> 
> The RTL, constraints, and OpenLane configuration are complete and ready for execution.
