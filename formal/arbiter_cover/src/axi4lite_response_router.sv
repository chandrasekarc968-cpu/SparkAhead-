// =============================================================================
// File       : axi4lite_response_router.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: Combinational response routing for both write (B) and read (R)
//              channels. Routes slave responses to the correct transaction owner
//              master, and generates internal DECERR responses for unmapped
//              address transactions.
//
//              Write Response (B channel):
//                - Routes BRESP/BVALID from target slave to owner master
//                - Routes BREADY from owner master to target slave
//                - Generates BRESP=DECERR for invalid-address transactions
//
//              Read Response (R channel):
//                - Routes RDATA/RRESP/RVALID from target slave to owner master
//                - Routes RREADY from owner master to target slave
//                - Generates RRESP=DECERR, RDATA=0 for invalid-address transactions
//
//              All non-owner masters see deasserted BVALID/RVALID.
// =============================================================================

`timescale 1ns / 1ps

module axi4lite_response_router #(
    parameter int NUM_MASTERS = 4,
    parameter int NUM_SLAVES  = 2,
    parameter int DATA_WIDTH  = 32
) (
    // --- Write Response Control ---
    input  logic                                     w_active,       // Write FSM in response phase
    input  logic [$clog2(NUM_MASTERS)-1:0]           w_owner_id,     // Write transaction owner
    input  logic [NUM_SLAVES-1:0]                    w_target_slave, // One-hot target slave
    input  logic                                     w_target_invalid, // DECERR target

    // Write response from slaves
    input  logic [NUM_SLAVES-1:0][1:0]               s_bresp,
    input  logic [NUM_SLAVES-1:0]                    s_bvalid,
    // Write response control to slaves
    output logic [NUM_SLAVES-1:0]                    s_bready,

    // Write response to masters
    output logic [NUM_MASTERS-1:0][1:0]              m_bresp,
    output logic [NUM_MASTERS-1:0]                   m_bvalid,
    // Write response acknowledgment from masters
    input  logic [NUM_MASTERS-1:0]                   m_bready,

    // Write response handshake indicator
    output logic                                     w_resp_handshake, // BVALID && BREADY for owner

    // --- Read Response Control ---
    input  logic                                     r_active,       // Read FSM in response phase
    input  logic [$clog2(NUM_MASTERS)-1:0]           r_owner_id,     // Read transaction owner
    input  logic [NUM_SLAVES-1:0]                    r_target_slave, // One-hot target slave
    input  logic                                     r_target_invalid, // DECERR target

    // Read response from slaves
    input  logic [NUM_SLAVES-1:0][DATA_WIDTH-1:0]    s_rdata,
    input  logic [NUM_SLAVES-1:0][1:0]               s_rresp,
    input  logic [NUM_SLAVES-1:0]                    s_rvalid,
    // Read response control to slaves
    output logic [NUM_SLAVES-1:0]                    s_rready,

    // Read response to masters
    output logic [NUM_MASTERS-1:0][DATA_WIDTH-1:0]   m_rdata,
    output logic [NUM_MASTERS-1:0][1:0]              m_rresp,
    output logic [NUM_MASTERS-1:0]                   m_rvalid,
    // Read response acknowledgment from masters
    input  logic [NUM_MASTERS-1:0]                   m_rready,

    // Read response handshake indicator
    output logic                                     r_resp_handshake, // RVALID && RREADY for owner
    output logic                                     r_owner_rready    // Owner's RREADY
);

    localparam logic [1:0] RESP_DECERR = 2'b11;

    // =========================================================================
    // Write Response (B Channel) Routing
    // =========================================================================
    always_comb begin
        // Default: all deasserted
        for (int i = 0; i < NUM_MASTERS; i++) begin
            m_bresp[i]  = 2'b00;
            m_bvalid[i] = 1'b0;
        end
        for (int i = 0; i < NUM_SLAVES; i++) begin
            s_bready[i] = 1'b0;
        end
        w_resp_handshake = 1'b0;

        if (w_active) begin
            if (w_target_invalid) begin
                // Internal DECERR response
                m_bvalid[w_owner_id] = 1'b1;
                m_bresp[w_owner_id]  = RESP_DECERR;
                w_resp_handshake     = m_bready[w_owner_id];
            end else begin
                // Route from target slave to owner master
                if (w_target_slave[0]) begin
                    m_bvalid[w_owner_id] = s_bvalid[0];
                    m_bresp[w_owner_id]  = s_bresp[0];
                    s_bready[0]          = m_bready[w_owner_id];
                    w_resp_handshake     = s_bvalid[0] && m_bready[w_owner_id];
                end else if (w_target_slave[1]) begin
                    m_bvalid[w_owner_id] = s_bvalid[1];
                    m_bresp[w_owner_id]  = s_bresp[1];
                    s_bready[1]          = m_bready[w_owner_id];
                    w_resp_handshake     = s_bvalid[1] && m_bready[w_owner_id];
                end
            end
        end
    end

    // =========================================================================
    // Read Response (R Channel) Routing
    // =========================================================================
    always_comb begin
        // Default: all deasserted
        for (int i = 0; i < NUM_MASTERS; i++) begin
            m_rdata[i]  = '0;
            m_rresp[i]  = 2'b00;
            m_rvalid[i] = 1'b0;
        end
        for (int i = 0; i < NUM_SLAVES; i++) begin
            s_rready[i] = 1'b0;
        end
        r_resp_handshake = 1'b0;
        r_owner_rready   = 1'b0;

        if (r_active) begin
            r_owner_rready = m_rready[r_owner_id];

            if (r_target_invalid) begin
                // Internal DECERR response with zero data
                m_rvalid[r_owner_id] = 1'b1;
                m_rdata[r_owner_id]  = '0;
                m_rresp[r_owner_id]  = RESP_DECERR;
                r_resp_handshake     = m_rready[r_owner_id];
            end else begin
                // Route from target slave to owner master
                if (r_target_slave[0]) begin
                    m_rvalid[r_owner_id] = s_rvalid[0];
                    m_rdata[r_owner_id]  = s_rdata[0];
                    m_rresp[r_owner_id]  = s_rresp[0];
                    s_rready[0]          = m_rready[r_owner_id];
                    r_resp_handshake     = s_rvalid[0] && m_rready[r_owner_id];
                end else if (r_target_slave[1]) begin
                    m_rvalid[r_owner_id] = s_rvalid[1];
                    m_rdata[r_owner_id]  = s_rdata[1];
                    m_rresp[r_owner_id]  = s_rresp[1];
                    s_rready[1]          = m_rready[r_owner_id];
                    r_resp_handshake     = s_rvalid[1] && m_rready[r_owner_id];
                end
            end
        end
    end

    // =========================================================================
    // Synthesis-Safe Assertions
    // =========================================================================
`ifdef ASSERTIONS
    // Only one BVALID at a time
    always_comb begin
        assert ($onehot0(m_bvalid))
            else $error("[axi4lite_response_router] Multiple BVALID asserted!");
        assert ($onehot0(m_rvalid))
            else $error("[axi4lite_response_router] Multiple RVALID asserted!");
    end
`endif

endmodule
