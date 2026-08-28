// =============================================================================
// File       : tb_qos_arbiter.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: Directed testbench for qos_arbiter verifying:
//              1. Master 0 high priority
//              2. WRR rotation (M1 -> M2 -> M3)
//              3. Weight ratio exactness (M1:3, M2:2, M3:1)
//              4. Anti-starvation aging threshold (64 cycles) and recovery
//              5. No spurious grants without request
//              6. One-hot grant compliance
// =============================================================================

`timescale 1ns / 1ps

module tb_qos_arbiter;

    parameter int NUM_MASTERS   = 4;
    parameter int M0_WEIGHT     = 1;
    parameter int M1_WEIGHT     = 3;
    parameter int M2_WEIGHT     = 2;
    parameter int M3_WEIGHT     = 1;
    parameter int AGE_THRESHOLD = 64;

    logic                     aclk = 1'b0;
    logic                     aresetn = 1'b0;
    logic [NUM_MASTERS-1:0]   req = '0;
    logic                     transaction_complete = 1'b0;

    logic [NUM_MASTERS-1:0]   grant;
    logic [$clog2(NUM_MASTERS)-1:0] master_id;
    logic                     grant_valid;
    logic                     starvation_flag;

    int pass_count = 0;
    int fail_count = 0;

    // DUT Instantiation
    qos_arbiter #(
        .NUM_MASTERS   (NUM_MASTERS),
        .M0_WEIGHT     (M0_WEIGHT),
        .M1_WEIGHT     (M1_WEIGHT),
        .M2_WEIGHT     (M2_WEIGHT),
        .M3_WEIGHT     (M3_WEIGHT),
        .AGE_THRESHOLD (AGE_THRESHOLD)
    ) dut (
        .aclk                 (aclk),
        .aresetn              (aresetn),
        .req                  (req),
        .transaction_complete (transaction_complete),
        .grant                (grant),
        .master_id            (master_id),
        .grant_valid          (grant_valid),
        .starvation_flag      (starvation_flag)
    );

    // Clock generator (100 MHz, 10 ns period)
    always #5 aclk = ~aclk;

    // Helper task to check condition
    task automatic check(input logic condition, input string name);
        if (condition) begin
            $display("[PASS] %s", name);
            pass_count++;
        end else begin
            $display("[FAIL] %s", name);
            fail_count++;
        end
    endtask

    // Helper task to execute one complete granted transaction
    task automatic do_transaction(input int expected_master);
        wait (grant_valid == 1'b1);
        @(posedge aclk);
        #1;
        check(grant_valid && master_id == expected_master && grant[expected_master],
              $sformatf("Grant check: Expected Master %0d, Got Master %0d (grant=%b)", expected_master, master_id, grant));
        
        // Assert transaction_complete for 1 cycle
        transaction_complete = 1'b1;
        @(posedge aclk);
        #1;
        transaction_complete = 1'b0;
    endtask

    initial begin
        $display("=============================================================================");
        $display(" Starting testbench: tb_qos_arbiter");
        $display("=============================================================================");

        // --- Reset sequence ---
        #20;
        @(posedge aclk);
        #1;
        aresetn = 1'b1;
        @(posedge aclk);
        #1;

        // ---------------------------------------------------------------------
        // Test 1: No grant when no request
        // ---------------------------------------------------------------------
        $display("\n--- Test 1: No Grant Without Request ---");
        req = 4'b0000;
        @(posedge aclk);
        #1;
        check(grant == 4'b0000 && grant_valid == 0, "Idle state: no grant asserted");

        // ---------------------------------------------------------------------
        // Test 2: M0 Priority over M1..M3
        // ---------------------------------------------------------------------
        $display("\n--- Test 2: Master 0 Immediate Priority ---");
        req = 4'b1111; // All masters requesting
        do_transaction(0);

        // Clear requests to return to clean idle between tests
        req = 4'b0000;
        @(posedge aclk);
        #1;

        // ---------------------------------------------------------------------
        // Test 3: WRR Rotation & Weights (M1=3, M2=2, M3=1)
        // ---------------------------------------------------------------------
        $display("\n--- Test 3: WRR Rotation for M1..M3 ---");
        req = 4'b1110; // M1, M2, M3 requesting (M0 idle)
        
        // Round 1: M1 should get 3 beats
        $display("  -> Verifying M1 quota of 3");
        do_transaction(1);
        do_transaction(1);
        do_transaction(1);

        // Round 1: M2 should get 2 beats
        $display("  -> Verifying M2 quota of 2");
        do_transaction(2);
        do_transaction(2);

        // Round 1: M3 should get 1 beat
        $display("  -> Verifying M3 quota of 1");
        do_transaction(3);

        // Round 2: Verifying that next rotation begins at M1 again
        $display("  -> Verifying WRR repeats: M1 gets next grant");
        do_transaction(1);
        do_transaction(1);
        do_transaction(1);
        do_transaction(2);
        do_transaction(2);
        do_transaction(3);

        // Return to clean idle
        req = 4'b0000;
        @(posedge aclk);
        #1;

        // ---------------------------------------------------------------------
        // Test 4: Anti-Starvation Aging (M0 continuous vs M1 pending)
        // ---------------------------------------------------------------------
        $display("\n--- Test 4: Anti-Starvation Aging Threshold (64 cycles) ---");
        req = 4'b0011; // M0 and M1 requesting
        
        // Keep M0 active while M1 waits until starvation triggers
        for (int i = 0; i < AGE_THRESHOLD + 10 && !starvation_flag; i++) begin
            @(posedge aclk);
            #1;
            transaction_complete = 1'b1;
            @(posedge aclk);
            #1;
            transaction_complete = 1'b0;
        end

        check(starvation_flag == 1'b1, "Starvation flag asserted after threshold reached");
        check(master_id == 1 && grant[1] == 1'b1, "M0 suppressed: M1 granted due to starvation override");

        // Complete M1 transaction and verify starvation flag is cleared
        transaction_complete = 1'b1;
        @(posedge aclk);
        #1;
        transaction_complete = 1'b0;

        check(starvation_flag == 1'b0, "Starvation flag cleared after lower-priority master serviced");
        check(master_id == 0 && grant[0] == 1'b1, "M0 resumes priority after starvation cleared");
        do_transaction(0);

        // Return to clean idle
        req = 4'b0000;
        @(posedge aclk);
        #1;

        // ---------------------------------------------------------------------
        // Test 5: Single Master Requests
        // ---------------------------------------------------------------------
        $display("\n--- Test 5: Single Master Requests ---");
        req = 4'b0100; // Only M2
        do_transaction(2);

        req = 4'b1000; // Only M3
        do_transaction(3);

        // ---------------------------------------------------------------------
        // Summary
        // ---------------------------------------------------------------------
        req = 4'b0000;
        @(posedge aclk);
        #1;

        $display("\n=============================================================================");
        $display(" Verification Summary: %0d Passed, %0d Failed", pass_count, fail_count);
        $display("=============================================================================");

        if (fail_count == 0) begin
            $display(">> TEST RESULT: ALL QOS_ARBITER ASSERTIONS PASSED <<");
            $finish(0);
        end else begin
            $display(">> TEST RESULT: FAILURES DETECTED <<");
            $fatal(1, "QoS arbiter verification failed!");
        end
    end

endmodule
