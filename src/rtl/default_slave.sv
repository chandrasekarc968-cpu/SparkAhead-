// =============================================================================
// File       : default_slave.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: Internal default slave that handles DECERR generation for
//              unmapped addresses.
// =============================================================================

`timescale 1ns / 1ps

module default_slave #(
    parameter int DATA_WIDTH = 32
) (
    input  logic                      w_active,
    input  logic                      w_target_invalid,
    output logic [1:0]                decerr_bresp,
    output logic                      decerr_bvalid,
    
    input  logic                      r_active,
    input  logic                      r_target_invalid,
    output logic [DATA_WIDTH-1:0]     decerr_rdata,
    output logic [1:0]                decerr_rresp,
    output logic                      decerr_rvalid
);

    always_comb begin
        // Write Response DECERR
        decerr_bresp  = 2'b11; // DECERR
        decerr_bvalid = w_active && w_target_invalid;

        // Read Response DECERR
        decerr_rdata  = '0;
        decerr_rresp  = 2'b11; // DECERR
        decerr_rvalid = r_active && r_target_invalid;
    end

endmodule
