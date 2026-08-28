# Verification Plan & Results — Multi-Master AXI4-Lite Arbiter

## 1. Verification Strategy

The verification suite combines:
1. **Directed Simulation Tests**: 46 integration tests in `tb_axi4lite_arbiter.sv`.
2. **Randomized Stress Test**: 10,000 transactions (2,500 per master) in `tb_axi4lite_stress.sv`.
3. **Formal Verification**: SymbiYosys BMC (depth 40, Z3) + cover mode with 22 property groups.
4. **Protocol Assertion Monitors**: VALID/payload stability monitors embedded in both testbenches.

---

## 2. Directed Regression Tests

| Test ID | Scenario | Key Checks | Status |
|---|---|---|---|
| **1** | M1 read from S0 | OKAY + data | BLOCKED |
| **2** | M2 read from S1 | OKAY + data | BLOCKED |
| **3** | M1 write to S0 | OKAY response | BLOCKED |
| **4** | M2 write to S1 | OKAY response | BLOCKED |
| **5** | Invalid address read | DECERR + zero RDATA | BLOCKED |
| **6** | Invalid address write | DECERR | BLOCKED |
| **7** | AW arrives 5 cycles before W | Correct completion | BLOCKED |
| **8** | W arrives 5 cycles before AW | Correct completion | BLOCKED |
| **9** | All 4 masters request S0 | M0 priority + WRR rotation | BLOCKED |
| **10** | Concurrent read + write | Independent progress | BLOCKED |
| **11** | M0 priority burst (limit=3) | 3 consecutive M0 grants | BLOCKED |
| **12** | M0 burst-limit enforcement | M1 served after limit | BLOCKED |
| **13** | WRR proportional fairness (3:2:1) | Quota-proportional service | BLOCKED |
| **14** | Anti-starvation aging (threshold=8) | M1 promoted | BLOCKED |
| **15** | Random stalls (AW/W/AR/R) | Correct completion | BLOCKED |
| **16** | Reset during idle | All outputs zero + recovery | BLOCKED |
| **17** | S0 upper boundary address | OKAY | BLOCKED |
| **18** | S1 lower boundary address | OKAY | BLOCKED |
| **19** | Address outside both slaves | DECERR | BLOCKED |
| **20** | Slave error response (SLVERR) | Passthrough | BLOCKED |
| **21** | Reset during active write | Clean recovery | BLOCKED |
| **22** | M0 write to S0 | OKAY | BLOCKED |
| **23** | M3 read from S0 | OKAY + data | BLOCKED |
| **24** | M3 write to S1 | OKAY | BLOCKED |
| **25** | M0 read from S1 | OKAY + data | BLOCKED |
| **26** | Slave AW backpressure (4 cycles) | Handled | BLOCKED |
| **27** | Slave W backpressure (4 cycles) | Handled | BLOCKED |
| **28** | Master B backpressure (5 cycles) | Handled | BLOCKED |
| **29** | Slave AR backpressure (4 cycles) | Handled | BLOCKED |
| **30** | Master R backpressure (5 cycles) | Handled | BLOCKED |
| **31** | M1→S0 and M2→S1 sequential | Both OKAY | BLOCKED |
| **32** | M0 invalid write DECERR | DECERR | BLOCKED |
| **33** | M3 invalid read DECERR | DECERR + zero RDATA | BLOCKED |
| **34** | Long delayed BREADY (10 cycles) | Handled | BLOCKED |
| **35** | Long delayed RREADY (10 cycles) | Handled | BLOCKED |
| **36** | Slave delayed B response (10 cycles) | Handled | BLOCKED |
| **37** | True aging beyond 64 cycles | M3 served | BLOCKED |
| **38** | All 4 masters read contention | All served | BLOCKED |
| **39** | DECERR read + valid write concurrent | Both complete | BLOCKED |
| **40** | Reset during R_ADDR | Clean recovery | BLOCKED |
| **41** | DECERR write all 4 masters | All DECERR | BLOCKED |
| **42** | DECERR read all 4 masters | All DECERR + zero | BLOCKED |
| **43** | Sequential DECERR then valid | Recovery | BLOCKED |
| **44** | True anti-starvation: M0 flood vs M1 aging | M1 promoted | BLOCKED |
| **45** | Reset during W_DATA state | Clean recovery | BLOCKED |
| **46** | Reset during W_RESP state | Clean recovery | BLOCKED |

> **BLOCKED**: No simulation tools (iverilog) installed on the current system. Install oss-cad-suite to run.

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
| **Status** | **BLOCKED** (no tools) |

---

## 4. Formal Verification Properties

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

BMC depth: 40 cycles. Solver: Z3. Status: **BLOCKED** (no sby installed).

---

## 5. RTL Assertion Summary (In-Design)

| Module | Assertions | Description |
|---|---|---|
| `axi4lite_qos_scheduler` | Owner stability, grant-implies-request, no-stale-grant | 6 assertion groups |
| `axi4lite_arbiter_top` | BVALID one-hot, response isolation | 2 assertion groups |
| `axi4lite_write_arbiter` | Buffer integrity | Built-in |
| `axi4lite_read_arbiter` | State consistency | Built-in |

All assertions guarded by `` `ifdef ASSERTIONS `` for synthesis compatibility.
