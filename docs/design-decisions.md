# Design Decisions & Frozen MVP Scope — VELTRAXX'26 PS02

## Executive Summary

This document formalizes the architectural scope for the **VELTRAXX'26 PS02 Multi-Master AXI4-Lite Interconnect / Arbiter**. All RTL, verification, and synthesis must adhere to these frozen parameters.

---

## 1. Frozen Scope & Architecture Parameters

| Parameter | Frozen Value | Rationale |
|:---|:---|:---|
| **Master Count** | `4` (M0–M3) | 4 upstream AXI4-Lite masters with prioritized/weighted access. |
| **Slave Count** | `2` (S0, S1) + internal DECERR | 2 external slaves + inline DECERR responder. |
| **Address Width** | `32` bits | Byte-addressable 32-bit address space. |
| **Data Width** | `32` bits | 32-bit data with 4-bit byte strobe. |
| **Transaction Concurrency** | 1 Outstanding Write + 1 Outstanding Read | Independent single-outstanding FSMs for read and write. |
| **Burst Support** | None (single-beat only) | AXI4-Lite compliant (ARM IHI 0022E). |
| **WRR Weights** | `cfg_weight_m1=3, m2=2, m3=1` (runtime) | Budget-based WRR with runtime-configurable quotas. |
| **M0 Priority** | `cfg_master0_priority` (runtime enable) | Preemption only at IDLE boundary. Burst-limited by `cfg_master0_burst_limit`. |
| **Anti-Starvation** | `cfg_age_threshold` (runtime, per-master) | Independent 8-bit saturating counters. Promotion above M0 on threshold breach. |
| **Address Map** | Fixed hardcoded decode | S0: `[0x0000_0000, 0x0000_FFFF]`, S1: `[0x0001_0000, 0x0001_FFFF]`. |
| **Unmapped Handling** | Internal DECERR (`2'b11`) | Returns `BRESP/RRESP = 2'b11`, `RDATA = 0`. No slave-side traffic. |

---

## 2. Microarchitecture Details

### 2.1 Per-Master AW/W Skid Buffers
- Each master has independent AW and W buffers in `axi4lite_write_arbiter`.
- Buffers decouple VALID/READY timing: AW and W can arrive in any order.
- `buf_locked` prevents buffer overwrite during in-flight transactions.
- Arbitration eligibility requires both AW and W buffers valid for the same master.

### 2.2 Independent Read & Write Datapaths
- **Write Path FSM** (`W_IDLE → W_ADDR → W_DATA → W_RESP`):
  - `W_IDLE`: QoS scheduler grants master. Owner and target latched.
  - `W_ADDR`: Forward AW to target slave.
  - `W_DATA`: Forward W to target slave.
  - `W_RESP`: Route B response to owner.
- **Read Path FSM** (`R_IDLE → R_ADDR → R_RESP`):
  - `R_IDLE`: QoS scheduler grants master. Owner and target latched.
  - `R_ADDR`: Forward AR to target slave.
  - `R_RESP`: Route R data/response to owner.

### 2.3 QoS Arbitration
1. **Normal WRR**: M0–M3 arbitrated by budget-based WRR with configurable quotas.
2. **M0 Preemption**: When `cfg_master0_priority` is active and no master has exceeded age threshold, M0 wins immediately at IDLE. Subject to burst limit.
3. **Anti-Starvation**: Per-master age counters for M1–M3. When `age >= cfg_age_threshold`, the aged master gets promoted. Aged-master tie-breaking uses RR pointer. Age resets on grant.

### 2.4 DECERR Handling
- Zero-latency combinational decode in `axi4lite_address_decoder`.
- `axi4lite_response_router` generates DECERR inline when `target_invalid` is set.
- No slave-side VALID is asserted for unmapped addresses.

---

## 3. Protocol & Verification Rules

1. **Handshake Stability**: Per ARM IHI 0022E, VALID held with stable payload until READY.
2. **Response Isolation**: B/R routed strictly to registered owner. Non-owners see deasserted VALID.
3. **AW/W Pairing**: Both buffers must be from the same master before arbitration eligibility.
4. **Synthesizability**: Standard SV-2012 constructs. Compatible with iverilog, Verilator, Yosys.
5. **No Latches**: All state fully registered with explicit reset.
