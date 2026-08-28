// =============================================================================
// File       : tb_addr_decoder.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: Directed testbench for addr_decoder covering base addresses,
//              interior points, boundary limits, and unmapped spaces.
// =============================================================================

`timescale 1ns / 1ps

module tb_addr_decoder;

    parameter int ADDR_WIDTH  = 32;
    parameter logic [ADDR_WIDTH-1:0] SLAVE0_BASE = 32'h0000_0000;
    parameter logic [ADDR_WIDTH-1:0] SLAVE0_SIZE = 32'h0001_0000;
    parameter logic [ADDR_WIDTH-1:0] SLAVE1_BASE = 32'h0001_0000;
    parameter logic [ADDR_WIDTH-1:0] SLAVE1_SIZE = 32'h0001_0000;

    // DUT Signals
    logic [ADDR_WIDTH-1:0] addr;
    logic [1:0]            slave_sel;
    logic                  valid_addr;
    logic                  invalid_addr;

    // Verification statistics
    int pass_count = 0;
    int fail_count = 0;

    // Instantiate DUT
    addr_decoder #(
        .ADDR_WIDTH  (ADDR_WIDTH),
        .SLAVE0_BASE (SLAVE0_BASE),
        .SLAVE0_SIZE (SLAVE0_SIZE),
        .SLAVE1_BASE (SLAVE1_BASE),
        .SLAVE1_SIZE (SLAVE1_SIZE)
    ) dut (
        .addr         (addr),
        .slave_sel    (slave_sel),
        .valid_addr   (valid_addr),
        .invalid_addr (invalid_addr)
    );

    // Verification Task
    task automatic check_addr(
        input logic [ADDR_WIDTH-1:0] test_addr,
        input logic [1:0]            exp_sel,
        input logic                  exp_valid,
        input logic                  exp_invalid,
        input string                 desc
    );
        addr = test_addr;
        #1; // Allow combinational logic to settle

        if (slave_sel === exp_sel && valid_addr === exp_valid && invalid_addr === exp_invalid) begin
            $display("[PASS] %-30s | Addr: 0x%08h | Sel: %b | Valid: %b | Invalid: %b",
                     desc, test_addr, slave_sel, valid_addr, invalid_addr);
            pass_count++;
        end else begin
            $display("[FAIL] %-30s | Addr: 0x%08h | Expected: Sel=%b, Val=%b, Inval=%b | Got: Sel=%b, Val=%b, Inval=%b",
                     desc, test_addr, exp_sel, exp_valid, exp_invalid, slave_sel, valid_addr, invalid_addr);
            fail_count++;
        end
    endtask

    initial begin
        $display("=============================================================================");
        $display(" Starting testbench: tb_addr_decoder");
        $display("=============================================================================");

        // --- Slave 0 Region Tests [0x0000_0000 .. 0x0000_FFFF] ---
        check_addr(32'h0000_0000, 2'b01, 1'b1, 1'b0, "Slave 0 Base (Min)");
        check_addr(32'h0000_0004, 2'b01, 1'b1, 1'b0, "Slave 0 Word 1");
        check_addr(32'h0000_8000, 2'b01, 1'b1, 1'b0, "Slave 0 Mid-point");
        check_addr(32'h0000_FFFC, 2'b01, 1'b1, 1'b0, "Slave 0 Last Word");
        check_addr(32'h0000_FFFF, 2'b01, 1'b1, 1'b0, "Slave 0 Boundary (Max)");

        // --- Slave 1 Region Tests [0x0001_0000 .. 0x0001_FFFF] ---
        check_addr(32'h0001_0000, 2'b10, 1'b1, 1'b0, "Slave 1 Base (Min)");
        check_addr(32'h0001_0004, 2'b10, 1'b1, 1'b0, "Slave 1 Word 1");
        check_addr(32'h0001_4000, 2'b10, 1'b1, 1'b0, "Slave 1 Mid-point");
        check_addr(32'h0001_FFFC, 2'b10, 1'b1, 1'b0, "Slave 1 Last Word");
        check_addr(32'h0001_FFFF, 2'b10, 1'b1, 1'b0, "Slave 1 Boundary (Max)");

        // --- Unmapped / DECERR Region Tests ---
        check_addr(32'h0002_0000, 2'b00, 1'b0, 1'b1, "Unmapped (Just above S1)");
        check_addr(32'h0002_0004, 2'b00, 1'b0, 1'b1, "Unmapped 0x0002_0004");
        check_addr(32'h1000_0000, 2'b00, 1'b0, 1'b1, "Unmapped High RAM");
        check_addr(32'h8000_0000, 2'b00, 1'b0, 1'b1, "Unmapped MSB=1");
        check_addr(32'hDEAD_BEEF, 2'b00, 1'b0, 1'b1, "Unmapped Pattern");
        check_addr(32'hFFFF_FFFF, 2'b00, 1'b0, 1'b1, "Unmapped Max Address");

        $display("=============================================================================");
        $display(" Verification Summary: %0d Passed, %0d Failed", pass_count, fail_count);
        $display("=============================================================================");

        if (fail_count == 0) begin
            $display(">> TEST RESULT: ALL ADDR_DECODER ASSERTIONS PASSED <<");
            $finish(0);
        end else begin
            $display(">> TEST RESULT: FAILURES DETECTED <<");
            $fatal(1, "Address decoder verification failed!");
        end
    end

endmodule
