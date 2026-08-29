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

## Complete Step-by-Step: Clone to GDS

Follow these steps on **Ubuntu 22.04+** to go from zero to a finished GDSII layout.

### Step 1: Install Prerequisites

```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install build essentials and Git
sudo apt-get install -y git make curl unzip

# Install Docker (required for OpenLane2)
sudo apt-get install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# IMPORTANT: Log out and log back in so the docker group takes effect
# Verify with:
docker run --rm hello-world
```

### Step 2: Install Verification Tools (Optional but Recommended)

```bash
# Option A: Install via apt (quick, may be older versions)
sudo apt-get install -y verilator iverilog

# Option B: Install oss-cad-suite (recommended — includes Yosys, SymbiYosys, Z3)
# Download the latest release from:
#   https://github.com/YosysHQ/oss-cad-suite-build/releases
# Then:
tar -xzf oss-cad-suite-linux-x64-*.tgz -C ~/
echo 'export PATH="$HOME/oss-cad-suite/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Step 3: Clone the Repository

```bash
git clone https://github.com/chandrasekarc968-cpu/SparkAhead-.git
cd SparkAhead-
```

### Step 4: Run RTL Lint (Verify RTL is Clean)

```bash
make lint
```

**Expected output:**
```
=== LINT ===
- V e r i l a t i o n   R e p o r t: Verilator 5.032 ...
=== LINT COMPLETE ===
```

### Step 5: Run Simulation (Verify Functional Correctness)

```bash
make sim
```

> **Note**: Requires `iverilog` and `vvp`. If not installed, skip to Step 7.

### Step 6: Validate OpenLane Config

```bash
make check-config
```

**Expected output:**
```
=== OpenLane Config Sanity Check ===
  [OK]   DESIGN_NAME = axi4lite_arbiter_top
  [OK]   CLOCK_PORT = aclk
  [OK]   CLOCK_PERIOD = 10.0
  [OK]   PDK = sky130A
  [OK]   STD_CELL_LIBRARY = sky130_fd_sc_hd
  ...
[PASS] Config looks good.
```

### Step 7: Run OpenLane2 RTL-to-GDS (Generates the GDS)

This is the main step. It runs the full ASIC flow inside Docker:
**sv2v → Yosys Synthesis → Floorplan → Placement → CTS → Routing → DRC → LVS → GDS**

```bash
make openlane
```

**What happens:**
1. `sv2v` converts SystemVerilog to Verilog-2005
2. Docker pulls the OpenLane2 image (`ghcr.io/efabless/openlane2:2.0.4`) on first run (~3 GB download)
3. The Docker container automatically downloads the SKY130 PDK via Volare
4. OpenLane2 runs all 75 stages of the RTL-to-GDS flow
5. Results are copied to `outputs/` and `logs/`

**Expected runtime:** ~5–8 minutes (after Docker image is cached)

**Expected final output:**
```
=== OpenLane Flow COMPLETE ===
Outputs are available in: openlane/runs/
[INFO] Copying test data to logs/ and outputs/ directories...
=== OPENLANE COMPLETE ===
```

### Step 8: Verify the Generated GDS

```bash
# Check that the GDS file was generated
ls -lh outputs/axi4lite_arbiter_top.gds

# View the design metrics
cat logs/openlane_metrics.json | python3 -m json.tool | head -20

# Or run the showcase for a quick summary
make showcase
```

**Expected output files in `outputs/`:**

| File | Description | Size |
|---|---|---|
| `axi4lite_arbiter_top.gds` | Final GDSII layout | ~19 MB |
| `axi4lite_arbiter_top.def` | Design Exchange Format | ~12 MB |
| `axi4lite_arbiter_top.lef` | Library Exchange Format | ~229 KB |
| `axi4lite_arbiter_top.nl.v` | Gate-level netlist | ~4.3 MB |

**Expected log files in `logs/`:**

| File | Description |
|---|---|
| `openlane.log` | Full OpenLane execution log |
| `openlane_metrics.json` | Design metrics (area, timing, DRC, LVS) |
| `openlane_metrics.csv` | Same metrics in CSV format |

### Alternative: Run the Complete Pipeline in One Command

```bash
make rtl-to-gds
```

This runs **lint → simulation → formal → OpenLane** in sequence, stopping on the first error, and prints all final artifact paths at the end.

---

## All Available Make Targets

| Command | What It Does |
|---|---|
| `make lint` | RTL lint check (Verilator or iverilog) |
| `make sim` | Run 46-test directed regression suite |
| `make sim-stress` | Run 10,000-transaction randomized stress test |
| `make formal` | Formal verification (SymbiYosys BMC + cover) |
| `make synth` | Yosys gate-level synthesis (with sky130 mapping if PDK_ROOT set) |
| `make openlane` | OpenLane2 RTL-to-GDS via Docker |
| `make pnr` | Same as `make openlane` |
| `make rtl-to-gds` | Full pipeline: lint → sim → formal → OpenLane |
| `make showcase` | Lightweight demo: lint + sim + display metrics |
| `make check-config` | Validate `openlane/config.json` |
| `make check` | Run all checks (CI target) |
| `make clean` | Remove all generated outputs |

---

## Advanced Setup Options

### Option A: Python venv + OpenLane (--dockerized)

> **Note**: OpenLane2's Python package requires **Python 3.10–3.12**.
> Python 3.13+ is NOT supported due to `libparse` build failures.

```bash
python3.12 -m venv .venv
source .venv/bin/activate
pip install openlane
python -m openlane --dockerized openlane/config.json
```

### Option B: Nix-based OpenLane

```bash
# Install Nix
sh <(curl -L https://nixos.org/nix/install) --daemon
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Run OpenLane directly
nix run github:efabless/openlane2 -- openlane/config.json
```

### PDK_ROOT Setup (Native Only)

If running OpenLane natively (not via Docker), set `PDK_ROOT`:

```bash
export PDK_ROOT=$HOME/.volare
```

The Docker-based flow handles PDK installation automatically — no `PDK_ROOT` needed.

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
| **PDK** | SKY130 (sky130_fd_sc_hd) |
| **Cell Count** | 16,391 |
| **Area** | 58,227 μm² |
| **Die Size** | 900 × 900 μm |
| **Utilization** | 7.5% |
| **Setup Slack (nom_tt)** | +2.12 ns |
| **Setup Slack (nom_ss)** | +0.30 ns |
| **DRC** | 0 errors (Magic + KLayout) |
| **LVS** | 0 errors |
| **Total Power** | 18.7 mW |
| **Antenna Violations** | 27 pins / 23 nets (non-blocking) |

---

## Troubleshooting

### Docker permission denied
```
Got permission denied while trying to connect to the Docker daemon socket
```
**Fix:** Run `sudo usermod -aG docker $USER` and **log out / log back in**.

### sv2v not found
The `openlane.sh` script automatically downloads `sv2v` on first run. If it fails:
```bash
curl -sL https://github.com/zachjs/sv2v/releases/download/v0.0.11/sv2v-Linux.zip -o /tmp/sv2v.zip
unzip -qo /tmp/sv2v.zip -d /tmp/sv2v_bin
cp /tmp/sv2v_bin/sv2v-Linux/sv2v scripts/
```

### OpenLane Docker image pull fails
```bash
# Manually pull the image
docker pull ghcr.io/efabless/openlane2:2.0.4
```

### Python 3.14 / libparse build error
OpenLane2 requires **Python 3.10–3.12**. If your system default is newer:
```bash
sudo apt-get install -y python3.12 python3.12-venv
python3.12 -m venv .venv
source .venv/bin/activate
```

---

## Known Limitations

1. **Single Outstanding Transaction Per Channel**: 1 outstanding write + 1 outstanding read at any time.
2. **Fixed Address Map**: Compile-time parameters, no software-remappable registers.
3. **Frozen 4M/2S**: Hardcoded to 4 masters and 2 slaves. Changing triggers `$fatal`.
4. **Hold Timing**: Marginal hold violations (~68 ps) on the slowest signoff corner (max_ss_100C_1v60). Non-blocking for tapeout preparation.
