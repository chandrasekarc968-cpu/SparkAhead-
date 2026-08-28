# Verification Plan & Results — Multi-Master AXI4-Lite Arbiter

## 1. Verification Strategy

The verification suite combines:
1. **Directed Simulation Tests**: 17 integration tests with `$fatal`-guarded assertions in `tb_axi4lite_arbiter.sv`.
2. **Formal Verification**: SymbiYosys BMC (depth 20, Z3) with 11 assertion groups in `arbiter_formal.sv`.
3. **Build Script Guards**: `sim.sh` requires `[PASS]` markers; `formal.sh` requires assertions exist; `synth.sh` verifies the netlist.

---

## 2. Integration Simulation Tests

| Test ID | Scenario | Checks | Status |
|---|---|---|---|
| **Test 1** | M1 writes to Slave 0 | OKAY response | **PASS** |
| **Test 2** | M2 reads from Slave 1 | OKAY + data check | **PASS** |
| **Test 3** | Invalid address write | DECERR + slave isolation | **PASS** |
| **Test 4** | Invalid address read | DECERR + zero RDATA + slave isolation | **PASS** |
| **Test 5** | AW backpressure (4 cycles) | Correct completion | **PASS** |
| **Test 6** | W backpressure (4 cycles) | Correct completion | **PASS** |
| **Test 7** | B response backpressure (4 cycles) | OKAY response | **PASS** |
| **Test 8** | AR backpressure (4 cycles) | Correct completion | **PASS** |
| **Test 9** | R response backpressure (4 cycles) | OKAY + data check | **PASS** |
| **Test 10** | M1/M2/M3 WRR rotation | 3:2:1 quota sequence | **PASS** |
| **Test 11** | M0 continuous + 64-cycle aging | M1 served after threshold | **PASS** |
| **Test 12** | Concurrent read/write | Independent progress | **PASS** |
| **Test 13** | Reset during idle | All outputs zero | **PASS** |
| **Test 14** | Split AW/W handshake | Ownership locked after AWVALID drops | **PASS** |
| **Test 15** | VALID stability under backpressure | AWVALID/AWADDR stable 5 cycles | **PASS** |
| **Test 16** | Reset during active transaction | Clean recovery | **PASS** |
| **Test 17** | All 4 masters contend | M0 priority → WRR rotation | **PASS** |

**Total**: 47 assertions passed, 0 failed.

---

## 3. Formal Verification Properties (SymbiYosys / Z3)

| ID | Property | Type | Status |
|---|---|---|---|
| **A1** | `$onehot0` on master-facing AWREADY, WREADY, BVALID, ARREADY, RVALID | Assert | **PROVED** |
| **A2** | `$onehot0` on slave-facing AWVALID, WVALID, ARVALID | Assert | **PROVED** |
| **A3** | AWREADY/ARREADY implies active master request | Assert | **PROVED** |
| **A4** | `$onehot0` on response routing (BVALID, RVALID) | Assert | **PROVED** |
| **A5** | Reset clears all handshakes to zero | Assert | **PROVED** |
| **A6** | Write owner stable when `w_state != W_IDLE` | Assert | **PROVED** |
| **A7** | Read owner stable when `r_state != R_IDLE` | Assert | **PROVED** |
| **A8** | `write_arb_tx_done` only from `W_B_WAIT` | Assert | **PROVED** |
| **A9** | `read_arb_tx_done` only from `R_R_WAIT` | Assert | **PROVED** |
| **A10** | Write DECERR: invalid target → BRESP=2'b11 | Assert | **PROVED** |
| **A11** | Read DECERR: invalid target → RRESP=2'b11, RDATA=0 | Assert | **PROVED** |

All properties bounded-proved at depth 20 with 0 counterexamples.

---

## 4. Synthesis Statistics (Yosys 0.52)

- **Top Module**: `axi4lite_arbiter_top`
- **Total Mapped Cells**: 5313
- **Sequential (DFF/DFFE)**: 354
- **Combinational**: 4959
- **Inferred Latches**: 0
- **Check Pass Problems**: 0
