# Verification Plan — Multi-Master AXI4-Lite Arbiter

## 1. Verification Goals

- **Protocol compliance:** All AXI4-Lite handshakes conform to ARM IHI 0022E.
- **Arbitration correctness:** WRR, preemption, and aging behave as specified.
- **Address decoding:** Valid addresses route to the correct slave; invalid addresses return DECERR.
- **No starvation:** Every requesting master is eventually granted.
- **No deadlock:** The arbiter never enters a state from which it cannot make progress.

## 2. Testbench Architecture

> **TODO:** Describe the layered UVM / cocotb / Verilator testbench structure.

### 2.1 Components

| Component | Description |
|---|---|
| `axi4lite_master_driver` | Drives AXI4-Lite write/read transactions from a sequence |
| `axi4lite_slave_responder` | Programmable slave that returns OK / SLVERR with configurable latency |
| `axi4lite_monitor` | Passive bus monitor — captures transactions for scoreboard |
| `scoreboard` | Checks data integrity, ordering, and response correctness |
| `coverage_collector` | Functional coverage bins for arbitration, decode, error paths |

### 2.2 Block Diagram

> **TODO:** Insert testbench block diagram.

## 3. Directed Tests

| ID | Test Name | Description | Status |
|---|---|---|---|
| T01 | `test_single_master_write` | Single master writes to Slave 0, expects OKAY | TODO |
| T02 | `test_single_master_read` | Single master reads from Slave 1, expects OKAY | TODO |
| T03 | `test_decerr_unmapped` | Access to unmapped address, expects DECERR | TODO |
| T04 | `test_wrr_fairness` | All 4 masters request simultaneously; verify WRR grant order matches weights | TODO |
| T05 | `test_preemption` | Master 0 preempts an active grant cycle | TODO |
| T06 | `test_aging_promotion` | A starved master is promoted after AGE_THRESHOLD cycles | TODO |
| T07 | `test_concurrent_rw` | Simultaneous read and write from different masters granted independently | TODO |
| T08 | `test_back_to_back` | Back-to-back transactions with no idle cycles | TODO |
| T09 | `test_reset_recovery` | Assert reset mid-transaction; arbiter returns to idle cleanly | TODO |
| T10 | `test_all_masters_all_slaves` | Stress test — all masters hit both slaves with random addresses | TODO |

## 4. Constrained-Random Strategy

> **TODO:** Define randomisation knobs:
> - Transaction type (read / write / mixed)
> - Address distribution (uniform / hot-spot / boundary)
> - Inter-transaction delay
> - Slave response latency
> - Reset injection

## 5. Assertions (SVA / PSL)

> **TODO:** Implement the following inline assertions in the RTL or bind file:

| ID | Assertion | Channel |
|---|---|---|
| A01 | VALID must not be deasserted before READY | AW, W, AR |
| A02 | RESP is valid (00, 10, 11) | B, R |
| A03 | No two masters granted on the same channel simultaneously | AW, AR |
| A04 | Grant implies prior request | AW, AR |
| A05 | DECERR returned for unmapped address | B, R |
| A06 | No starvation: requesting master granted within AGE_THRESHOLD × NUM_MASTERS cycles | AW, AR |
| A07 | Reset clears all internal state | Global |

## 6. Functional Coverage

> **TODO:** Define coverage groups:

| CG | Description |
|---|---|
| `cg_arb_grant` | Cross of master ID × channel (read/write) × grant type (normal/preempt/aged) |
| `cg_addr_decode` | Bins for each slave region + unmapped region |
| `cg_resp` | Cross of master ID × response type (OKAY / DECERR) |
| `cg_concurrent` | Simultaneous read and write grants active |
| `cg_back_pressure` | Slave not-ready stalls |

## 7. Formal Verification

> **TODO:** Define formal properties to prove:

- **Liveness:** Every request is eventually granted.
- **Safety:** No two grants on the same channel.
- **Deadlock freedom:** The arbiter FSM is deadlock-free (model-check).
- **Reset:** After reset, all outputs are deasserted within 1 cycle.

## 8. Synthesis Checks

> **TODO:**
- Verify no latches inferred.
- Verify no combinational loops.
- Verify timing closure at target frequency (see `constraints/timing.sdc`).

## 9. Waveform Evidence

> **TODO:** Capture annotated VCD / FSDB waveforms for:
- WRR arbitration sequence
- Preemption event
- Aging promotion event
- DECERR response
- Concurrent read + write grant

## 10. Coverage Closure Criteria

- **Line coverage:** ≥ 95 %
- **Branch coverage:** ≥ 90 %
- **Functional coverage:** 100 % of defined bins hit
- **Assertion coverage:** All assertions exercised (hit and not-hit)
