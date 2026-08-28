// =============================================================================
// File       : tb_axi4lite_read_path.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: Directed testbench for the read datapath & FSM in axi4lite_arbiter_top:
//              1. Single-master read from Slave 0 (OKAY)
//              2. Single-master read from Slave 1 (OKAY)
//              3. Invalid-address read to unmapped space (DECERR, RDATA=0, no slave valid)
//              4. Downstream slave backpressure on ARREADY
//              5. Upstream master backpressure on RREADY
//              6. Sequential multi-master reads
// =============================================================================

`timescale 1ns / 1ps

module tb_axi4lite_read_path;

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

    int pass_count = 0;
    int fail_count = 0;

    // DUT Instantiation
    axi4lite_arbiter_top #(
        .NUM_MASTERS   (NUM_MASTERS),
        .NUM_SLAVES    (NUM_SLAVES),
        .ADDR_WIDTH    (ADDR_WIDTH),
        .DATA_WIDTH    (DATA_WIDTH),
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

    // Clock generator (100 MHz)
    always #5 aclk = ~aclk;

    task automatic check(input logic condition, input string desc);
        if (condition) begin
            $display("[PASS] %s", desc);
            pass_count++;
        end else begin
            $display("[FAIL] %s", desc);
            fail_count++;
        end
    endtask

    // Master Read Driver Task
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

        // Wait for ARREADY
        do begin
            @(posedge aclk);
        end while (!s_axi_arready[m_id]);
        #1;
        s_axi_arvalid[m_id] = 1'b0;

        // Apply optional master backpressure delay before asserting RREADY
        repeat (rready_delay) @(posedge aclk);
        #1;
        s_axi_rready[m_id]  = 1'b1;

        // Wait for RVALID
        do begin
            @(posedge aclk);
        end while (!s_axi_rvalid[m_id]);
        data = s_axi_rdata[m_id];
        resp = s_axi_rresp[m_id];
        #1;
        s_axi_rready[m_id]  = 1'b0;
    endtask

    // Simple Behavioral Read Slave Model
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

    logic [DATA_WIDTH-1:0] r_data;
    logic [1:0]            r_resp;

    initial begin
        $display("=============================================================================");
        $display(" Starting testbench: tb_axi4lite_read_path");
        $display("=============================================================================");

        // Reset Sequence
        #20;
        @(posedge aclk);
        #1;
        aresetn = 1'b1;
        @(posedge aclk);
        #1;

        // ---------------------------------------------------------------------
        // Test 1: Single Master Read from Slave 0 (OKAY)
        // ---------------------------------------------------------------------
        $display("\n--- Test 1: Master 0 Read from Slave 0 (0x0000_2000) ---");
        fork
            master_read(0, 32'h0000_2000, 0, r_data, r_resp);
            slave_respond_read(0, 0, 32'h1122_3344, 2'b00);
        join
        check(r_resp == 2'b00, "Master 0 received OKAY response from Slave 0");
        check(r_data == 32'h1122_3344, "Master 0 received correct data (0x11223344)");

        // ---------------------------------------------------------------------
        // Test 2: Single Master Read from Slave 1 (OKAY)
        // ---------------------------------------------------------------------
        $display("\n--- Test 2: Master 1 Read from Slave 1 (0x0001_8000) ---");
        fork
            master_read(1, 32'h0001_8000, 0, r_data, r_resp);
            slave_respond_read(1, 0, 32'h5566_7788, 2'b00);
        join
        check(r_resp == 2'b00, "Master 1 received OKAY response from Slave 1");
        check(r_data == 32'h5566_7788, "Master 1 received correct data (0x55667788)");

        // ---------------------------------------------------------------------
        // Test 3: Invalid Address Read to Unmapped Space (DECERR, RDATA=0)
        // ---------------------------------------------------------------------
        $display("\n--- Test 3: Master 2 Read from Unmapped Space (0x0003_0000) ---");
        master_read(2, 32'h0003_0000, 0, r_data, r_resp);
        check(r_resp == 2'b11, "Master 2 received DECERR response for unmapped read");
        check(r_data == 32'h0000_0000, "Master 2 received RDATA=0 on DECERR");
        check(m_axi_arvalid == 2'b00, "Slaves received no ARVALID for invalid access");

        // ---------------------------------------------------------------------
        // Test 4: Downstream Slave Backpressure on ARREADY
        // ---------------------------------------------------------------------
        $display("\n--- Test 4: Slave Backpressure on ARREADY (3 cycles delay) ---");
        fork
            master_read(3, 32'h0001_4000, 0, r_data, r_resp);
            slave_respond_read(1, 3, 32'h99AA_BBCC, 2'b00);
        join
        check(r_resp == 2'b00, "Master 3 completed read under slave backpressure");
        check(r_data == 32'h99AA_BBCC, "Master 3 received correct data after AR backpressure");

        // ---------------------------------------------------------------------
        // Test 5: Upstream Master Backpressure on RREADY
        // ---------------------------------------------------------------------
        $display("\n--- Test 5: Master Backpressure on RREADY (3 cycles delay) ---");
        fork
            master_read(0, 32'h0000_1000, 3, r_data, r_resp);
            slave_respond_read(0, 0, 32'hFEED_FACE, 2'b00);
        join
        check(r_resp == 2'b00, "Master 0 completed read under master backpressure");
        check(r_data == 32'hFEED_FACE, "Master 0 received correct data after R backpressure");

        // ---------------------------------------------------------------------
        // Test 6: Sequential Multi-Master Reads (M1 then M2)
        // ---------------------------------------------------------------------
        $display("\n--- Test 6: Sequential Multi-Master Reads ---");
        fork
            master_read(1, 32'h0000_0004, 0, r_data, r_resp);
            slave_respond_read(0, 0, 32'hAAAA_1111, 2'b00);
        join
        check(r_resp == 2'b00 && r_data == 32'hAAAA_1111, "M1 sequential read completed");

        fork
            master_read(2, 32'h0001_0004, 0, r_data, r_resp);
            slave_respond_read(1, 0, 32'hBBBB_2222, 2'b00);
        join
        check(r_resp == 2'b00 && r_data == 32'hBBBB_2222, "M2 sequential read completed");

        // ---------------------------------------------------------------------
        // Summary
        // ---------------------------------------------------------------------
        @(posedge aclk);
        #1;
        $display("\n=============================================================================");
        $display(" Verification Summary: %0d Passed, %0d Failed", pass_count, fail_count);
        $display("=============================================================================");

        if (fail_count == 0) begin
            $display(">> TEST RESULT: ALL READ PATH ASSERTIONS PASSED <<");
            $finish(0);
        end else begin
            $display(">> TEST RESULT: FAILURES DETECTED <<");
            $fatal(1, "Read path verification failed!");
        end
    end

endmodule
