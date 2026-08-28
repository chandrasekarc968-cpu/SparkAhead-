// =============================================================================
// File       : addr_decoder.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: Hardcoded combinational address decoder for 2 AXI4-Lite slaves
//              with internal DECERR (unmapped address) detection.
// =============================================================================

`timescale 1ns / 1ps

module addr_decoder #(
    parameter int ADDR_WIDTH  = 32,
    parameter logic [ADDR_WIDTH-1:0] SLAVE0_BASE = 32'h0000_0000,
    parameter logic [ADDR_WIDTH-1:0] SLAVE0_SIZE = 32'h0001_0000,
    parameter logic [ADDR_WIDTH-1:0] SLAVE1_BASE = 32'h0001_0000,
    parameter logic [ADDR_WIDTH-1:0] SLAVE1_SIZE = 32'h0001_0000
) (
    // Address input (from master request)
    input  logic [ADDR_WIDTH-1:0] addr,

    // Decode outputs
    output logic [1:0]            slave_sel,    // One-hot slave select: bit 0 -> Slave 0, bit 1 -> Slave 1
    output logic                  valid_addr,   // 1 if address maps to a valid slave
    output logic                  invalid_addr  // 1 if address is unmapped (triggers DECERR)
);

    // Unsigned range bounds calculation using 64-bit arithmetic to prevent 32-bit wrap-around
    logic match_s0;
    logic match_s1;

    /* verilator lint_off UNSIGNED */
    always_comb begin
        // Check Slave 0 region: [SLAVE0_BASE, SLAVE0_BASE + SLAVE0_SIZE - 1]
        if (SLAVE0_SIZE > 0 &&
            (64'(addr) >= 64'(SLAVE0_BASE)) &&
            (64'(addr) <  (64'(SLAVE0_BASE) + 64'(SLAVE0_SIZE)))) begin
            match_s0 = 1'b1;
        end else begin
            match_s0 = 1'b0;
        end

        // Check Slave 1 region: [SLAVE1_BASE, SLAVE1_BASE + SLAVE1_SIZE - 1]
        if (SLAVE1_SIZE > 0 &&
            (64'(addr) >= 64'(SLAVE1_BASE)) &&
            (64'(addr) <  (64'(SLAVE1_BASE) + 64'(SLAVE1_SIZE)))) begin
            match_s1 = 1'b1;
        end else begin
            match_s1 = 1'b0;
        end

        // Overlapping priority: Slave 0 has priority if regions overlap
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

`ifdef ASSERTIONS
        assert ($onehot0(slave_sel))
            else $error("[addr_decoder] Mutual exclusion violated on slave_sel!");
        assert (valid_addr ^ invalid_addr)
            else $error("[addr_decoder] valid_addr and invalid_addr must be complementary!");
`endif
    end
    /* verilator lint_on UNSIGNED */

endmodule
