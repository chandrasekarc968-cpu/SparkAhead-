# Design Decisions & Frozen MVP Scope — VELTRAXX'26 PS02

## Executive Summary

This document formalizes and freezes the architectural scope for the **VELTRAXX'26 PS02 Multi-Master AXI4-Lite Interconnect / Arbiter**. All downstream RTL implementation (`src/rtl/`), verification testbenches (`tb/`), assertions, and synthesis constraints must adhere to these frozen parameters and behavioral specifications.

---

## 1. Frozen Scope & Architecture Parameters

| Parameter | Frozen Value | Rationale / Specification |
|:---|:---|:---|
| **Master Count (`NUM_MASTERS`)** | `4` (M0, M1, M2, M3) | 4 upstream AXI4-Lite master interfaces with prioritized / weighted access. |
| **Slave Count (`NUM_SLAVES`)** | `2` (Slave 0, Slave 1) | 2 downstream AXI4-Lite target slaves + 1 internal default DECERR slave. |
| **Address Bus Width (`ADDR_WIDTH`)** | `32` bits | Byte-addressable 32-bit address space. |
| **Data Bus Width (`DATA_WIDTH`)** | `32` bits | 32-bit data datapath with 4-bit byte strobe (`WSTRB[3:0]`). |
| **Transaction Concurrency** | **1 Outstanding Write + 1 Outstanding Read** | Independent single-outstanding read FSM and single-outstanding write FSM allowing parallel read/write across different masters/slaves without interleaving hazards. |
| **Burst Support** | **None (Single-beat only)** | Strictly compliant with AXI4-Lite (ARM IHI 0022E). No burst signals (`AWLEN`, `AWSIZE`, `AWBURST`, `ARLEN`, etc.) or burst counters. |
| **M1 / M2 / M3 WRR Weights** | `M1_WEIGHT = 3`<br>`M2_WEIGHT = 2`<br>`M3_WEIGHT = 1` | Weighted round-robin quota for standard masters. Quota decrements on completed transaction. |
| **M0 Priority & Preemption** | `M0_WEIGHT = 1`<br>**Preemption only before acceptance** | M0 has immediate high priority when requesting. Preemption is permitted **only at arbitration / decision phase before transaction acceptance**. In-flight transactions (`AW_WAIT`, `W_WAIT`, `B_WAIT`, `AR_WAIT`, `R_WAIT`) are **never interrupted**. |
| **Anti-Starvation Aging** | `AGE_THRESHOLD = 64` cycles | Starvation counter increments per cycle when lower-priority masters (M1-M3) have pending requests while M0 is served. Upon reaching 64 cycles, M0 is temporarily suppressed to service starved masters, resetting upon lower-priority completion. |
| **Address Mapping** | **Fixed / Hardcoded Decode** | • **Slave 0:** `[0x0000_0000, 0x0000_FFFF]` (Size: 64 KB)<br>• **Slave 1:** `[0x0001_0000, 0x0001_FFFF]` (Size: 64 KB) |
| **Unmapped Address Handling** | **Internal DECERR (`2'b11`)** | Any address outside defined slave ranges routes to an internal default slave shim, consuming request handshakes and returning `BRESP = 2'b11` / `RRESP = 2'b11` with `RDATA = 32'h0`. |

---

## 2. Microarchitecture Details

### 2.1 Independent Read & Write Datapaths
- **Write Path FSM (`IDLE`, `AW_WAIT`, `W_WAIT`, `B_WAIT`)**:
  - `IDLE`: QoS arbiter selects active master write request. Owner ID and decoded slave target are latched.
  - `AW_WAIT`: Forward latched master address to target slave (`AWVALID` asserted). Retain ownership until `AWREADY` handshake.
  - `W_WAIT`: Accept write data/strb exclusively from the latched owner and forward to target slave until `WREADY` handshake.
  - `B_WAIT`: Forward response (`BRESP`/`BVALID`) from slave exclusively to the owning master until `BREADY` handshake.
- **Read Path FSM (`IDLE`, `AR_WAIT`, `R_WAIT`)**:
  - `IDLE`: QoS arbiter selects active master read request. Read owner ID and decoded slave target are latched.
  - `AR_WAIT`: Forward read address to target slave (`ARVALID` asserted) until `ARREADY` handshake.
  - `R_WAIT`: Forward `RDATA`, `RRESP`, and `RVALID` from slave exclusively to the owning read master until `RREADY` handshake.

### 2.2 QoS Arbitration (M0 Preemption, WRR, Aging)
1. **Normal WRR Operation**: When M0 is idle and starvation is inactive, M1, M2, and M3 are arbitrated using Weighted Round-Robin with service quotas of 3, 2, and 1 transactions respectively.
2. **Master 0 Preemption Boundary**: If M0 asserts a request while M1-M3 are being evaluated in `IDLE`, M0 is immediately granted. Once a transaction enters active handshake/transfer state, M0 must wait until that transaction completes (no mid-burst / mid-handshake interruption).
3. **Anti-Starvation Mechanism**:
   - Continuous pending requests from M1..M3 while M0 retains arbitration cause the `age_counter` to increment each clock cycle.
   - If `age_counter >= 64`, the `starvation_flag` is asserted, demoting M0 and guaranteeing service to waiting lower-priority masters.
   - Successful completion of a lower-priority transaction resets the starvation counter.

### 2.3 Hardcoded Address Decoder & DECERR Handling
- Zero-latency combinational address decode.
- Generates one-hot target select (`slave_sel[1:0]`) and an `unmapped_addr` flag.
- Protection attributes (`AWPROT`, `ARPROT`) are passed through without modification.
- Unmapped accesses trigger internal default slave responses:
  - Write: Consumes `AW` and `W` phases, returns `BRESP = 2'b11` (DECERR) with `BVALID = 1`.
  - Read: Consumes `AR` phase, returns `RRESP = 2'b11` (DECERR) with `RDATA = 32'h0` and `RVALID = 1`.

---

## 3. Protocol & Verification Rules

1. **Handshake Stability**: In accordance with ARM IHI 0022E, once `*VALID` is asserted by the interconnect or forwarded from master/slave, payload signals (`ADDR`, `DATA`, `STRB`, `PROT`, `RESP`) must remain stable until `*READY` is asserted.
2. **Response Routing Isolation**: Responses (`B` channel and `R` channel) are steered strictly to the registered transaction owner. Non-owner masters see deasserted `BVALID`/`RVALID`.
3. **Synthesizability & Language Standard**: Standard synthesizable SystemVerilog 2012 constructs compatible with Icarus Verilog (`iverilog -g2012`), Verilator, and Yosys. No dynamic classes, UVM, or proprietary simulator pragmas.
