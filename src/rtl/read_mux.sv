// =============================================================================
// File       : read_mux.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: Slave-side multiplexing for the Read Address (AR) channel.
// =============================================================================

`timescale 1ns / 1ps

module read_mux #(
    parameter int NUM_SLAVES = 2,
    parameter int ADDR_WIDTH = 32
) (
    input  logic [ADDR_WIDTH-1:0]           latched_araddr,
    input  logic [2:0]                      latched_arprot,
    
    input  logic                            r_state_is_addr,
    input  logic [NUM_SLAVES-1:0]           target_slave_r,
    input  logic                            target_invalid_r,

    output logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0] m_axi_araddr,
    output logic [NUM_SLAVES-1:0][2:0]            m_axi_arprot,
    output logic [NUM_SLAVES-1:0]                 m_axi_arvalid
);

    always_comb begin
        m_axi_araddr  = {NUM_SLAVES{latched_araddr}};
        m_axi_arprot  = {NUM_SLAVES{latched_arprot}};
        m_axi_arvalid = '0;

        m_axi_arvalid = (r_state_is_addr && !target_invalid_r) ? target_slave_r : '0;
    end

endmodule
