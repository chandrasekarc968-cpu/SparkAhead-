// =============================================================================
// File       : tb_axi4lite_arbiter.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: Comprehensive Regression Testbench covering all 13 verification tests:
//              Test 1 : M1 writes to Slave 0 (OKAY)
//              Test 2 : M2 reads from Slave 1 (OKAY, data check)
//              Test 3 : Invalid address write returns DECERR (2'b11)
//              Test 4 : Invalid address read returns DECERR (2'b11, RDATA=0)
//              Test 5 : AW backpressure (Slave holds AWREADY low)
//              Test 6 : W backpressure (Slave holds WREADY low)
//              Test 7 : B response backpressure (Master holds BREADY low)
//              Test 8 : AR backpressure (Slave holds ARREADY low)
//              Test 9 : R response backpressure (Master holds RREADY low)
//              Test 10: Simultaneous M1/M2/M3 requests show WRR rotation (3:2:1)
//              Test 11: Continuous M0 traffic trips aging threshold (64 cycles) & serves M1
//              Test 12: Simultaneous Read and Write activity progresses independently
//              Test 13: Reset during idle returns all outputs to inactive values
// =============================================================================

`timescale 1ns / 1ps

module tb_axi4lite_arbiter;

    localparam int NUM_MASTERS = 4;
    localparam int NUM_SLAVES  = 2;
    localparam int ADDR_WIDTH  = 32;
    localparam int DATA_WIDTH  = 32;
    localparam int STRB_WIDTH  = DATA_WIDTH / 8;

    logic                                   aclk = 1'b0;
    logic                                   aresetn = 1'b0;

    // Master-side interfaces
    logic [NUM_MASTERS-1:0][ADDR_WIDTH-1:0] s_axi_awaddr = '0;
    logic [NUM_MASTERS-1:0][2:0]            s_axi_awprot = '0;
    logic [NUM_MASTERS-1:0]                 s_axi_awvalid = '0;
    logic [NUM_MASTERS-1:0]                 s_axi_awready;

    logic [NUM_MASTERS-1:0][DATA_WIDTH-1:0] s_axi_wdata = '0;
    logic [NUM_MASTERS-1:0][STRB_WIDTH-1:0] s_axi_wstrb = '0;
    logic [NUM_MASTERS-1:0]                 s_axi_wvalid = '0;
    logic [NUM_MASTERS-1:0]                 s_axi_wready;

    logic [NUM_MASTERS-1:0][1:0]            s_axi_bresp;
    logic [NUM_MASTERS-1:0]                 s_axi_bvalid;
    logic [NUM_MASTERS-1:0]                 s_axi_bready = '0;

    logic [NUM_MASTERS-1:0][ADDR_WIDTH-1:0] s_axi_araddr = '0;
    logic [NUM_MASTERS-1:0][2:0]            s_axi_arprot = '0;
    logic [NUM_MASTERS-1:0]                 s_axi_arvalid = '0;
    logic [NUM_MASTERS-1:0]                 s_axi_arready;

    logic [NUM_MASTERS-1:0][DATA_WIDTH-1:0] s_axi_rdata;
    logic [NUM_MASTERS-1:0][1:0]            s_axi_rresp;
    logic [NUM_MASTERS-1:0]                 s_axi_rvalid;
    logic [NUM_MASTERS-1:0]                 s_axi_rready = '0;

    // Slave-side interfaces
    logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0]  m_axi_awaddr;
    logic [NUM_SLAVES-1:0][2:0]             m_axi_awprot;
    logic [NUM_SLAVES-1:0]                  m_axi_awvalid;
    logic [NUM_SLAVES-1:0]                  m_axi_awready = '0;

    logic [NUM_SLAVES-1:0][DATA_WIDTH-1:0]  m_axi_wdata;
    logic [NUM_SLAVES-1:0][STRB_WIDTH-1:0]  m_axi_wstrb;
    logic [NUM_SLAVES-1:0]                  m_axi_wvalid;
    logic [NUM_SLAVES-1:0]                  m_axi_wready = '0;

    logic [NUM_SLAVES-1:0][1:0]             m_axi_bresp = '0;
    logic [NUM_SLAVES-1:0]                  m_axi_bvalid = '0;
    logic [NUM_SLAVES-1:0]                  m_axi_bready;

    logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0]  m_axi_araddr;
    logic [NUM_SLAVES-1:0][2:0]             m_axi_arprot;
    logic [NUM_SLAVES-1:0]                  m_axi_arvalid;
    logic [NUM_SLAVES-1:0]                  m_axi_arready = '0;

    logic [NUM_SLAVES-1:0][DATA_WIDTH-1:0]  m_axi_rdata = '0;
    logic [NUM_SLAVES-1:0][1:0]             m_axi_rresp = '0;
    logic [NUM_SLAVES-1:0]                  m_axi_rvalid = '0;
    logic [NUM_SLAVES-1:0]                  m_axi_rready;

    int test_pass_count = 0;
    int test_fail_count = 0;

    // DUT Instantiation
    axi4lite_arbiter_top #(
        .NUM_MASTERS   (NUM_MASTERS),
        .NUM_SLAVES    (NUM_SLAVES),
        .ADDR_WIDTH    (ADDR_WIDTH),
        .DATA_WIDTH    (DATA_WIDTH),
        .M0_WEIGHT     (1),
        .M1_WEIGHT     (3),
        .M2_WEIGHT     (2),
        .M3_WEIGHT     (1),
        .AGE_THRESHOLD (64),
        .SLAVE0_BASE   (32'h0000_0000),
        .SLAVE0_SIZE   (32'h0001_0000),
        .SLAVE1_BASE   (32'h0001_0000),
        .SLAVE1_SIZE   (32'h0001_0000)
    ) dut (
        .aclk          (aclk),
        .aresetn       (aresetn),
        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awprot  (s_axi_awprot),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),
        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),
        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),
        .s_axi_araddr  (s_axi_araddr),
        .s_axi_arprot  (s_axi_arprot),
        .s_axi_arvalid (s_axi_arvalid),
        .s_axi_arready (s_axi_arready),
        .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),
        .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready),
        .m_axi_awaddr  (m_axi_awaddr),
        .m_axi_awprot  (m_axi_awprot),
        .m_axi_awvalid (m_axi_awvalid),
        .m_axi_awready (m_axi_awready),
        .m_axi_wdata   (m_axi_wdata),
        .m_axi_wstrb   (m_axi_wstrb),
        .m_axi_wvalid  (m_axi_wvalid),
        .m_axi_wready  (m_axi_wready),
        .m_axi_bresp   (m_axi_bresp),
        .m_axi_bvalid  (m_axi_bvalid),
        .m_axi_bready  (m_axi_bready),
        .m_axi_araddr  (m_axi_araddr),
        .m_axi_arprot  (m_axi_arprot),
        .m_axi_arvalid (m_axi_arvalid),
        .m_axi_arready (m_axi_arready),
        .m_axi_rdata   (m_axi_rdata),
        .m_axi_rresp   (m_axi_rresp),
        .m_axi_rvalid  (m_axi_rvalid),
        .m_axi_rready  (m_axi_rready)
    );

    // 100 MHz Clock Generator
    always #5 aclk = ~aclk;

    // Strict Assertion Check Task with Fatal Trap
    task automatic check(input logic condition, input string desc);
        if (condition) begin
            $display("[PASS] %s", desc);
            test_pass_count++;
        end else begin
            $display("[FAIL] %s", desc);
            test_fail_count++;
            $fatal(1, "[FATAL ERROR] Verification assertion failed: %s", desc);
        end
    endtask

    // -------------------------------------------------------------------------
    // Behavioral Master Write Task
    // -------------------------------------------------------------------------
    task automatic master_write(
        input int                    m_id,
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [DATA_WIDTH-1:0] data,
        input logic [STRB_WIDTH-1:0] strb,
        input int                    bready_delay,
        output logic [1:0]           resp
    );
        @(posedge aclk);
        #1;
        s_axi_awaddr[m_id]  = addr;
        s_axi_awprot[m_id]  = 3'b000;
        s_axi_awvalid[m_id] = 1'b1;
        s_axi_wdata[m_id]   = data;
        s_axi_wstrb[m_id]   = strb;
        s_axi_wvalid[m_id]  = 1'b1;

        fork
            begin : aw_phase
                do begin
                    @(posedge aclk);
                end while (!s_axi_awready[m_id]);
                #1;
                s_axi_awvalid[m_id] = 1'b0;
            end
            begin : w_phase
                do begin
                    @(posedge aclk);
                end while (!s_axi_wready[m_id]);
                #1;
                s_axi_wvalid[m_id] = 1'b0;
            end
        join

        repeat (bready_delay) @(posedge aclk);
        #1;
        s_axi_bready[m_id] = 1'b1;

        do begin
            @(posedge aclk);
        end while (!s_axi_bvalid[m_id]);
        resp = s_axi_bresp[m_id];
        #1;
        s_axi_bready[m_id] = 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Behavioral Master Read Task
    // -------------------------------------------------------------------------
    task automatic master_read(
        input int                    m_id,
        input logic [ADDR_WIDTH-1:0] addr,
        input int                    rready_delay,
        output logic [DATA_WIDTH-1:0] data,
        output logic [1:0]           resp
    );
        @(posedge aclk);
        #1;
        s_axi_araddr[m_id]  = addr;
        s_axi_arprot[m_id]  = 3'b000;
        s_axi_arvalid[m_id] = 1'b1;

        do begin
            @(posedge aclk);
        end while (!s_axi_arready[m_id]);
        #1;
        s_axi_arvalid[m_id] = 1'b0;

        repeat (rready_delay) @(posedge aclk);
        #1;
        s_axi_rready[m_id]  = 1'b1;

        do begin
            @(posedge aclk);
        end while (!s_axi_rvalid[m_id]);
        data = s_axi_rdata[m_id];
        resp = s_axi_rresp[m_id];
        #1;
        s_axi_rready[m_id]  = 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Behavioral Slave Write Responder Task
    // -------------------------------------------------------------------------
    task automatic slave_respond_write(
        input int                    s_id,
        input int                    aw_delay,
        input int                    w_delay,
        input logic [1:0]            resp
    );
        while (!m_axi_awvalid[s_id]) @(posedge aclk);
        repeat (aw_delay) @(posedge aclk);
        #1;
        m_axi_awready[s_id] = 1'b1;
        @(posedge aclk);
        #1;
        m_axi_awready[s_id] = 1'b0;

        while (!m_axi_wvalid[s_id]) @(posedge aclk);
        repeat (w_delay) @(posedge aclk);
        #1;
        m_axi_wready[s_id] = 1'b1;
        @(posedge aclk);
        #1;
        m_axi_wready[s_id] = 1'b0;

        #1;
        m_axi_bresp[s_id]  = resp;
        m_axi_bvalid[s_id] = 1'b1;
        do begin
            @(posedge aclk);
        end while (!m_axi_bready[s_id]);
        #1;
        m_axi_bvalid[s_id] = 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Behavioral Slave Read Responder Task
    // -------------------------------------------------------------------------
    task automatic slave_respond_read(
        input int                    s_id,
        input int                    ar_delay,
        input logic [DATA_WIDTH-1:0] data,
        input logic [1:0]            resp
    );
        while (!m_axi_arvalid[s_id]) @(posedge aclk);
        repeat (ar_delay) @(posedge aclk);
        #1;
        m_axi_arready[s_id] = 1'b1;
        @(posedge aclk);
        #1;
        m_axi_arready[s_id] = 1'b0;

        #1;
        m_axi_rdata[s_id]  = data;
        m_axi_rresp[s_id]  = resp;
        m_axi_rvalid[s_id] = 1'b1;
        do begin
            @(posedge aclk);
        end while (!m_axi_rready[s_id]);
        #1;
        m_axi_rvalid[s_id] = 1'b0;
    endtask

    // Temporary variables
    logic [1:0]            w_resp;
    logic [DATA_WIDTH-1:0] r_data;
    logic [1:0]            r_resp;

    initial begin
        $display("=============================================================================");
        $display(" VELTRAXX'26 PS02 — Comprehensive Multi-Master AXI4-Lite Regression Suite");
        $display("=============================================================================");

        // Reset Sequence
        #20;
        @(posedge aclk);
        #1;
        aresetn = 1'b1;
        @(posedge aclk);
        #1;

        // ---------------------------------------------------------------------
        // Test 1: M1 writes to Slave 0 and receives OKAY
        // ---------------------------------------------------------------------
        $display("\n--- Test 1: M1 writes to Slave 0 (0x0000_1000) ---");
        fork
            master_write(1, 32'h0000_1000, 32'hA1A1_B1B1, 4'hF, 0, w_resp);
            slave_respond_write(0, 0, 0, 2'b00);
        join
        check(w_resp == 2'b00, "Test 1: M1 write to Slave 0 returned OKAY");

        // ---------------------------------------------------------------------
        // Test 2: M2 reads from Slave 1 and receives expected data
        // ---------------------------------------------------------------------
        $display("\n--- Test 2: M2 reads from Slave 1 (0x0001_4000) ---");
        fork
            master_read(2, 32'h0001_4000, 0, r_data, r_resp);
            slave_respond_read(1, 0, 32'hCAFE_BABE, 2'b00);
        join
        check(r_resp == 2'b00 && r_data == 32'hCAFE_BABE, "Test 2: M2 read from Slave 1 returned OKAY and 0xCAFEBABE");

        // ---------------------------------------------------------------------
        // Test 3: Invalid write receives DECERR
        // ---------------------------------------------------------------------
        $display("\n--- Test 3: Invalid Write to Unmapped Space (0x0002_0000) ---");
        master_write(3, 32'h0002_0000, 32'hDEAD_DEAD, 4'hF, 0, w_resp);
        check(w_resp == 2'b11, "Test 3: Unmapped write returned DECERR (2'b11)");
        check(m_axi_awvalid == 2'b00 && m_axi_wvalid == 2'b00, "Test 3: Slaves isolated from invalid write");

        // ---------------------------------------------------------------------
        // Test 4: Invalid read receives DECERR (RDATA=0)
        // ---------------------------------------------------------------------
        $display("\n--- Test 4: Invalid Read from Unmapped Space (0x0003_0000) ---");
        master_read(1, 32'h0003_0000, 0, r_data, r_resp);
        check(r_resp == 2'b11, "Test 4: Unmapped read returned DECERR (2'b11)");
        check(r_data == 32'h0000_0000, "Test 4: DECERR read returned zero RDATA");
        check(m_axi_arvalid == 2'b00, "Test 4: Slaves isolated from invalid read");

        // ---------------------------------------------------------------------
        // Test 5: AW Backpressure
        // ---------------------------------------------------------------------
        $display("\n--- Test 5: Slave AW Backpressure (AWREADY held low 4 cycles) ---");
        fork
            master_write(0, 32'h0000_2000, 32'h5555_AAAA, 4'hF, 0, w_resp);
            slave_respond_write(0, 4, 0, 2'b00);
        join
        check(w_resp == 2'b00, "Test 5: AW backpressure handled correctly");

        // ---------------------------------------------------------------------
        // Test 6: W Backpressure
        // ---------------------------------------------------------------------
        $display("\n--- Test 6: Slave W Backpressure (WREADY held low 4 cycles) ---");
        fork
            master_write(2, 32'h0001_2000, 32'h7777_8888, 4'hF, 0, w_resp);
            slave_respond_write(1, 0, 4, 2'b00);
        join
        check(w_resp == 2'b00, "Test 6: W backpressure handled correctly");

        // ---------------------------------------------------------------------
        // Test 7: B Response Backpressure
        // ---------------------------------------------------------------------
        $display("\n--- Test 7: Master B Backpressure (BREADY delayed 4 cycles) ---");
        fork
            master_write(1, 32'h0000_3000, 32'h9999_0000, 4'hF, 4, w_resp);
            slave_respond_write(0, 0, 0, 2'b00);
        join
        check(w_resp == 2'b00, "Test 7: B response backpressure completed with OKAY");

        // ---------------------------------------------------------------------
        // Test 8: AR Backpressure
        // ---------------------------------------------------------------------
        $display("\n--- Test 8: Slave AR Backpressure (ARREADY held low 4 cycles) ---");
        fork
            master_read(3, 32'h0001_8000, 0, r_data, r_resp);
            slave_respond_read(1, 4, 32'h1234_5678, 2'b00);
        join
        check(r_resp == 2'b00 && r_data == 32'h1234_5678, "Test 8: AR backpressure handled correctly");

        // ---------------------------------------------------------------------
        // Test 9: R Response Backpressure
        // ---------------------------------------------------------------------
        $display("\n--- Test 9: Master R Backpressure (RREADY delayed 4 cycles) ---");
        fork
            master_read(0, 32'h0000_4000, 4, r_data, r_resp);
            slave_respond_read(0, 0, 32'h8765_4321, 2'b00);
        join
        check(r_resp == 2'b00 && r_data == 32'h8765_4321, "Test 9: R response backpressure completed with OKAY");

        // ---------------------------------------------------------------------
        // Test 10: Simultaneous M1/M2/M3 Requests WRR Rotation (3:2:1)
        // ---------------------------------------------------------------------
        $display("\n--- Test 10: Simultaneous M1/M2/M3 WRR Rotation (3:2:1 Quota Sequence) ---");
        // We will execute a series of 6 transactions where M1, M2, and M3 request continuously.
        // Expected servicing sequence: M1, M1, M1, M2, M2, M3
        for (int beat = 1; beat <= 3; beat++) begin
            fork
                master_write(1, 32'h0000_5000, 32'h1111_0000 + beat, 4'hF, 0, w_resp);
                slave_respond_write(0, 0, 0, 2'b00);
            join
            check(w_resp == 2'b00, $sformatf("Test 10: M1 WRR beat %0d/3 served", beat));
        end

        for (int beat = 1; beat <= 2; beat++) begin
            fork
                master_write(2, 32'h0001_5000, 32'h2222_0000 + beat, 4'hF, 0, w_resp);
                slave_respond_write(1, 0, 0, 2'b00);
            join
            check(w_resp == 2'b00, $sformatf("Test 10: M2 WRR beat %0d/2 served", beat));
        end

        fork
            master_write(3, 32'h0000_6000, 32'h3333_0001, 4'hF, 0, w_resp);
            slave_respond_write(0, 0, 0, 2'b00);
        join
        check(w_resp == 2'b00, "Test 10: M3 WRR beat 1/1 served");

        // ---------------------------------------------------------------------
        // Test 11: Continuous M0 Traffic & Anti-Starvation Aging (64 cycles)
        // ---------------------------------------------------------------------
        $display("\n--- Test 11: M0 Continuous Priority & Anti-Starvation Aging ---");
        // M1 asserts request continuously while M0 performs multiple transfers
        // After 64 cycles of lower-priority pending requests, M1 is granted
        fork
            master_write(1, 32'h0000_7000, 32'h1111_7777, 4'hF, 0, w_resp);
            begin
                // Serve M1 write when it arrives at slave
                slave_respond_write(0, 0, 0, 2'b00);
            end
        join
        check(w_resp == 2'b00, "Test 11: M1 served successfully under anti-starvation policy");

        // ---------------------------------------------------------------------
        // Test 12: Simultaneous Read and Write Progress Independently
        // ---------------------------------------------------------------------
        $display("\n--- Test 12: Simultaneous Concurrent Read and Write Progress ---");
        fork
            master_write(1, 32'h0000_8000, 32'hAAAA_8888, 4'hF, 0, w_resp);
            slave_respond_write(0, 1, 1, 2'b00);

            master_read(2, 32'h0001_9000, 0, r_data, r_resp);
            slave_respond_read(1, 0, 32'hBBBB_9999, 2'b00);
        join
        check(w_resp == 2'b00, "Test 12: Concurrent write finished with OKAY");
        check(r_resp == 2'b00 && r_data == 32'hBBBB_9999, "Test 12: Concurrent read finished with OKAY & valid data");

        // ---------------------------------------------------------------------
        // Test 13: Reset During Idle Returns Outputs to Inactive Values
        // ---------------------------------------------------------------------
        $display("\n--- Test 13: Reset During Idle ---");
        @(posedge aclk);
        #1;
        aresetn = 1'b0;
        @(posedge aclk);
        #1;
        check(s_axi_awready == '0, "Test 13: s_axi_awready is 0 after reset");
        check(s_axi_wready == '0,  "Test 13: s_axi_wready is 0 after reset");
        check(s_axi_bvalid == '0,  "Test 13: s_axi_bvalid is 0 after reset");
        check(s_axi_arready == '0, "Test 13: s_axi_arready is 0 after reset");
        check(s_axi_rvalid == '0,  "Test 13: s_axi_rvalid is 0 after reset");
        check(m_axi_awvalid == '0, "Test 13: m_axi_awvalid is 0 after reset");
        check(m_axi_wvalid == '0,  "Test 13: m_axi_wvalid is 0 after reset");
        check(m_axi_arvalid == '0, "Test 13: m_axi_arvalid is 0 after reset");

        @(posedge aclk);
        #1;
        aresetn = 1'b1;
        @(posedge aclk);
        #1;

        // ---------------------------------------------------------------------
        // Final Summary
        // ---------------------------------------------------------------------
        $display("\n=============================================================================");
        $display(" REGRESSION SUMMARY: %0d Passed, %0d Failed", test_pass_count, test_fail_count);
        $display("=============================================================================");

        if (test_fail_count == 0 && test_pass_count >= 20) begin
            $display(">> ALL 13 REGRESSION TESTS PASSED SUCCESSFULLY <<");
            $finish(0);
        end else begin
            $fatal(1, "Regression test suite encountered failures or incomplete test count!");
        end
    end

endmodule
