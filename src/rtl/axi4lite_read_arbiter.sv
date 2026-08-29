// =============================================================================
// File       : axi4lite_read_arbiter.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: Complete AXI4-Lite read path with:
//              - QoS scheduling via axi4lite_qos_scheduler
//              - Address decoding via axi4lite_address_decoder
//              - Read FSM: R_IDLE → R_ADDR → R_RESP → R_IDLE
//              - Locked transaction ownership through AR+R sequence
//              - Internal DECERR for unmapped addresses
//              - Slave-side mux for AR channel
//              - Conservative single-outstanding read policy
//
// Read Path Strategy:
//   When a master asserts ARVALID and is selected by the QoS scheduler,
//   the AR fields are latched and forwarded to the target slave. ARREADY
//   is given to the requesting master when the target slave accepts (or
//   immediately for DECERR). The owner is locked until the R response
//   handshake completes.
// =============================================================================

`timescale 1ns / 1ps

module axi4lite_read_arbiter #(
    parameter int NUM_MASTERS = 4,
    parameter int NUM_SLAVES  = 2,
    parameter int ADDR_WIDTH  = 32,
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

    // --- Master-Side Read Channels ---
    // AR (Read Address)
    input  logic [NUM_MASTERS-1:0][ADDR_WIDTH-1:0]   s_axi_araddr,
    input  logic [NUM_MASTERS-1:0][2:0]              s_axi_arprot,
    input  logic [NUM_MASTERS-1:0]                   s_axi_arvalid,
    output logic [NUM_MASTERS-1:0]                   s_axi_arready,

    // R Response — routed by response_router at top level
    // We expose owner/target info for the response router
    output logic [$clog2(NUM_MASTERS)-1:0]           r_owner_id,
    output logic [NUM_SLAVES-1:0]                    r_target_slave,
    output logic                                     r_target_invalid,
    output logic                                     r_resp_phase,     // 1 when in R_RESP state

    // Feedback from response router
    input  logic                                     r_resp_handshake, // R handshake done

    // --- Slave-Side Read Channels ---
    // AR to slaves
    output logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0]    m_axi_araddr,
    output logic [NUM_SLAVES-1:0][2:0]               m_axi_arprot,
    output logic [NUM_SLAVES-1:0]                    m_axi_arvalid,
    input  logic [NUM_SLAVES-1:0]                    m_axi_arready
);

    localparam int ID_W = $clog2(NUM_MASTERS);

    // =========================================================================
    // 1. Read FSM States
    // =========================================================================
    typedef enum logic [1:0] {
        R_IDLE = 2'b00,
        R_ADDR = 2'b01,
        R_RESP = 2'b10
    } read_state_t;

    read_state_t r_state;

    // Latched transaction metadata
    logic [ID_W-1:0]              owner_id_r;
    logic [NUM_SLAVES-1:0]        target_slave_r;
    logic                         target_invalid_r;
    logic [ADDR_WIDTH-1:0]        latched_addr;
    logic [2:0]                   latched_prot;

    // =========================================================================
    // 2. QoS Scheduler
    // =========================================================================
    logic                     arb_tx_done;
    logic [NUM_MASTERS-1:0]   arb_grant;
    logic [ID_W-1:0]          arb_master_id;
    logic                     arb_grant_valid;

    /* verilator lint_off UNUSEDSIGNAL */
    logic                     arb_starvation_unused;
    logic [NUM_MASTERS-1:0]   arb_grant_unused;
    /* verilator lint_on UNUSEDSIGNAL */

    assign arb_grant_unused = arb_grant;

    axi4lite_qos_scheduler #(
        .NUM_MASTERS (NUM_MASTERS)
    ) u_read_qos (
        .aclk                   (aclk),
        .aresetn                (aresetn),
        .cfg_weight_m0          (cfg_weight_m0),
        .cfg_weight_m1          (cfg_weight_m1),
        .cfg_weight_m2          (cfg_weight_m2),
        .cfg_weight_m3          (cfg_weight_m3),
        .cfg_master0_priority   (cfg_master0_priority),
        .cfg_age_threshold      (cfg_age_threshold),
        .cfg_master0_burst_limit(cfg_master0_burst_limit),
        .req                    (s_axi_arvalid),
        .transaction_complete   (arb_tx_done),
        .grant                  (arb_grant),
        .master_id              (arb_master_id),
        .grant_valid            (arb_grant_valid),
        .starvation_flag        (arb_starvation_unused)
    );

    // =========================================================================
    // 3. Address Decoder
    // =========================================================================
    logic [ADDR_WIDTH-1:0]    decode_addr;
    logic [1:0]               decode_slave_sel;
    logic                     decode_invalid;

    /* verilator lint_off UNUSEDSIGNAL */
    logic                     decode_valid_unused;
    /* verilator lint_on UNUSEDSIGNAL */

    // Decode the address of the master that the arbiter has selected
    always_comb begin
        decode_addr = '0;
        if (arb_grant_valid) begin
            decode_addr = s_axi_araddr[arb_master_id];
        end
    end

    axi4lite_address_decoder #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .S0_BASE    (S0_BASE),
        .S0_SIZE    (S0_SIZE),
        .S1_BASE    (S1_BASE),
        .S1_SIZE    (S1_SIZE)
    ) u_read_decoder (
        .addr         (decode_addr),
        .slave_sel    (decode_slave_sel),
        .valid_addr   (decode_valid_unused),
        .invalid_addr (decode_invalid)
    );

    // =========================================================================
    // 4. Target slave ready mux
    // =========================================================================
    logic target_arready;
    always_comb begin
        target_arready = 1'b0;
        if (target_slave_r[0]) target_arready = m_axi_arready[0];
        else if (target_slave_r[1]) target_arready = m_axi_arready[1];
    end

    // =========================================================================
    // 5. Read FSM
    // =========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            r_state          <= R_IDLE;
            owner_id_r       <= '0;
            target_slave_r   <= '0;
            target_invalid_r <= 1'b0;
            latched_addr     <= '0;
            latched_prot     <= '0;
            arb_tx_done      <= 1'b0;
        end else begin
            arb_tx_done <= 1'b0;

            case (r_state)
                R_IDLE: begin
                    if (arb_grant_valid) begin
                        if (s_axi_arvalid[arb_master_id]) begin
                            // Normal path: master still requesting
                            owner_id_r       <= arb_master_id;
                            latched_addr     <= s_axi_araddr[arb_master_id];
                            latched_prot     <= s_axi_arprot[arb_master_id];
                            target_slave_r   <= decode_slave_sel;
                            target_invalid_r <= decode_invalid;
                            r_state          <= R_ADDR;
                        end else begin
                            // B4 fix: Master dropped ARVALID before clock edge.
                            // Release the scheduler immediately to prevent deadlock.
                            // Do NOT enter R_ADDR — no transaction to service.
                            arb_tx_done <= 1'b1;
                        end
                    end
                end

                R_ADDR: begin
                    if (target_invalid_r) begin
                        // DECERR: give ARREADY immediately, go to response
                        r_state <= R_RESP;
                    end else if (target_arready) begin
                        // Slave accepted AR
                        r_state <= R_RESP;
                    end
                end

                R_RESP: begin
                    if (r_resp_handshake) begin
                        arb_tx_done <= 1'b1;
                        r_state     <= R_IDLE;
                    end
                end

                default: r_state <= R_IDLE;
            endcase
        end
    end

    // =========================================================================
    // 6. Master-Side ARREADY Demux
    // =========================================================================
    always_comb begin
        s_axi_arready = '0;

        if (r_state == R_ADDR) begin
            if (target_invalid_r) begin
                // DECERR: give ARREADY to owner immediately
                s_axi_arready[owner_id_r] = 1'b1;
            end else begin
                // Pass through slave ARREADY to owner
                if (target_slave_r[0])
                    s_axi_arready[owner_id_r] = m_axi_arready[0];
                else if (target_slave_r[1])
                    s_axi_arready[owner_id_r] = m_axi_arready[1];
            end
        end
    end

    // =========================================================================
    // 7. Slave-Side AR Output Mux
    // =========================================================================
    always_comb begin
        for (int s = 0; s < NUM_SLAVES; s++) begin
            m_axi_araddr[s]  = latched_addr;
            m_axi_arprot[s]  = latched_prot;
            m_axi_arvalid[s] = 1'b0;
        end

        if (r_state == R_ADDR && !target_invalid_r) begin
            if (target_slave_r[0]) m_axi_arvalid[0] = 1'b1;
            if (target_slave_r[1]) m_axi_arvalid[1] = 1'b1;
        end
    end

    // =========================================================================
    // 8. Output Assignments
    // =========================================================================
    assign r_owner_id       = owner_id_r;
    assign r_target_slave   = target_slave_r;
    assign r_target_invalid = target_invalid_r;
    assign r_resp_phase     = (r_state == R_RESP);

    // =========================================================================
    // 9. Synthesis-Safe Assertions
    // =========================================================================
`ifdef ASSERTIONS
    property p_r_owner_stable;
        @(posedge aclk) disable iff (!aresetn)
        (r_state != R_IDLE) |=> (owner_id_r == $past(owner_id_r));
    endproperty
    assert property (p_r_owner_stable)
        else $error("[axi4lite_read_arbiter] Read owner changed mid-transaction!");

    always_comb begin
        assert ($onehot0(m_axi_arvalid))
            else $error("[axi4lite_read_arbiter] Multiple slave ARVALID!");
        assert ($onehot0(s_axi_arready))
            else $error("[axi4lite_read_arbiter] Multiple master ARREADY!");
    end
`endif

endmodule
