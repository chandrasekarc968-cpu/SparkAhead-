# Verification Plan & Results — Multi-Master AXI4-Lite Arbiter

## 1. Verification Strategy

The verification suite combines:
1. **Directed Simulation Tests**: 46 integration tests in `tb_axi4lite_arbiter.sv`.
2. **Randomized Stress Test**: 10,000 transactions (2,500 per master) in `tb_axi4lite_stress.sv`.
3. **Formal Verification**: SymbiYosys BMC (depth 40, Z3) + cover mode with 22 property groups.
4. **Protocol Assertion Monitors**: VALID/payload stability monitors embedded in both testbenches.
5. **In-Design SVA Assertions**: Guarded by `` `ifdef ASSERTIONS `` for synthesis compatibility.

---

## 2. Directed Regression Tests

All tests implemented in `tb/sim/tb_axi4lite_arbiter.sv`.

| Test ID | Scenario | Key Checks | Status |
|---|---|---|---|
| **1** | M1 read from S0 | OKAY + data match | ✅ Implemented |
| **2** | M2 read from S1 | OKAY + data match | ✅ Implemented |
| **3** | M1 write to S0 | OKAY response | ✅ Implemented |
| **4** | M2 write to S1 | OKAY response | ✅ Implemented |
| **5** | Invalid address read | DECERR + zero RDATA | ✅ Implemented |
| **6** | Invalid address write | DECERR | ✅ Implemented |
| **7** | AW arrives 5 cycles before W | Correct completion | ✅ Implemented |
| **8** | W arrives 5 cycles before AW | Correct completion | ✅ Implemented |
| **9** | All 4 masters request S0 | M0 priority + WRR rotation | ✅ Implemented |
| **10** | Concurrent read + write | Independent progress | ✅ Implemented |
| **11** | M0 priority burst (limit=3) | 3 consecutive M0 grants | ✅ Implemented |
| **12** | M0 burst-limit enforcement | M1 served after limit | ✅ Implemented |
| **13** | WRR proportional fairness (2:1:1) | Quota-proportional service | ✅ Implemented |
| **14** | Anti-starvation aging (threshold=8) | M1 promoted | ✅ Implemented |
| **15** | Random stalls (AW/W/AR/R) | Correct completion | ✅ Implemented |
| **16** | Reset during idle | All outputs zero + recovery | ✅ Implemented |
| **17** | S0 upper boundary address | OKAY | ✅ Implemented |
| **18** | S1 lower boundary address | OKAY | ✅ Implemented |
| **19** | Address outside both slaves | DECERR | ✅ Implemented |
| **20** | Slave error response (SLVERR) | Passthrough | ✅ Implemented |
| **21** | Reset during active write | Clean recovery | ✅ Implemented |
| **22** | M0 write to S0 | OKAY | ✅ Implemented |
| **23** | M3 read from S0 | OKAY + data | ✅ Implemented |
| **24** | M3 write to S1 | OKAY | ✅ Implemented |
| **25** | M0 read from S1 | OKAY + data | ✅ Implemented |
| **26** | Slave AW backpressure (4 cycles) | Handled | ✅ Implemented |
| **27** | Slave W backpressure (4 cycles) | Handled | ✅ Implemented |
| **28** | Master B backpressure (5 cycles) | Handled | ✅ Implemented |
| **29** | Slave AR backpressure (4 cycles) | Handled | ✅ Implemented |
| **30** | Master R backpressure (5 cycles) | Handled | ✅ Implemented |
| **31** | M1→S0 and M2→S1 sequential | Both OKAY | ✅ Implemented |
| **32** | M0 invalid write DECERR | DECERR | ✅ Implemented |
| **33** | M3 invalid read DECERR | DECERR + zero RDATA | ✅ Implemented |
| **34** | Long delayed BREADY (10 cycles) | Handled | ✅ Implemented |
| **35** | Long delayed RREADY (10 cycles) | Handled | ✅ Implemented |
| **36** | Slave delayed B response (10 cycles) | Handled | ✅ Implemented |
| **37** | True aging beyond 64 cycles | M3 served | ✅ Implemented |
| **38** | All 4 masters read contention | All served | ✅ Implemented |
| **39** | DECERR read + valid write concurrent | Both complete | ✅ Implemented |
| **40** | Reset during R_ADDR | Clean recovery | ✅ Implemented |
| **41** | DECERR write all 4 masters | All DECERR | ✅ Implemented |
| **42** | DECERR read all 4 masters | All DECERR + zero | ✅ Implemented |
| **43** | Sequential DECERR then valid | Recovery | ✅ Implemented |
| **44** | True anti-starvation: M0 flood vs M1 aging | M1 promoted | ✅ Implemented |
| **45** | Reset during W_DATA state | Clean recovery | ✅ Implemented |
| **46** | Reset during W_RESP state | Clean recovery | ✅ Implemented |

### Test Execution

```bash
make sim          # Runs 46 directed tests via iverilog
make sim-stress   # Runs 10,000-txn randomized stress test
```

> **Note**: Requires `iverilog` and `vvp` (Icarus Verilog). Install via `apt install iverilog` on Linux or via oss-cad-suite.

---

## 3. Randomized Stress Test (`tb_axi4lite_stress.sv`)

| Feature | Details |
|---|---|
| **Transactions** | 10,000 total (2,500 per master) |
| **Address Distribution** | ~15% unmapped (DECERR), remainder split S0/S1 |
| **Timing Randomization** | LFSR-driven delays (0–2 cycles) |
| **Slave Backpressure** | Random 75% accept rate on all channels |
| **Protocol Monitors** | One-hot BVALID/RVALID, one-hot slave VALID, VALID/payload stability |
| **Scoreboard** | Per-master write/read/DECERR counts, total verification |
| **Deadlock Watchdog** | 10ms timeout |

---

## 4. Formal Verification Properties

All properties in `formal/arbiter_formal.sv`, configured via `formal/arbiter.sby`.

| ID | Property | Type | Description |
|---|---|---|---|
| **A1** | One-hot BVALID | Assert | `$onehot0(s_axi_bvalid)` |
| **A2** | One-hot RVALID | Assert | `$onehot0(s_axi_rvalid)` |
| **A3** | One-hot slave AWVALID | Assert | `$onehot0(m_axi_awvalid)` |
| **A4** | One-hot slave WVALID | Assert | `$onehot0(m_axi_wvalid)` |
| **A5** | One-hot slave ARVALID | Assert | `$onehot0(m_axi_arvalid)` |
| **A6** | Reset clears all handshakes | Assert | All VALID/READY = 0 after reset |
| **A7** | Write owner stable when active | Assert | `owner_id_r` constant during in-flight |
| **A8** | Read owner stable when active | Assert | `owner_id_r` constant during in-flight |
| **A9–A11** | Slave VALID/payload stability | Assert | AWVALID/WVALID/ARVALID stable until READY |
| **A12** | Slave AWVALID only in W_ADDR | Assert | No phantom AW transactions |
| **A13** | Slave WVALID only in W_DATA | Assert | No phantom W transactions |
| **A14** | Slave ARVALID only in R_ADDR | Assert | No phantom AR transactions |
| **A15** | Response isolation | Assert | BVALID/RVALID only for registered owner |
| **A16–A17** | Master BVALID/RVALID stability | Assert | DUT response VALID/payload stable |
| **A18** | AW/W same-master pairing | Assert | Buffers belong to same master |
| **A19** | Read/write path independence | Cover | Both FSMs active simultaneously |
| **A20** | Write transaction completion | Cover | `arb_tx_done` reachable |
| **A21** | Read transaction completion | Cover | `arb_tx_done` reachable |
| **A22** | DECERR completion | Cover | DECERR on both write and read paths |

### Formal Execution

```bash
make formal       # SymbiYosys BMC (depth 40, Z3) + cover mode
```

BMC depth: 40 cycles. Solver: Z3. Requires `sby` (SymbiYosys).

---

## 5. RTL Assertion Summary (In-Design)

| Module | Assertions | Description |
|---|---|---|
| `axi4lite_qos_scheduler` | 6 groups | Owner stability, grant-implies-request, no-stale-grant, one-hot grant |
| `axi4lite_arbiter_top` | 9 groups | One-hot BVALID/RVALID, one-hot slave VALID, reset-clears-state |
| `axi4lite_write_arbiter` | 3 groups | Owner stability, no buffer overwrite, one-hot slave VALID |
| `axi4lite_read_arbiter` | 3 groups | Owner stability, one-hot slave VALID, one-hot master READY |
| `axi4lite_address_decoder` | 2 groups | One-hot slave_sel, valid/invalid complementary |
| `axi4lite_response_router` | 2 groups | One-hot BVALID, one-hot RVALID |

All assertions guarded by `` `ifdef ASSERTIONS `` for synthesis compatibility.

---

## 6. Synthesis Verification

```bash
make synth        # Yosys generic synthesis
```

| Item | Status |
|---|---|
| **Tool** | Yosys (open-source) |
| **Top Module** | `axi4lite_arbiter_top` |
| **Technology Mapping** | Generic (unmapped) without PDK; sky130 with `PDK_ROOT` set |
| **SDC** | `constraints/timing.sdc` — informational for Yosys |
| **Netlist** | `outputs/axi4lite_arbiter_top_netlist.v` |
| **Reports** | Cell count and area in `logs/synth.log` |

> [!IMPORTANT]
> **Timing closure cannot be verified** without a technology library (Liberty `.lib` file). Yosys performs logic synthesis but does not perform static timing analysis (STA). For timing closure, use OpenSTA with a Liberty file or run the full OpenLane flow.

> [!IMPORTANT]
> **ASIC physical design** (floorplan, placement, CTS, routing, DRC, LVS) requires a PDK (e.g., sky130A via OpenLane2). This verification plan covers RTL through gate-level synthesis only.

---

## 7. Coverage Summary

| Coverage Type | Status | Notes |
|---|---|---|
| **Line/Statement** | Implicit via directed tests | iverilog does not generate coverage reports |
| **FSM State** | All states exercised | W_IDLE, W_ADDR, W_DATA, W_RESP; R_IDLE, R_ADDR, R_RESP |
| **Boundary Conditions** | ✅ | Address boundaries, timeout values, reset at each state |
| **Error Paths** | ✅ | DECERR for all masters, SLVERR passthrough |
| **Arbitration Policies** | ✅ | WRR fairness, aging promotion, M0 priority, burst limit |
| **Backpressure** | ✅ | AW, W, B, AR, R backpressure from both masters and slaves |
| **Concurrent Operations** | ✅ | Simultaneous read+write, DECERR+valid concurrent |
| **Reset Recovery** | ✅ | Reset during idle, W_ADDR, W_DATA, W_RESP, R_ADDR |
