// =============================================================================
// File       : axi4lite_write_arbiter.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: Complete AXI4-Lite write path with:
//              - Independent per-master AW and W single-entry skid buffers
//              - Write eligibility: arbitrate only after both AW and W buffered
//              - QoS scheduling via axi4lite_qos_scheduler
//              - Address decoding via axi4lite_address_decoder
//              - Write FSM: W_IDLE → W_ADDR → W_DATA → W_RESP → W_IDLE
//              - Locked transaction ownership through AW+W+B sequence
//              - Internal DECERR for unmapped addresses
//              - Slave-side mux for AW and W channels
//              - Conservative single-outstanding write policy
//
// AW/W Buffering Strategy:
//   Each master has one AW buffer and one W buffer. When AWVALID is asserted
//   and the master's AW buffer is free, AWREADY is asserted and the AW fields
//   are captured. Similarly for W. AW and W may arrive in any order or
//   simultaneously. A master becomes eligible for write arbitration ONLY when
//   both its AW buffer and W buffer are valid. After the transaction completes
//   (B response accepted), both buffers are freed.
//
//   This ensures:
//     - AW from one master is never combined with W from another master
//     - The write address and data are always from the same master
//     - AW and W may arrive in different cycles
//     - No buffer is overwritten while in use
// =============================================================================

`timescale 1ns / 1ps

module write_arbiter #(
    parameter int NUM_MASTERS = 4,
    parameter int NUM_SLAVES  = 2,
    parameter int ADDR_WIDTH  = 32,
    parameter int DATA_WIDTH  = 32,
    parameter int STRB_WIDTH  = DATA_WIDTH / 8,
    // Address map
    parameter logic [ADDR_WIDTH-1:0] S0_BASE = 32'h0000_0000,
    parameter logic [ADDR_WIDTH-1:0] S0_SIZE = 32'h0001_0000,
    parameter logic [ADDR_WIDTH-1:0] S1_BASE = 32'h0001_0000,
    parameter logic [ADDR_WIDTH-1:0] S1_SIZE = 32'h0001_0000
) (
    input  logic                                     aclk,
    input  logic                                     aresetn,

    // --- Runtime QoS Configuration ---
    input  logic [3:0]                               cfg_weight_m0,
    input  logic [3:0]                               cfg_weight_m1,
    input  logic [3:0]                               cfg_weight_m2,
    input  logic [3:0]                               cfg_weight_m3,
    input  logic                                     cfg_master0_priority,
    input  logic [7:0]                               cfg_age_threshold,
    input  logic [7:0]                               cfg_master0_burst_limit,

    // --- Master-Side Write Channels ---
    // AW (Write Address)
    input  logic [NUM_MASTERS-1:0][ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  logic [NUM_MASTERS-1:0][2:0]              s_axi_awprot,
    input  logic [NUM_MASTERS-1:0]                   s_axi_awvalid,
    output logic [NUM_MASTERS-1:0]                   s_axi_awready,

    // W (Write Data)
    input  logic [NUM_MASTERS-1:0][DATA_WIDTH-1:0]   s_axi_wdata,
    input  logic [NUM_MASTERS-1:0][STRB_WIDTH-1:0]   s_axi_wstrb,
    input  logic [NUM_MASTERS-1:0]                   s_axi_wvalid,
    output logic [NUM_MASTERS-1:0]                   s_axi_wready,

    // B (Write Response) — routed by response_router at top level
    // We expose owner/target info for the response router
    output logic [$clog2(NUM_MASTERS)-1:0]           w_owner_id,
    output logic [NUM_SLAVES-1:0]                    w_target_slave,
    output logic                                     w_target_invalid,
    output logic                                     w_resp_phase,     // 1 when in W_RESP state

    // Feedback from response router
    input  logic                                     w_resp_handshake, // B handshake done

    // --- Slave-Side Write Channels ---
    // AW to slaves
    output logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0]    m_axi_awaddr,
    output logic [NUM_SLAVES-1:0][2:0]               m_axi_awprot,
    output logic [NUM_SLAVES-1:0]                    m_axi_awvalid,
    input  logic [NUM_SLAVES-1:0]                    m_axi_awready,

    // W to slaves
    output logic [NUM_SLAVES-1:0][DATA_WIDTH-1:0]    m_axi_wdata,
    output logic [NUM_SLAVES-1:0][STRB_WIDTH-1:0]    m_axi_wstrb,
    output logic [NUM_SLAVES-1:0]                    m_axi_wvalid,
    input  logic [NUM_SLAVES-1:0]                    m_axi_wready
);

    localparam int ID_W = $clog2(NUM_MASTERS);

    // =========================================================================
    // 1. Per-Master AW and W Buffers
    // =========================================================================
    // AW buffers
    logic [NUM_MASTERS-1:0]                    aw_buf_valid;
    logic [NUM_MASTERS-1:0][ADDR_WIDTH-1:0]    aw_buf_addr;
    logic [NUM_MASTERS-1:0][2:0]               aw_buf_prot;

    // W buffers
    logic [NUM_MASTERS-1:0]                    w_buf_valid;
    logic [NUM_MASTERS-1:0][DATA_WIDTH-1:0]    w_buf_data;
    logic [NUM_MASTERS-1:0][STRB_WIDTH-1:0]    w_buf_strb;

    // Write eligibility: both AW and W buffered
    logic [NUM_MASTERS-1:0] write_eligible;

    // Buffer currently locked by in-flight transaction
    logic [NUM_MASTERS-1:0] buf_locked;

    // =========================================================================
    // 2. Write FSM States
    // =========================================================================
    typedef enum logic [1:0] {
        W_IDLE = 2'b00,
        W_ADDR = 2'b01,
        W_DATA = 2'b10,
        W_RESP = 2'b11
    } write_state_t;

    write_state_t w_state;

    // Latched transaction metadata
    logic [ID_W-1:0]              w_owner_id_r;
    logic [NUM_SLAVES-1:0]        w_target_slave_r;
    logic                         w_target_invalid_r;
    logic [ADDR_WIDTH-1:0]        latched_addr;
    logic [2:0]                   latched_prot;
    logic [DATA_WIDTH-1:0]        latched_wdata;
    logic [STRB_WIDTH-1:0]        latched_wstrb;

    // =========================================================================
    // 3. QoS Scheduler
    // =========================================================================
    logic                     arb_tx_done;
    assign arb_tx_done = (w_state == W_RESP) && w_resp_handshake;
    logic [ID_W-1:0]          arb_master_id;
    logic                     arb_grant_valid;

    /* verilator lint_off UNUSEDSIGNAL */
    logic                     arb_starvation_unused;
    /* verilator lint_on UNUSEDSIGNAL */

    /* verilator lint_off PINCONNECTEMPTY */
    wrr_scheduler #(
        .NUM_MASTERS (NUM_MASTERS)
    ) u_write_qos (
        .aclk                   (aclk),
        .aresetn                (aresetn),
        .cfg_weight_m0          (cfg_weight_m0),
        .cfg_weight_m1          (cfg_weight_m1),
        .cfg_weight_m2          (cfg_weight_m2),
        .cfg_weight_m3          (cfg_weight_m3),
        .cfg_master0_priority   (cfg_master0_priority),
        .cfg_age_threshold      (cfg_age_threshold),
        .cfg_master0_burst_limit(cfg_master0_burst_limit),
        .req                    (write_eligible),
        .transaction_complete   (arb_tx_done),
        .grant                  (),
        .master_id              (arb_master_id),
        .grant_valid            (arb_grant_valid),
        .starvation_flag        (arb_starvation_unused)
    );
    /* verilator lint_on PINCONNECTEMPTY */

    // =========================================================================
    // 4. Address Decoder (Decode the selected master's buffered AW address)
    // =========================================================================
    logic [ADDR_WIDTH-1:0]    decode_addr;
    logic [1:0]               decode_slave_sel;
    logic                     decode_invalid;

    /* verilator lint_off UNUSEDSIGNAL */
    logic                     decode_valid_unused;
    /* verilator lint_on UNUSEDSIGNAL */

    // Use the buffered address from the granted master
    always_comb begin
        decode_addr = '0;
        if (arb_grant_valid) begin
            decode_addr = aw_buf_addr[arb_master_id];
        end
    end

    addr_decoder #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .S0_BASE    (S0_BASE),
        .S0_SIZE    (S0_SIZE),
        .S1_BASE    (S1_BASE),
        .S1_SIZE    (S1_SIZE)
    ) u_write_decoder (
        .addr         (decode_addr),
        .slave_sel    (decode_slave_sel),
        .valid_addr   (decode_valid_unused),
        .invalid_addr (decode_invalid)
    );

    // =========================================================================
    // 5. Buffer Acceptance Logic
    // =========================================================================
    // Accept AW and W independently into buffers.
    // AWREADY[m] = 1 when AW buffer for master m is free (not valid and not locked).
    // WREADY[m] = 1 when W buffer for master m is free (not valid and not locked).
    // Buffer is locked when the master's transaction is in-flight (selected and FSM busy).

    always_comb begin
        for (int m = 0; m < NUM_MASTERS; m++) begin
            buf_locked[m] = (w_state != W_IDLE) && (w_owner_id_r == ID_W'(m));
        end
    end

    always_comb begin
        for (int m = 0; m < NUM_MASTERS; m++) begin
            s_axi_awready[m] = !aw_buf_valid[m] && !buf_locked[m];
            s_axi_wready[m]  = !w_buf_valid[m]  && !buf_locked[m];
        end
    end

    // Eligibility: both AW and W buffered, and not currently locked
    always_comb begin
        for (int m = 0; m < NUM_MASTERS; m++) begin
            write_eligible[m] = aw_buf_valid[m] && w_buf_valid[m] && !buf_locked[m];
        end
    end

    // =========================================================================
    // 6. Buffer Capture and FSM
    // =========================================================================
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            aw_buf_valid     <= '0;
            w_buf_valid      <= '0;
            for (int m = 0; m < NUM_MASTERS; m++) begin
                aw_buf_addr[m] <= '0;
                aw_buf_prot[m] <= '0;
                w_buf_data[m]  <= '0;
                w_buf_strb[m]  <= '0;
            end
            w_state          <= W_IDLE;
            w_owner_id_r       <= '0;
            w_target_slave_r   <= '0;
            w_target_invalid_r <= 1'b0;
            latched_addr     <= '0;
            latched_prot     <= '0;
            latched_wdata    <= '0;
            latched_wstrb    <= '0;
        end else begin

            // -----------------------------------------------------------------
            // AW Buffer Capture (independent of FSM state)
            // -----------------------------------------------------------------
            for (int m = 0; m < NUM_MASTERS; m++) begin
                if (s_axi_awvalid[m] && s_axi_awready[m]) begin
                    aw_buf_valid[m] <= 1'b1;
                    aw_buf_addr[m]  <= s_axi_awaddr[m];
                    aw_buf_prot[m]  <= s_axi_awprot[m];
                end
            end

            // -----------------------------------------------------------------
            // W Buffer Capture (independent of FSM state)
            // -----------------------------------------------------------------
            for (int m = 0; m < NUM_MASTERS; m++) begin
                if (s_axi_wvalid[m] && s_axi_wready[m]) begin
                    w_buf_valid[m] <= 1'b1;
                    w_buf_data[m]  <= s_axi_wdata[m];
                    w_buf_strb[m]  <= s_axi_wstrb[m];
                end
            end

            // -----------------------------------------------------------------
            // Write FSM
            // -----------------------------------------------------------------
            case (w_state)
                W_IDLE: begin
                    if (arb_grant_valid) begin
                        // Latch transaction metadata from buffers
                        w_owner_id_r       <= arb_master_id;
                        latched_addr     <= aw_buf_addr[arb_master_id];
                        latched_prot     <= aw_buf_prot[arb_master_id];
                        latched_wdata    <= w_buf_data[arb_master_id];
                        latched_wstrb    <= w_buf_strb[arb_master_id];
                        w_target_slave_r   <= decode_slave_sel;
                        w_target_invalid_r <= decode_invalid;
                        w_state          <= W_ADDR;
                    end
                end

                W_ADDR: begin
                    if (w_target_invalid_r) begin
                        // DECERR: skip slave AW, go straight to W_DATA
                        w_state <= W_DATA;
                    end else begin
                        // Wait for target slave to accept AW
                        if ((w_target_slave_r[0] && m_axi_awready[0]) ||
                            (w_target_slave_r[1] && m_axi_awready[1])) begin
                            w_state <= W_DATA;
                        end
                    end
                end

                W_DATA: begin
                    if (w_target_invalid_r) begin
                        // DECERR: skip slave W, go straight to W_RESP
                        w_state <= W_RESP;
                    end else begin
                        // Wait for target slave to accept W
                        if ((w_target_slave_r[0] && m_axi_wready[0]) ||
                            (w_target_slave_r[1] && m_axi_wready[1])) begin
                            w_state <= W_RESP;
                        end
                    end
                end

                W_RESP: begin
                    if (w_resp_handshake) begin
                        // Transaction complete — free buffers
                        aw_buf_valid[w_owner_id_r] <= 1'b0;
                        w_buf_valid[w_owner_id_r]  <= 1'b0;
                        w_state                  <= W_IDLE;
                    end
                end

            endcase
        end
    end

    write_mux #(
        .NUM_SLAVES(NUM_SLAVES),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .STRB_WIDTH(STRB_WIDTH)
    ) u_write_mux (
        .latched_awaddr  (latched_addr),
        .latched_awprot  (latched_prot),
        .latched_wdata   (latched_wdata),
        .latched_wstrb   (latched_wstrb),
        .w_state_is_addr (w_state == W_ADDR),
        .w_state_is_data (w_state == W_DATA),
        .target_slave_r  (w_target_slave_r),
        .target_invalid_r(w_target_invalid_r),
        .m_axi_awaddr    (m_axi_awaddr),
        .m_axi_awprot    (m_axi_awprot),
        .m_axi_awvalid   (m_axi_awvalid),
        .m_axi_wdata     (m_axi_wdata),
        .m_axi_wstrb     (m_axi_wstrb),
        .m_axi_wvalid    (m_axi_wvalid)
    );

    // =========================================================================
    // 9. Output Assignments
    // =========================================================================
    assign w_owner_id      = w_owner_id_r;
    assign w_target_slave  = w_target_slave_r;
    assign w_target_invalid = w_target_invalid_r;
    assign w_resp_phase    = (w_state == W_RESP);

    // =========================================================================
    // 10. Synthesis-Safe Assertions
    // =========================================================================
`ifdef ASSERTIONS
    // Owner must not change while FSM is active
    property p_w_owner_stable;
        @(posedge aclk) disable iff (!aresetn)
        (w_state != W_IDLE) |=> (w_owner_id_r == $past(w_owner_id_r));
    endproperty
    assert property (p_w_owner_stable) 

    // No buffer overwrite: AW buffer not written while valid
    property p_no_aw_overwrite;
        @(posedge aclk) disable iff (!aresetn)
        (aw_buf_valid[0] && s_axi_awvalid[0]) |-> !s_axi_awready[0];
    endproperty
    assert property (p_no_aw_overwrite) 

    // At most one slave AWVALID
    always_comb begin
        assert ($onehot0(m_axi_awvalid)); 
        assert ($onehot0(m_axi_wvalid)); 
    end
`endif

endmodule
