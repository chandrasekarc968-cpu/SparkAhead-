# Architecture — Multi-Master AXI4-Lite Arbiter

## 1. Top-Level Block Diagram

> **TODO:** Insert block diagram (draw.io / Mermaid) showing 4 master ports → arbiter → 2 slave ports + default-slave shim.

## 2. Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `NUM_MASTERS` | int | 4 | Number of AXI4-Lite master ports |
| `NUM_SLAVES` | int | 2 | Number of AXI4-Lite slave ports |
| `DATA_WIDTH` | int | 32 | Data bus width (bits) |
| `ADDR_WIDTH` | int | 32 | Address bus width (bits) |
| `SLAVE0_BASE` | logic [ADDR_WIDTH-1:0] | `32'h0000_0000` | Slave 0 base address |
| `SLAVE0_SIZE` | logic [ADDR_WIDTH-1:0] | `32'h0001_0000` | Slave 0 region size |
| `SLAVE1_BASE` | logic [ADDR_WIDTH-1:0] | `32'h0001_0000` | Slave 1 base address |
| `SLAVE1_SIZE` | logic [ADDR_WIDTH-1:0] | `32'h0001_0000` | Slave 1 region size |
| `WRR_WEIGHTS` | int [NUM_MASTERS-1:0] | `{4, 2, 1, 1}` | Per-master weights for weighted round-robin |
| `AGE_THRESHOLD` | int | 64 | Cycles before an aged master gets promoted |
| `PREEMPT_EN` | bit | 1 | Enable Master 0 preemption |

## 3. Module Hierarchy

```
axi4lite_arbiter_top
├── addr_decoder            — Hardcoded address-range comparator → slave select / DECERR
├── write_arbiter           — WRR + aging + preemption for AW/W/B channels
│   ├── wrr_scheduler       — Weighted round-robin FSM
│   └── age_counter [0:3]   — Per-master starvation counters
├── read_arbiter            — WRR + aging + preemption for AR/R channels
│   ├── wrr_scheduler       — (shared design, second instance)
│   └── age_counter [0:3]
├── write_mux               — AW/W channel master → slave crossbar mux
├── read_mux                — AR channel master → slave crossbar mux
├── resp_demux              — B/R channel slave → master response demux
└── default_slave           — Returns DECERR for unmapped addresses
```

## 4. Arbitration Algorithm

### 4.1 Weighted Round-Robin (WRR)

> **TODO:** Describe the counter-based WRR state machine in detail. Include state diagram.

### 4.2 Master 0 Preemption

> **TODO:** Describe preemption handshake, latency, and conditions under which an in-flight grant is NOT preempted.

### 4.3 Anti-Starvation Aging

> **TODO:** Describe the per-master age counter, threshold comparison, and priority override mechanism.

## 5. Address Decoder

> **TODO:** Describe compile-time address map, overlap checking (assertion), and DECERR generation.

## 6. Channel Datapath

### 6.1 Write Path (AW → W → B)

> **TODO:** Describe mux/demux structure, outstanding transaction tracking, and back-pressure handling.

### 6.2 Read Path (AR → R)

> **TODO:** Describe mux/demux structure, outstanding transaction tracking, and back-pressure handling.

## 7. Default Slave (DECERR Responder)

> **TODO:** Describe the shim that absorbs invalid-address transactions and returns `RESP = 2'b11`.

## 8. Clock & Reset Strategy

- Single clock domain (`aclk`).
- Synchronous active-low reset (`aresetn`).

> **TODO:** Document any CDC considerations if the design later becomes multi-clock.

## 9. Interface Signals

> **TODO:** Full signal table for `axi4lite_arbiter_top` (master-side and slave-side AXI4-Lite ports).

## 10. RTL File List

> **TODO:** Populate once RTL is written.

| File | Module | Description |
|---|---|---|
| `src/rtl/axi4lite_arbiter_top.sv` | `axi4lite_arbiter_top` | Top-level wrapper |
| `src/rtl/addr_decoder.sv` | `addr_decoder` | Address decoder |
| `src/rtl/wrr_scheduler.sv` | `wrr_scheduler` | Weighted round-robin FSM |
| `src/rtl/age_counter.sv` | `age_counter` | Per-master starvation counter |
| `src/rtl/write_arbiter.sv` | `write_arbiter` | Write channel arbiter |
| `src/rtl/read_arbiter.sv` | `read_arbiter` | Read channel arbiter |
| `src/rtl/write_mux.sv` | `write_mux` | Write channel multiplexer |
| `src/rtl/read_mux.sv` | `read_mux` | Read channel multiplexer |
| `src/rtl/resp_demux.sv` | `resp_demux` | Response demultiplexer |
| `src/rtl/default_slave.sv` | `default_slave` | DECERR responder |
