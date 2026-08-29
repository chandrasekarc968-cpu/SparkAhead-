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

module resp_demux #(
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


    // Instantiate default slave for DECERR responses
    logic [1:0]            decerr_bresp;
    logic                  decerr_bvalid;
    logic [DATA_WIDTH-1:0] decerr_rdata;
    logic [1:0]            decerr_rresp;
    logic                  decerr_rvalid;

    default_slave #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_default_slave (
        .w_active         (w_active),
        .w_target_invalid (w_target_invalid),
        .decerr_bresp     (decerr_bresp),
        .decerr_bvalid    (decerr_bvalid),
        .r_active         (r_active),
        .r_target_invalid (r_target_invalid),
        .decerr_rdata     (decerr_rdata),
        .decerr_rresp     (decerr_rresp),
        .decerr_rvalid    (decerr_rvalid)
    );

    // =========================================================================
    // Write Response (B Channel) Routing
    // =========================================================================
    always_comb begin
        m_bresp          = '0;
        m_bvalid         = '0;
        s_bready         = '0;
        w_resp_handshake = 1'b0;

        if (w_active) begin
            if (w_target_invalid) begin
                // Internal DECERR response
                m_bvalid[w_owner_id] = decerr_bvalid;
                m_bresp[w_owner_id]  = decerr_bresp;
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
        m_rdata          = '0;
        m_rresp          = '0;
        m_rvalid         = '0;
        s_rready         = '0;
        r_resp_handshake = 1'b0;
        r_owner_rready   = 1'b0;

        if (r_active) begin
            r_owner_rready = m_rready[r_owner_id];

            if (r_target_invalid) begin
                // Internal DECERR response with zero data
                m_rvalid[r_owner_id] = decerr_rvalid;
                m_rdata[r_owner_id]  = decerr_rdata;
                m_rresp[r_owner_id]  = decerr_rresp;
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
        assert ($onehot0(m_bvalid));
            ;
        assert ($onehot0(m_rvalid));
            ;
    end
`endif

endmodule
