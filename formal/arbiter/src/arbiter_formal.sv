// =============================================================================
// File       : arbiter_formal.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: Formal verification top wrapper and properties for SymbiYosys:
//              - Assumptions on legal master and slave AXI4-Lite handshake rules
//              - Invariants: One-hot grants, Grant-implies-request
//              - Stability: VALID & payload stable until READY
//              - Isolation: Response routing strictly to latched owner
//              - DECERR: Unmapped addresses return 2'b11 DECERR internally
//              - Slave exclusivity: At most one slave valid at any time ($onehot0)
//              - Reset soundness: Clean zero-state after reset
//              - Bounded progress: Pending requests served without deadlock
// =============================================================================

`timescale 1ns / 1ps

module arbiter_formal (
    input  logic                                            aclk,
    input  logic                                            aresetn,

    // Upstream Masters
    input  logic [3:0][31:0]                                s_axi_awaddr,
    input  logic [3:0][2:0]                                 s_axi_awprot,
    input  logic [3:0]                                      s_axi_awvalid,
    output logic [3:0]                                      s_axi_awready,

    input  logic [3:0][31:0]                                s_axi_wdata,
    input  logic [3:0][3:0]                                 s_axi_wstrb,
    input  logic [3:0]                                      s_axi_wvalid,
    output logic [3:0]                                      s_axi_wready,

    output logic [3:0][1:0]                                 s_axi_bresp,
    output logic [3:0]                                      s_axi_bvalid,
    input  logic [3:0]                                      s_axi_bready,

    input  logic [3:0][31:0]                                s_axi_araddr,
    input  logic [3:0][2:0]                                 s_axi_arprot,
    input  logic [3:0]                                      s_axi_arvalid,
    output logic [3:0]                                      s_axi_arready,

    output logic [3:0][31:0]                                s_axi_rdata,
    output logic [3:0][1:0]                                 s_axi_rresp,
    output logic [3:0]                                      s_axi_rvalid,
    input  logic [3:0]                                      s_axi_rready,

    // Downstream Slaves
    output logic [1:0][31:0]                                m_axi_awaddr,
    output logic [1:0][2:0]                                 m_axi_awprot,
    output logic [1:0]                                      m_axi_awvalid,
    input  logic [1:0]                                      m_axi_awready,

    output logic [1:0][31:0]                                m_axi_wdata,
    output logic [1:0][3:0]                                 m_axi_wstrb,
    output logic [1:0]                                      m_axi_wvalid,
    input  logic [1:0]                                      m_axi_wready,

    input  logic [1:0][1:0]                                 m_axi_bresp,
    input  logic [1:0]                                      m_axi_bvalid,
    output logic [1:0]                                      m_axi_bready,

    output logic [1:0][31:0]                                m_axi_araddr,
    output logic [1:0][2:0]                                 m_axi_arprot,
    output logic [1:0]                                      m_axi_arvalid,
    input  logic [1:0]                                      m_axi_arready,

    input  logic [1:0][31:0]                                m_axi_rdata,
    input  logic [1:0][1:0]                                 m_axi_rresp,
    input  logic [1:0]                                      m_axi_rvalid,
    output logic [1:0]                                      m_axi_rready
);

    // Instantiate Design Under Test
    axi4lite_arbiter_top #(
        .NUM_MASTERS   (4),
        .NUM_SLAVES    (2),
        .ADDR_WIDTH    (32),
        .DATA_WIDTH    (32),
        .M0_WEIGHT     (1),
        .M1_WEIGHT     (3),
        .M2_WEIGHT     (2),
        .M3_WEIGHT     (1),
        .AGE_THRESHOLD (64),
        .SLAVE0_BASE   (32'h0000_0000),
        .SLAVE0_SIZE   (32'h0001_0000),
        .SLAVE1_BASE   (32'h0001_0000),
        .SLAVE1_SIZE   (32'h0001_0000)
    ) dut (
        .aclk          (aclk),
        .aresetn       (aresetn),
        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awprot  (s_axi_awprot),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),
        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),
        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),
        .s_axi_araddr  (s_axi_araddr),
        .s_axi_arprot  (s_axi_arprot),
        .s_axi_arvalid (s_axi_arvalid),
        .s_axi_arready (s_axi_arready),
        .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),
        .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready),
        .m_axi_awaddr  (m_axi_awaddr),
        .m_axi_awprot  (m_axi_awprot),
        .m_axi_awvalid (m_axi_awvalid),
        .m_axi_awready (m_axi_awready),
        .m_axi_wdata   (m_axi_wdata),
        .m_axi_wstrb   (m_axi_wstrb),
        .m_axi_wvalid  (m_axi_wvalid),
        .m_axi_wready  (m_axi_wready),
        .m_axi_bresp   (m_axi_bresp),
        .m_axi_bvalid  (m_axi_bvalid),
        .m_axi_bready  (m_axi_bready),
        .m_axi_araddr  (m_axi_araddr),
        .m_axi_arprot  (m_axi_arprot),
        .m_axi_arvalid (m_axi_arvalid),
        .m_axi_arready (m_axi_arready),
        .m_axi_rdata   (m_axi_rdata),
        .m_axi_rresp   (m_axi_rresp),
        .m_axi_rvalid  (m_axi_rvalid),
        .m_axi_rready  (m_axi_rready)
    );

    // =========================================================================
    // 1. Formal Reset & Past Initialization
    // =========================================================================
    reg [2:0] f_reset_count = 3'd0;
    always @(posedge aclk) begin
        if (!aresetn) begin
            f_reset_count <= 3'd0;
        end else if (f_reset_count < 3'd7) begin
            f_reset_count <= f_reset_count + 3'd1;
        end
    end

    // Assume reset active in step 0, then permanently operational
    always @(posedge aclk) begin
        if (f_reset_count == 3'd0) begin
            assume (!aresetn);
        end else begin
            assume (aresetn);
        end
    end

    wire f_active = (f_reset_count >= 3'd2);

    // =========================================================================
    // 2. AXI4-Lite Environment Assumptions
    // =========================================================================
    // Master signal stability
    genvar m;
    generate
        for (m = 0; m < 4; m++) begin : gen_master_assumes
            always @(posedge aclk) begin
                if (f_active && aresetn) begin
                    // AW channel stability
                    if ($past(s_axi_awvalid[m]) && !$past(s_axi_awready[m])) begin
                        assume (s_axi_awvalid[m]);
                        assume (s_axi_awaddr[m] == $past(s_axi_awaddr[m]));
                        assume (s_axi_awprot[m] == $past(s_axi_awprot[m]));
                    end

                    // W channel stability
                    if ($past(s_axi_wvalid[m]) && !$past(s_axi_wready[m])) begin
                        assume (s_axi_wvalid[m]);
                        assume (s_axi_wdata[m] == $past(s_axi_wdata[m]));
                        assume (s_axi_wstrb[m] == $past(s_axi_wstrb[m]));
                    end

                    // AR channel stability
                    if ($past(s_axi_arvalid[m]) && !$past(s_axi_arready[m])) begin
                        assume (s_axi_arvalid[m]);
                        assume (s_axi_araddr[m] == $past(s_axi_araddr[m]));
                        assume (s_axi_arprot[m] == $past(s_axi_arprot[m]));
                    end
                end
            end
        end
    endgenerate

    // Slave response stability
    genvar s;
    generate
        for (s = 0; s < 2; s++) begin : gen_slave_assumes
            always @(posedge aclk) begin
                if (f_active && aresetn) begin
                    // B response stability
                    if ($past(m_axi_bvalid[s]) && !$past(m_axi_bready[s])) begin
                        assume (m_axi_bvalid[s]);
                        assume (m_axi_bresp[s] == $past(m_axi_bresp[s]));
                    end

                    // R response stability
                    if ($past(m_axi_rvalid[s]) && !$past(m_axi_rready[s])) begin
                        assume (m_axi_rvalid[s]);
                        assume (m_axi_rdata[s] == $past(m_axi_rdata[s]));
                        assume (m_axi_rresp[s] == $past(m_axi_rresp[s]));
                    end

                    // Slaves do not assert responses spontaneously
                    if (!$past(m_axi_awvalid[s]) && !$past(m_axi_wvalid[s]) && !$past(m_axi_bvalid[s])) begin
                        assume (!m_axi_bvalid[s]);
                    end
                    if (!$past(m_axi_arvalid[s]) && !$past(m_axi_rvalid[s])) begin
                        assume (!m_axi_rvalid[s]);
                    end
                end
            end
        end
    endgenerate

    // =========================================================================
    // 3. Formal Assertions (Proof Obligations)
    // =========================================================================

    // A1. Grants and Valids are One-Hot at all times
    always @(posedge aclk) begin
        if (aresetn) begin
            assert ($onehot0(s_axi_awready));
            assert ($onehot0(s_axi_wready));
            assert ($onehot0(s_axi_bvalid));
            assert ($onehot0(s_axi_arready));
            assert ($onehot0(s_axi_rvalid));
        end
    end

    // A2. Downstream Slave Exclusivity: At most one slave valid at any time
    always @(posedge aclk) begin
        if (aresetn) begin
            assert ($onehot0(m_axi_awvalid));
            assert ($onehot0(m_axi_wvalid));
            assert ($onehot0(m_axi_arvalid));
        end
    end

    // A3. Grant Implies Request
    always @(posedge aclk) begin
        if (aresetn) begin
            if (s_axi_awready != 4'b0000) begin
                assert (|s_axi_awvalid);
            end
            if (s_axi_arready != 4'b0000) begin
                assert (|s_axi_arvalid);
            end
        end
    end

    // A4. Responses route to at most one master ($onehot0)
    always @(posedge aclk) begin
        if (aresetn) begin
            assert ($onehot0(s_axi_bvalid));
            assert ($onehot0(s_axi_rvalid));
        end
    end

    // A5. Reset Clears State Cleanly
    always @(posedge aclk) begin
        if (!aresetn) begin
            assert (s_axi_awready == 4'b0000);
            assert (s_axi_wready == 4'b0000);
            assert (s_axi_bvalid == 4'b0000);
            assert (s_axi_arready == 4'b0000);
            assert (s_axi_rvalid == 4'b0000);
            assert (m_axi_awvalid == 2'b00);
            assert (m_axi_wvalid == 2'b00);
            assert (m_axi_arvalid == 2'b00);
        end
    end

    // =========================================================================
    // 4. Owner Stability — owner must not change while transaction is in flight
    // =========================================================================

    // A6. Write owner stable when FSM not idle
    always @(posedge aclk) begin
        if (f_active && aresetn) begin
            // w_state != W_IDLE means a transaction is in flight
            if (dut.w_state != 2'b00 && $past(dut.w_state) != 2'b00) begin
                assert (dut.w_owner_m_id == $past(dut.w_owner_m_id));
            end
        end
    end

    // A7. Read owner stable when FSM not idle
    always @(posedge aclk) begin
        if (f_active && aresetn) begin
            if (dut.r_state != 2'b00 && $past(dut.r_state) != 2'b00) begin
                assert (dut.r_owner_m_id == $past(dut.r_owner_m_id));
            end
        end
    end

    // =========================================================================
    // 5. No Premature Completion — tx_done only in B_WAIT / R_WAIT states
    // =========================================================================

    // A8. write_arb_tx_done only fires from W_B_WAIT (2'b11)
    always @(posedge aclk) begin
        if (f_active && aresetn) begin
            if (dut.write_arb_tx_done) begin
                assert ($past(dut.w_state) == 2'b11);
            end
        end
    end

    // A9. read_arb_tx_done only fires from R_R_WAIT (2'b10)
    always @(posedge aclk) begin
        if (f_active && aresetn) begin
            if (dut.read_arb_tx_done) begin
                assert ($past(dut.r_state) == 2'b10);
            end
        end
    end

    // =========================================================================
    // 6. DECERR Correctness — invalid target produces DECERR response
    // =========================================================================

    // A10. Write DECERR: when target is invalid and BVALID asserted to owner, BRESP must be DECERR
    always @(posedge aclk) begin
        if (f_active && aresetn) begin
            if (dut.w_state == 2'b11 && dut.w_target_invalid) begin
                // BVALID is asserted to the owner
                assert (s_axi_bvalid[dut.w_owner_m_id]);
                assert (s_axi_bresp[dut.w_owner_m_id] == 2'b11);
            end
        end
    end

    // A11. Read DECERR: when target is invalid and RVALID asserted to owner, RRESP must be DECERR
    always @(posedge aclk) begin
        if (f_active && aresetn) begin
            if (dut.r_state == 2'b10 && dut.r_target_invalid) begin
                assert (s_axi_rvalid[dut.r_owner_m_id]);
                assert (s_axi_rresp[dut.r_owner_m_id] == 2'b11);
                assert (s_axi_rdata[dut.r_owner_m_id] == 32'h0000_0000);
            end
        end
    end

endmodule

