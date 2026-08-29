// =============================================================================
// File       : write_mux.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: Slave-side multiplexing for the Write Address (AW) and Write
//              Data (W) channels.
// =============================================================================

`timescale 1ns / 1ps

module write_mux #(
    parameter int NUM_SLAVES = 2,
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int STRB_WIDTH = DATA_WIDTH / 8
) (
    input  logic [ADDR_WIDTH-1:0]           latched_awaddr,
    input  logic [2:0]                      latched_awprot,
    input  logic [DATA_WIDTH-1:0]           latched_wdata,
    input  logic [STRB_WIDTH-1:0]           latched_wstrb,
    
    input  logic                            w_state_is_addr,
    input  logic                            w_state_is_data,
    input  logic [NUM_SLAVES-1:0]           target_slave_r,
    input  logic                            target_invalid_r,

    output logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0] m_axi_awaddr,
    output logic [NUM_SLAVES-1:0][2:0]            m_axi_awprot,
    output logic [NUM_SLAVES-1:0]                 m_axi_awvalid,

    output logic [NUM_SLAVES-1:0][DATA_WIDTH-1:0] m_axi_wdata,
    output logic [NUM_SLAVES-1:0][STRB_WIDTH-1:0] m_axi_wstrb,
    output logic [NUM_SLAVES-1:0]                 m_axi_wvalid
);

    always_comb begin
        m_axi_awaddr  = {NUM_SLAVES{latched_awaddr}};
        m_axi_awprot  = {NUM_SLAVES{latched_awprot}};
        m_axi_awvalid = '0;

        m_axi_wdata   = {NUM_SLAVES{latched_wdata}};
        m_axi_wstrb   = {NUM_SLAVES{latched_wstrb}};
        m_axi_wvalid  = '0;

        // AW Phase Mux
        m_axi_awvalid = (w_state_is_addr && !target_invalid_r) ? target_slave_r : '0;

        // W Phase Mux
        m_axi_wvalid = (w_state_is_data && !target_invalid_r) ? target_slave_r : '0;
    end

endmodule
