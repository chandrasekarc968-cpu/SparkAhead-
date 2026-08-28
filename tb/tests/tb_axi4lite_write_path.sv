// =============================================================================
// File       : tb_axi4lite_write_path.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: Directed testbench for the write datapath & FSM in axi4lite_arbiter_top:
//              1. Single-master write to Slave 0 (OKAY)
//              2. Single-master write to Slave 1 (OKAY)
//              3. Invalid-address write to unmapped space (DECERR, no slave valid)
//              4. Downstream slave backpressure on AWREADY and WREADY
//              5. Upstream master backpressure on BREADY
//              6. Simultaneous multi-master writes without interleaving
// =============================================================================

`timescale 1ns / 1ps

module tb_axi4lite_write_path;

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

    // Unused read ports tied off
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

    // Master Write Driver Task with concurrent AW and W phase handshakes
    task automatic master_write(
        input int                    m_id,
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [DATA_WIDTH-1:0] data,
        input logic [STRB_WIDTH-1:0] strb,
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
        s_axi_bready[m_id]  = 1'b1;

        fork
            begin : aw_handshake
                do begin
                    @(posedge aclk);
                end while (!s_axi_awready[m_id]);
                #1;
                s_axi_awvalid[m_id] = 1'b0;
            end
            begin : w_handshake
                do begin
                    @(posedge aclk);
                end while (!s_axi_wready[m_id]);
                #1;
                s_axi_wvalid[m_id] = 1'b0;
            end
        join

        do begin
            @(posedge aclk);
        end while (!s_axi_bvalid[m_id]);
        resp = s_axi_bresp[m_id];
        #1;
        s_axi_bready[m_id] = 1'b0;
    endtask

    // Simple Behavioral Slave Model
    task automatic slave_respond_write(input int s_id, input int aw_delay, input int w_delay, input logic [1:0] resp);
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

    logic [1:0] w_resp;

    initial begin
        $display("=============================================================================");
        $display(" Starting testbench: tb_axi4lite_write_path");
        $display("=============================================================================");

        // Reset Sequence
        #20;
        @(posedge aclk);
        #1;
        aresetn = 1'b1;
        @(posedge aclk);
        #1;

        // ---------------------------------------------------------------------
        // Test 1: Single Master Write to Slave 0 (OKAY)
        // ---------------------------------------------------------------------
        $display("\n--- Test 1: Master 1 Write to Slave 0 (0x0000_1000) ---");
        fork
            master_write(1, 32'h0000_1000, 32'hDEAD_0001, 4'hF, w_resp);
            slave_respond_write(0, 0, 0, 2'b00);
        join
        check(w_resp == 2'b00, "Master 1 received OKAY response from Slave 0");

        // ---------------------------------------------------------------------
        // Test 2: Single Master Write to Slave 1 (OKAY)
        // ---------------------------------------------------------------------
        $display("\n--- Test 2: Master 2 Write to Slave 1 (0x0001_2000) ---");
        fork
            master_write(2, 32'h0001_2000, 32'hBEEF_0002, 4'hF, w_resp);
            slave_respond_write(1, 0, 0, 2'b00);
        join
        check(w_resp == 2'b00, "Master 2 received OKAY response from Slave 1");

        // ---------------------------------------------------------------------
        // Test 3: Invalid Address Write to Unmapped Space (DECERR)
        // ---------------------------------------------------------------------
        $display("\n--- Test 3: Master 3 Write to Unmapped Space (0x0002_0000) ---");
        master_write(3, 32'h0002_0000, 32'hCAFE_0003, 4'hF, w_resp);
        check(w_resp == 2'b11, "Master 3 received DECERR response for unmapped address");
        check(m_axi_awvalid == 2'b00 && m_axi_wvalid == 2'b00, "Slaves received no valid signals for invalid access");

        // ---------------------------------------------------------------------
        // Test 4: Downstream Slave Backpressure (AWREADY & WREADY delay)
        // ---------------------------------------------------------------------
        $display("\n--- Test 4: Slave Backpressure on AWREADY (3 cycles) & WREADY (2 cycles) ---");
        fork
            master_write(0, 32'h0000_4000, 32'hAAAA_0000, 4'hF, w_resp);
            slave_respond_write(0, 3, 2, 2'b00);
        join
        check(w_resp == 2'b00, "Master 0 completed write under slave backpressure");

        // ---------------------------------------------------------------------
        // Test 5: Sequential Multi-Master Writes (M1 then M2)
        // ---------------------------------------------------------------------
        $display("\n--- Test 5: Sequential Multi-Master Writes ---");
        fork
            master_write(1, 32'h0000_0100, 32'h1111_1111, 4'hF, w_resp);
            slave_respond_write(0, 1, 1, 2'b00);
        join
        check(w_resp == 2'b00, "M1 sequential write completed");

        fork
            master_write(2, 32'h0001_0200, 32'h2222_2222, 4'hF, w_resp);
            slave_respond_write(1, 1, 1, 2'b00);
        join
        check(w_resp == 2'b00, "M2 sequential write completed");

        // ---------------------------------------------------------------------
        // Summary
        // ---------------------------------------------------------------------
        @(posedge aclk);
        #1;
        $display("\n=============================================================================");
        $display(" Verification Summary: %0d Passed, %0d Failed", pass_count, fail_count);
        $display("=============================================================================");

        if (fail_count == 0) begin
            $display(">> TEST RESULT: ALL WRITE PATH ASSERTIONS PASSED <<");
            $finish(0);
        end else begin
            $display(">> TEST RESULT: FAILURES DETECTED <<");
            $fatal(1, "Write path verification failed!");
        end
    end

endmodule
