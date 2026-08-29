// =============================================================================
// File       : axi4lite_pkg.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: Common constants, types, and helper definitions for the
//              AXI4-Lite interconnect. Each RTL module also defines its own
//              local constants for Icarus Verilog compatibility; this file
//              serves as a single-source reference and is available for
//              tools that support SystemVerilog packages.
// =============================================================================

`timescale 1ns / 1ps

package axi4lite_pkg;
    /* verilator lint_off UNUSEDPARAM */

    // -------------------------------------------------------------------------
    // AXI4-Lite Response Codes (ARM IHI 0022E §A3.4.4)
    // -------------------------------------------------------------------------
    localparam logic [1:0] RESP_OKAY   = 2'b00;  // Normal access success
    localparam logic [1:0] RESP_EXOKAY = 2'b01;  // Exclusive access okay
    localparam logic [1:0] RESP_SLVERR = 2'b10;  // Slave error
    localparam logic [1:0] RESP_DECERR = 2'b11;  // Decode error

    // -------------------------------------------------------------------------
    // Design Constants
    // -------------------------------------------------------------------------
    localparam int NUM_MASTERS       = 4;
    localparam int NUM_SLAVES        = 2;
    localparam int ADDR_WIDTH        = 32;
    localparam int DATA_WIDTH        = 32;
    localparam int STRB_WIDTH        = DATA_WIDTH / 8;
    localparam int MASTER_ID_WIDTH   = $clog2(NUM_MASTERS);  // 2 bits

    // -------------------------------------------------------------------------
    // Default Address Map
    // -------------------------------------------------------------------------
    localparam logic [ADDR_WIDTH-1:0] DEFAULT_S0_BASE = 32'h0000_0000;
    localparam logic [ADDR_WIDTH-1:0] DEFAULT_S0_SIZE = 32'h0001_0000;  // 64 KB
    localparam logic [ADDR_WIDTH-1:0] DEFAULT_S1_BASE = 32'h0001_0000;
    localparam logic [ADDR_WIDTH-1:0] DEFAULT_S1_SIZE = 32'h0001_0000;  // 64 KB

    // -------------------------------------------------------------------------
    // Default QoS Configuration
    // Spec: WRR_WEIGHTS = {4,2,1,1} for M0,M1,M2,M3
    // -------------------------------------------------------------------------
    localparam logic [3:0] DEFAULT_WEIGHT_M0       = 4'd4;
    localparam logic [3:0] DEFAULT_WEIGHT_M1       = 4'd2;
    localparam logic [3:0] DEFAULT_WEIGHT_M2       = 4'd1;
    localparam logic [3:0] DEFAULT_WEIGHT_M3       = 4'd1;
    localparam logic [7:0] DEFAULT_AGE_THRESHOLD   = 8'd64;
    localparam logic [7:0] DEFAULT_M0_BURST_LIMIT  = 8'd16;

    // -------------------------------------------------------------------------
    // Preemption Enable (PREEMPT_EN = 1)
    // -------------------------------------------------------------------------
    localparam int         DEFAULT_PREEMPT_EN      = 1;

    // -------------------------------------------------------------------------
    // Weight Clamping
    // Specification: valid weights are 1–15. Zero is clamped to 1.
    // -------------------------------------------------------------------------
    function automatic logic [3:0] clamp_weight(input logic [3:0] w);
        if (w == 4'd0)
            clamp_weight = 4'd1;
        else
            clamp_weight = w;
    endfunction

endpackage
