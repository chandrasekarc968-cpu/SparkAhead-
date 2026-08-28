// =============================================================================
// File       : axi4lite_address_decoder.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: Parameterized combinational address decoder for 2 AXI4-Lite
//              slave regions. Produces a one-hot slave select and an invalid
//              flag for unmapped addresses (triggers internal DECERR).
//
//              Address Map (compile-time configurable):
//                Slave 0: [S0_BASE, S0_BASE + S0_SIZE - 1]
//                Slave 1: [S1_BASE, S1_BASE + S1_SIZE - 1]
//                All other: invalid → DECERR
//
//              If regions overlap, Slave 0 has decode priority.
// =============================================================================

`timescale 1ns / 1ps

module axi4lite_address_decoder #(
    parameter int ADDR_WIDTH = 32,
    parameter logic [ADDR_WIDTH-1:0] S0_BASE = 32'h0000_0000,
    parameter logic [ADDR_WIDTH-1:0] S0_SIZE = 32'h0001_0000,
    parameter logic [ADDR_WIDTH-1:0] S1_BASE = 32'h0001_0000,
    parameter logic [ADDR_WIDTH-1:0] S1_SIZE = 32'h0001_0000
) (
    input  logic [ADDR_WIDTH-1:0] addr,
    output logic [1:0]            slave_sel,     // One-hot: bit 0 → S0, bit 1 → S1
    output logic                  valid_addr,    // 1 if address maps to a valid slave
    output logic                  invalid_addr   // 1 if address is unmapped (DECERR)
);

    // Internal match signals
    logic match_s0;
    logic match_s1;

    // Use 64-bit arithmetic to prevent 32-bit wrap-around at boundary
    /* verilator lint_off UNSIGNED */
    always_comb begin
        // --- Slave 0 region check ---
        if (S0_SIZE > 0 &&
            (64'(addr) >= 64'(S0_BASE)) &&
            (64'(addr) <  (64'(S0_BASE) + 64'(S0_SIZE)))) begin
            match_s0 = 1'b1;
        end else begin
            match_s0 = 1'b0;
        end

        // --- Slave 1 region check ---
        if (S1_SIZE > 0 &&
            (64'(addr) >= 64'(S1_BASE)) &&
            (64'(addr) <  (64'(S1_BASE) + 64'(S1_SIZE)))) begin
            match_s1 = 1'b1;
        end else begin
            match_s1 = 1'b0;
        end

        // --- Priority decode: S0 > S1 ---
        if (match_s0) begin
            slave_sel    = 2'b01;
            valid_addr   = 1'b1;
            invalid_addr = 1'b0;
        end else if (match_s1) begin
            slave_sel    = 2'b10;
            valid_addr   = 1'b1;
            invalid_addr = 1'b0;
        end else begin
            slave_sel    = 2'b00;
            valid_addr   = 1'b0;
            invalid_addr = 1'b1;
        end
    end
    /* verilator lint_on UNSIGNED */

`ifdef ASSERTIONS
    // slave_sel must be one-hot-zero
    always_comb begin
        assert ($onehot0(slave_sel))
            else $error("[axi4lite_address_decoder] slave_sel is not one-hot-zero!");
        assert (valid_addr ^ invalid_addr)
            else $error("[axi4lite_address_decoder] valid/invalid must be complementary!");
    end
`endif

endmodule
