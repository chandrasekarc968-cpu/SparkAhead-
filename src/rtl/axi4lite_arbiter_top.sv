// =============================================================================
// File       : axi4lite_arbiter_top.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: Synthesizable 4-Master, 2-Slave AXI4-Lite Shared-Bus Interconnect
//              Top-level module featuring:
//              - Two independent QoS Arbiter instances (Write Path & Read Path)
//              - Concurrent, decoupled Read and Write arbitration and datapaths
//              - Hardcoded combinational Address Decoders with DECERR support
//              - Single outstanding transaction per channel without interleaving
//              - Strict AXI4-Lite handshake & signal stability compliance
// =============================================================================

`timescale 1ns / 1ps

module axi4lite_arbiter_top #(
    parameter int NUM_MASTERS   = 4,
    parameter int NUM_SLAVES    = 2,
    parameter int ADDR_WIDTH    = 32,
    parameter int DATA_WIDTH    = 32,
    parameter int STRB_WIDTH    = DATA_WIDTH / 8,

    // QoS Arbitration Weights & Starvation Threshold
    parameter int M0_WEIGHT     = 1,
    parameter int M1_WEIGHT     = 3,
    parameter int M2_WEIGHT     = 2,
    parameter int M3_WEIGHT     = 1,
    parameter int AGE_THRESHOLD = 64,

    // Slave Address Regions
    parameter logic [ADDR_WIDTH-1:0] SLAVE0_BASE = 32'h0000_0000,
    parameter logic [ADDR_WIDTH-1:0] SLAVE0_SIZE = 32'h0001_0000,
    parameter logic [ADDR_WIDTH-1:0] SLAVE1_BASE = 32'h0001_0000,
    parameter logic [ADDR_WIDTH-1:0] SLAVE1_SIZE = 32'h0001_0000
) (
    input  logic                                            aclk,
    input  logic                                            aresetn,

    // -------------------------------------------------------------------------
    // Upstream AXI4-Lite Master Interfaces (s_axi_*)
    // -------------------------------------------------------------------------
    // Write Address Channel
    input  logic [NUM_MASTERS-1:0][ADDR_WIDTH-1:0]          s_axi_awaddr,
    input  logic [NUM_MASTERS-1:0][2:0]                     s_axi_awprot,
    input  logic [NUM_MASTERS-1:0]                          s_axi_awvalid,
    output logic [NUM_MASTERS-1:0]                          s_axi_awready,

    // Write Data Channel
    input  logic [NUM_MASTERS-1:0][DATA_WIDTH-1:0]          s_axi_wdata,
    input  logic [NUM_MASTERS-1:0][STRB_WIDTH-1:0]          s_axi_wstrb,
    input  logic [NUM_MASTERS-1:0]                          s_axi_wvalid,
    output logic [NUM_MASTERS-1:0]                          s_axi_wready,

    // Write Response Channel
    output logic [NUM_MASTERS-1:0][1:0]                     s_axi_bresp,
    output logic [NUM_MASTERS-1:0]                          s_axi_bvalid,
    input  logic [NUM_MASTERS-1:0]                          s_axi_bready,

    // Read Address Channel
    input  logic [NUM_MASTERS-1:0][ADDR_WIDTH-1:0]          s_axi_araddr,
    input  logic [NUM_MASTERS-1:0][2:0]                     s_axi_arprot,
    input  logic [NUM_MASTERS-1:0]                          s_axi_arvalid,
    output logic [NUM_MASTERS-1:0]                          s_axi_arready,

    // Read Data / Response Channel
    output logic [NUM_MASTERS-1:0][DATA_WIDTH-1:0]          s_axi_rdata,
    output logic [NUM_MASTERS-1:0][1:0]                     s_axi_rresp,
    output logic [NUM_MASTERS-1:0]                          s_axi_rvalid,
    input  logic [NUM_MASTERS-1:0]                          s_axi_rready,

    // -------------------------------------------------------------------------
    // Downstream AXI4-Lite Slave Interfaces (m_axi_*)
    // -------------------------------------------------------------------------
    // Write Address Channel
    output logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0]           m_axi_awaddr,
    output logic [NUM_SLAVES-1:0][2:0]                      m_axi_awprot,
    output logic [NUM_SLAVES-1:0]                           m_axi_awvalid,
    input  logic [NUM_SLAVES-1:0]                           m_axi_awready,

    // Write Data Channel
    output logic [NUM_SLAVES-1:0][DATA_WIDTH-1:0]           m_axi_wdata,
    output logic [NUM_SLAVES-1:0][STRB_WIDTH-1:0]           m_axi_wstrb,
    output logic [NUM_SLAVES-1:0]                           m_axi_wvalid,
    input  logic [NUM_SLAVES-1:0]                           m_axi_wready,

    // Write Response Channel
    input  logic [NUM_SLAVES-1:0][1:0]                      m_axi_bresp,
    input  logic [NUM_SLAVES-1:0]                           m_axi_bvalid,
    output logic [NUM_SLAVES-1:0]                           m_axi_bready,

    // Read Address Channel
    output logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0]           m_axi_araddr,
    output logic [NUM_SLAVES-1:0][2:0]                      m_axi_arprot,
    output logic [NUM_SLAVES-1:0]                           m_axi_arvalid,
    input  logic [NUM_SLAVES-1:0]                           m_axi_arready,

    // Read Data / Response Channel
    input  logic [NUM_SLAVES-1:0][DATA_WIDTH-1:0]           m_axi_rdata,
    input  logic [NUM_SLAVES-1:0][1:0]                      m_axi_rresp,
    input  logic [NUM_SLAVES-1:0]                           m_axi_rvalid,
    output logic [NUM_SLAVES-1:0]                           m_axi_rready
);

    localparam int M_ID_WIDTH = (NUM_MASTERS > 1) ? $clog2(NUM_MASTERS) : 1;
    localparam logic [1:0] RESP_DECERR = 2'b11;

    // Master Continuous Unpacked Aliases
    wire [ADDR_WIDTH-1:0] m_awaddr [0:3];
    wire [2:0]            m_awprot [0:3];
    wire                  m_awvalid[0:3];
    wire [DATA_WIDTH-1:0] m_wdata  [0:3];
    wire [STRB_WIDTH-1:0] m_wstrb  [0:3];
    wire                  m_wvalid [0:3];
    wire                  m_bready [0:3];
    wire [ADDR_WIDTH-1:0] m_araddr [0:3];
    wire [2:0]            m_arprot [0:3];
    wire                  m_arvalid[0:3];
    wire                  m_rready [0:3];

    genvar g;
    generate
        for (g = 0; g < 4; g++) begin : gen_m_aliases
            assign m_awaddr[g]  = s_axi_awaddr[g];
            assign m_awprot[g]  = s_axi_awprot[g];
            assign m_awvalid[g] = s_axi_awvalid[g];
            assign m_wdata[g]   = s_axi_wdata[g];
            assign m_wstrb[g]   = s_axi_wstrb[g];
            assign m_wvalid[g]  = s_axi_wvalid[g];
            assign m_bready[g]  = s_axi_bready[g];
            assign m_araddr[g]  = s_axi_araddr[g];
            assign m_arprot[g]  = s_axi_arprot[g];
            assign m_arvalid[g] = s_axi_arvalid[g];
            assign m_rready[g]  = s_axi_rready[g];
        end
    endgenerate

    // Slave Continuous Unpacked Aliases
    wire        s0_awready = m_axi_awready[0];
    wire        s1_awready = m_axi_awready[1];
    wire        s0_wready  = m_axi_wready[0];
    wire        s1_wready  = m_axi_wready[1];
    wire        s0_bvalid  = m_axi_bvalid[0];
    wire        s1_bvalid  = m_axi_bvalid[1];
    wire [1:0]  s0_bresp   = m_axi_bresp[0];
    wire [1:0]  s1_bresp   = m_axi_bresp[1];

    wire        s0_arready = m_axi_arready[0];
    wire        s1_arready = m_axi_arready[1];
    wire        s0_rvalid  = m_axi_rvalid[0];
    wire        s1_rvalid  = m_axi_rvalid[1];
    wire [DATA_WIDTH-1:0] s0_rdata = m_axi_rdata[0];
    wire [DATA_WIDTH-1:0] s1_rdata = m_axi_rdata[1];
    wire [1:0]  s0_rresp   = m_axi_rresp[0];
    wire [1:0]  s1_rresp   = m_axi_rresp[1];

    // =========================================================================
    // 1. Write Channel Datapath, Dedicated Arbiter & FSM
    // =========================================================================
    typedef enum logic [1:0] {
        W_IDLE    = 2'b00,
        W_AW_WAIT = 2'b01,
        W_W_WAIT  = 2'b10,
        W_B_WAIT  = 2'b11
    } write_state_t;

    write_state_t w_state;

    // Latched write transaction metadata
    logic [M_ID_WIDTH-1:0]       w_owner_m_id;
    logic [1:0]                  w_target_slave_sel;
    logic                        w_target_invalid;
    logic [ADDR_WIDTH-1:0]       w_latched_addr;
    logic [2:0]                  w_latched_prot;

    // Explicit Write QoS Arbiter Signals
    logic [NUM_MASTERS-1:0]      write_arb_req;
    logic                        write_arb_tx_done;
    logic [NUM_MASTERS-1:0]      write_arb_grant;
    logic [M_ID_WIDTH-1:0]       write_arb_master_id;
    logic                        write_arb_grant_valid;
    logic                        write_arb_starvation;

    /* verilator lint_off UNUSEDSIGNAL */
    logic [NUM_MASTERS-1:0]      write_arb_grant_unused;
    logic                        write_arb_starvation_unused;
    logic                        write_eval_valid_addr_unused;
    /* verilator lint_on UNUSEDSIGNAL */

    assign write_arb_req = s_axi_awvalid;
    assign write_arb_grant_unused = write_arb_grant;
    assign write_arb_starvation_unused = write_arb_starvation;

    // Dedicated Write Path QoS Arbiter Instance
    qos_arbiter #(
        .NUM_MASTERS   (NUM_MASTERS),
        .M0_WEIGHT     (M0_WEIGHT),
        .M1_WEIGHT     (M1_WEIGHT),
        .M2_WEIGHT     (M2_WEIGHT),
        .M3_WEIGHT     (M3_WEIGHT),
        .AGE_THRESHOLD (AGE_THRESHOLD)
    ) u_write_arbiter (
        .aclk                 (aclk),
        .aresetn              (aresetn),
        .req                  (write_arb_req),
        .transaction_complete (write_arb_tx_done),
        .grant                (write_arb_grant),
        .master_id            (write_arb_master_id),
        .grant_valid          (write_arb_grant_valid),
        .starvation_flag      (write_arb_starvation)
    );

    // Write Address Decoder
    logic [ADDR_WIDTH-1:0]       w_eval_addr;
    logic [1:0]                  w_eval_slave_sel;
    logic                        w_eval_invalid_addr;

    always_comb begin
        case (write_arb_master_id)
            2'd0: w_eval_addr = m_awaddr[0];
            2'd1: w_eval_addr = m_awaddr[1];
            2'd2: w_eval_addr = m_awaddr[2];
            2'd3: w_eval_addr = m_awaddr[3];
            default: w_eval_addr = m_awaddr[0];
        endcase
    end

    addr_decoder #(
        .ADDR_WIDTH  (ADDR_WIDTH),
        .SLAVE0_BASE (SLAVE0_BASE),
        .SLAVE0_SIZE (SLAVE0_SIZE),
        .SLAVE1_BASE (SLAVE1_BASE),
        .SLAVE1_SIZE (SLAVE1_SIZE)
    ) u_write_addr_decoder (
        .addr         (w_eval_addr),
        .slave_sel    (w_eval_slave_sel),
        .valid_addr   (write_eval_valid_addr_unused),
        .invalid_addr (w_eval_invalid_addr)
    );

    // Selected slave ready signals
    logic w_target_awready;
    logic w_target_wready;
    logic w_target_bvalid;

    always_comb begin
        if (w_target_slave_sel[0]) begin
            w_target_awready = s0_awready;
            w_target_wready  = s0_wready;
            w_target_bvalid  = s0_bvalid;
        end else if (w_target_slave_sel[1]) begin
            w_target_awready = s1_awready;
            w_target_wready  = s1_wready;
            w_target_bvalid  = s1_bvalid;
        end else begin
            w_target_awready = 1'b0;
            w_target_wready  = 1'b0;
            w_target_bvalid  = 1'b0;
        end
    end

    // Selected master write signals
    logic [DATA_WIDTH-1:0] w_owner_wdata;
    logic [STRB_WIDTH-1:0] w_owner_wstrb;
    logic                  w_owner_wvalid;
    logic                  w_owner_bready;

    always_comb begin
        case (w_owner_m_id)
            2'd0: begin
                w_owner_wdata   = m_wdata[0];
                w_owner_wstrb   = m_wstrb[0];
                w_owner_wvalid  = m_wvalid[0];
                w_owner_bready  = m_bready[0];
            end
            2'd1: begin
                w_owner_wdata   = m_wdata[1];
                w_owner_wstrb   = m_wstrb[1];
                w_owner_wvalid  = m_wvalid[1];
                w_owner_bready  = m_bready[1];
            end
            2'd2: begin
                w_owner_wdata   = m_wdata[2];
                w_owner_wstrb   = m_wstrb[2];
                w_owner_wvalid  = m_wvalid[2];
                w_owner_bready  = m_bready[2];
            end
            2'd3: begin
                w_owner_wdata   = m_wdata[3];
                w_owner_wstrb   = m_wstrb[3];
                w_owner_wvalid  = m_wvalid[3];
                w_owner_bready  = m_bready[3];
            end
            default: begin
                w_owner_wdata   = m_wdata[0];
                w_owner_wstrb   = m_wstrb[0];
                w_owner_wvalid  = m_wvalid[0];
                w_owner_bready  = m_bready[0];
            end
        endcase
    end

    // Write FSM Sequential Logic
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            w_state            <= W_IDLE;
            w_owner_m_id       <= '0;
            w_target_slave_sel <= '0;
            w_target_invalid   <= 1'b0;
            w_latched_addr     <= '0;
            w_latched_prot     <= '0;
            write_arb_tx_done  <= 1'b0;
        end else begin
            write_arb_tx_done <= 1'b0;

            case (w_state)
                W_IDLE: begin
                    if (write_arb_grant_valid && m_awvalid[write_arb_master_id]) begin
                        w_owner_m_id       <= write_arb_master_id;
                        w_latched_addr     <= m_awaddr[write_arb_master_id];
                        w_latched_prot     <= m_awprot[write_arb_master_id];
                        w_target_slave_sel <= w_eval_slave_sel;
                        w_target_invalid   <= w_eval_invalid_addr;
                        w_state            <= W_AW_WAIT;
                    end
                end

                W_AW_WAIT: begin
                    if (w_target_invalid) begin
                        w_state <= W_W_WAIT;
                    end else if (w_target_awready) begin
                        w_state <= W_W_WAIT;
                    end
                end

                W_W_WAIT: begin
                    if (w_target_invalid) begin
                        if (w_owner_wvalid) begin
                            w_state <= W_B_WAIT;
                        end
                    end else if (w_owner_wvalid && w_target_wready) begin
                        w_state <= W_B_WAIT;
                    end
                end

                W_B_WAIT: begin
                    if (w_target_invalid) begin
                        if (w_owner_bready) begin
                            write_arb_tx_done <= 1'b1;
                            w_state           <= W_IDLE;
                        end
                    end else if (w_target_bvalid && w_owner_bready) begin
                        write_arb_tx_done <= 1'b1;
                        w_state           <= W_IDLE;
                    end
                end

                default: w_state <= W_IDLE;
            endcase
        end
    end

    // Master-side Output Demux logic
    logic [3:0] w_awready_demux;
    logic [3:0] w_wready_demux;
    logic [3:0] w_bvalid_demux;
    logic [1:0] w_bresp_demux [0:3];

    // Slave-side Output Mux logic
    logic       s0_awvalid_mux, s1_awvalid_mux;
    logic       s0_wvalid_mux,  s1_wvalid_mux;
    logic       s0_bready_mux,  s1_bready_mux;

    always_comb begin
        w_awready_demux = 4'b0000;
        w_wready_demux  = 4'b0000;
        w_bvalid_demux  = 4'b0000;
        for (int i = 0; i < 4; i++) w_bresp_demux[i] = 2'b00;

        s0_awvalid_mux = 1'b0;
        s1_awvalid_mux = 1'b0;
        s0_wvalid_mux  = 1'b0;
        s1_wvalid_mux  = 1'b0;
        s0_bready_mux  = 1'b0;
        s1_bready_mux  = 1'b0;

        case (w_state)
            W_IDLE: begin
            end

            W_AW_WAIT: begin
                if (w_target_invalid) begin
                    w_awready_demux[w_owner_m_id] = 1'b1;
                end else begin
                    if (w_target_slave_sel[0]) begin
                        s0_awvalid_mux                = 1'b1;
                        w_awready_demux[w_owner_m_id] = s0_awready;
                    end else if (w_target_slave_sel[1]) begin
                        s1_awvalid_mux                = 1'b1;
                        w_awready_demux[w_owner_m_id] = s1_awready;
                    end
                end
            end

            W_W_WAIT: begin
                if (w_target_invalid) begin
                    w_wready_demux[w_owner_m_id] = 1'b1;
                end else begin
                    if (w_target_slave_sel[0]) begin
                        s0_wvalid_mux                = w_owner_wvalid;
                        w_wready_demux[w_owner_m_id] = s0_wready;
                    end else if (w_target_slave_sel[1]) begin
                        s1_wvalid_mux                = w_owner_wvalid;
                        w_wready_demux[w_owner_m_id] = s1_wready;
                    end
                end
            end

            W_B_WAIT: begin
                if (w_target_invalid) begin
                    w_bvalid_demux[w_owner_m_id] = 1'b1;
                    w_bresp_demux[w_owner_m_id]  = RESP_DECERR;
                end else begin
                    if (w_target_slave_sel[0]) begin
                        w_bvalid_demux[w_owner_m_id] = s0_bvalid;
                        w_bresp_demux[w_owner_m_id]  = s0_bresp;
                        s0_bready_mux                = w_owner_bready;
                    end else if (w_target_slave_sel[1]) begin
                        w_bvalid_demux[w_owner_m_id] = s1_bvalid;
                        w_bresp_demux[w_owner_m_id]  = s1_bresp;
                        s1_bready_mux                = w_owner_bready;
                    end
                end
            end

            default: ;
        endcase
    end

    // Master Write Outputs
    assign s_axi_awready = w_awready_demux;
    assign s_axi_wready  = w_wready_demux;
    assign s_axi_bvalid  = w_bvalid_demux;
    assign s_axi_bresp[0] = w_bresp_demux[0];
    assign s_axi_bresp[1] = w_bresp_demux[1];
    assign s_axi_bresp[2] = w_bresp_demux[2];
    assign s_axi_bresp[3] = w_bresp_demux[3];

    // Slave Write Outputs
    assign m_axi_awaddr[0]  = w_latched_addr;
    assign m_axi_awprot[0]  = w_latched_prot;
    assign m_axi_awvalid[0] = s0_awvalid_mux;
    assign m_axi_wdata[0]   = w_owner_wdata;
    assign m_axi_wstrb[0]   = w_owner_wstrb;
    assign m_axi_wvalid[0]  = s0_wvalid_mux;
    assign m_axi_bready[0]  = s0_bready_mux;

    assign m_axi_awaddr[1]  = w_latched_addr;
    assign m_axi_awprot[1]  = w_latched_prot;
    assign m_axi_awvalid[1] = s1_awvalid_mux;
    assign m_axi_wdata[1]   = w_owner_wdata;
    assign m_axi_wstrb[1]   = w_owner_wstrb;
    assign m_axi_wvalid[1]  = s1_wvalid_mux;
    assign m_axi_bready[1]  = s1_bready_mux;

    // =========================================================================
    // 2. Read Channel Datapath, Dedicated Arbiter & FSM
    // =========================================================================
    typedef enum logic [1:0] {
        R_IDLE    = 2'b00,
        R_AR_WAIT = 2'b01,
        R_R_WAIT  = 2'b10
    } read_state_t;

    read_state_t r_state;

    // Latched read transaction metadata
    logic [M_ID_WIDTH-1:0]       r_owner_m_id;
    logic [1:0]                  r_target_slave_sel;
    logic                        r_target_invalid;
    logic [ADDR_WIDTH-1:0]       r_latched_addr;
    logic [2:0]                  r_latched_prot;

    // Explicit Read QoS Arbiter Signals
    logic [NUM_MASTERS-1:0]      read_arb_req;
    logic                        read_arb_tx_done;
    logic [NUM_MASTERS-1:0]      read_arb_grant;
    logic [M_ID_WIDTH-1:0]       read_arb_master_id;
    logic                        read_arb_grant_valid;
    logic                        read_arb_starvation;

    /* verilator lint_off UNUSEDSIGNAL */
    logic [NUM_MASTERS-1:0]      read_arb_grant_unused;
    logic                        read_arb_starvation_unused;
    logic                        read_eval_valid_addr_unused;
    /* verilator lint_on UNUSEDSIGNAL */

    assign read_arb_req = s_axi_arvalid;
    assign read_arb_grant_unused = read_arb_grant;
    assign read_arb_starvation_unused = read_arb_starvation;

    // Dedicated Read Path QoS Arbiter Instance
    qos_arbiter #(
        .NUM_MASTERS   (NUM_MASTERS),
        .M0_WEIGHT     (M0_WEIGHT),
        .M1_WEIGHT     (M1_WEIGHT),
        .M2_WEIGHT     (M2_WEIGHT),
        .M3_WEIGHT     (M3_WEIGHT),
        .AGE_THRESHOLD (AGE_THRESHOLD)
    ) u_read_arbiter (
        .aclk                 (aclk),
        .aresetn              (aresetn),
        .req                  (read_arb_req),
        .transaction_complete (read_arb_tx_done),
        .grant                (read_arb_grant),
        .master_id            (read_arb_master_id),
        .grant_valid          (read_arb_grant_valid),
        .starvation_flag      (read_arb_starvation)
    );

    // Read Address Decoder
    logic [ADDR_WIDTH-1:0]       r_eval_addr;
    logic [1:0]                  r_eval_slave_sel;
    logic                        r_eval_invalid_addr;

    always_comb begin
        case (read_arb_master_id)
            2'd0: r_eval_addr = m_araddr[0];
            2'd1: r_eval_addr = m_araddr[1];
            2'd2: r_eval_addr = m_araddr[2];
            2'd3: r_eval_addr = m_araddr[3];
            default: r_eval_addr = m_araddr[0];
        endcase
    end

    addr_decoder #(
        .ADDR_WIDTH  (ADDR_WIDTH),
        .SLAVE0_BASE (SLAVE0_BASE),
        .SLAVE0_SIZE (SLAVE0_SIZE),
        .SLAVE1_BASE (SLAVE1_BASE),
        .SLAVE1_SIZE (SLAVE1_SIZE)
    ) u_read_addr_decoder (
        .addr         (r_eval_addr),
        .slave_sel    (r_eval_slave_sel),
        .valid_addr   (read_eval_valid_addr_unused),
        .invalid_addr (r_eval_invalid_addr)
    );

    // Selected read slave ready signals
    logic r_target_arready;
    logic r_target_rvalid;

    always_comb begin
        if (r_target_slave_sel[0]) begin
            r_target_arready = s0_arready;
            r_target_rvalid  = s0_rvalid;
        end else if (r_target_slave_sel[1]) begin
            r_target_arready = s1_arready;
            r_target_rvalid  = s1_rvalid;
        end else begin
            r_target_arready = 1'b0;
            r_target_rvalid  = 1'b0;
        end
    end

    // Selected master read signals
    logic r_owner_rready;

    always_comb begin
        case (r_owner_m_id)
            2'd0: r_owner_rready = m_rready[0];
            2'd1: r_owner_rready = m_rready[1];
            2'd2: r_owner_rready = m_rready[2];
            2'd3: r_owner_rready = m_rready[3];
            default: r_owner_rready = m_rready[0];
        endcase
    end

    // Read FSM Sequential Logic
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            r_state            <= R_IDLE;
            r_owner_m_id       <= '0;
            r_target_slave_sel <= '0;
            r_target_invalid   <= 1'b0;
            r_latched_addr     <= '0;
            r_latched_prot     <= '0;
            read_arb_tx_done   <= 1'b0;
        end else begin
            read_arb_tx_done <= 1'b0;

            case (r_state)
                R_IDLE: begin
                    if (read_arb_grant_valid && m_arvalid[read_arb_master_id]) begin
                        r_owner_m_id       <= read_arb_master_id;
                        r_latched_addr     <= m_araddr[read_arb_master_id];
                        r_latched_prot     <= m_arprot[read_arb_master_id];
                        r_target_slave_sel <= r_eval_slave_sel;
                        r_target_invalid   <= r_eval_invalid_addr;
                        r_state            <= R_AR_WAIT;
                    end
                end

                R_AR_WAIT: begin
                    if (r_target_invalid) begin
                        r_state <= R_R_WAIT;
                    end else if (r_target_arready) begin
                        r_state <= R_R_WAIT;
                    end
                end

                R_R_WAIT: begin
                    if (r_target_invalid) begin
                        if (r_owner_rready) begin
                            read_arb_tx_done <= 1'b1;
                            r_state          <= R_IDLE;
                        end
                    end else if (r_target_rvalid && r_owner_rready) begin
                        read_arb_tx_done <= 1'b1;
                        r_state          <= R_IDLE;
                    end
                end

                default: r_state <= R_IDLE;
            endcase
        end
    end

    // Master-side Read Output Demux
    logic [3:0]            r_arready_demux;
    logic [3:0]            r_rvalid_demux;
    logic [DATA_WIDTH-1:0] r_rdata_demux [0:3];
    logic [1:0]            r_rresp_demux [0:3];

    // Slave-side Read Output Mux
    logic s0_arvalid_mux, s1_arvalid_mux;
    logic s0_rready_mux,  s1_rready_mux;

    always_comb begin
        r_arready_demux = 4'b0000;
        r_rvalid_demux  = 4'b0000;
        for (int i = 0; i < 4; i++) begin
            r_rdata_demux[i] = '0;
            r_rresp_demux[i] = 2'b00;
        end

        s0_arvalid_mux = 1'b0;
        s1_arvalid_mux = 1'b0;
        s0_rready_mux  = 1'b0;
        s1_rready_mux  = 1'b0;

        case (r_state)
            R_IDLE: begin
            end

            R_AR_WAIT: begin
                if (r_target_invalid) begin
                    r_arready_demux[r_owner_m_id] = 1'b1;
                end else begin
                    if (r_target_slave_sel[0]) begin
                        s0_arvalid_mux                = 1'b1;
                        r_arready_demux[r_owner_m_id] = s0_arready;
                    end else if (r_target_slave_sel[1]) begin
                        s1_arvalid_mux                = 1'b1;
                        r_arready_demux[r_owner_m_id] = s1_arready;
                    end
                end
            end

            R_R_WAIT: begin
                if (r_target_invalid) begin
                    r_rvalid_demux[r_owner_m_id] = 1'b1;
                    r_rdata_demux[r_owner_m_id]  = '0;
                    r_rresp_demux[r_owner_m_id]  = RESP_DECERR;
                end else begin
                    if (r_target_slave_sel[0]) begin
                        r_rvalid_demux[r_owner_m_id] = s0_rvalid;
                        r_rdata_demux[r_owner_m_id]  = s0_rdata;
                        r_rresp_demux[r_owner_m_id]  = s0_rresp;
                        s0_rready_mux                = r_owner_rready;
                    end else if (r_target_slave_sel[1]) begin
                        r_rvalid_demux[r_owner_m_id] = s1_rvalid;
                        r_rdata_demux[r_owner_m_id]  = s1_rdata;
                        r_rresp_demux[r_owner_m_id]  = s1_rresp;
                        s1_rready_mux                = r_owner_rready;
                    end
                end
            end

            default: ;
        endcase
    end

    // Master Read Outputs
    assign s_axi_arready = r_arready_demux;
    assign s_axi_rvalid  = r_rvalid_demux;
    assign s_axi_rdata[0] = r_rdata_demux[0];
    assign s_axi_rdata[1] = r_rdata_demux[1];
    assign s_axi_rdata[2] = r_rdata_demux[2];
    assign s_axi_rdata[3] = r_rdata_demux[3];
    assign s_axi_rresp[0] = r_rresp_demux[0];
    assign s_axi_rresp[1] = r_rresp_demux[1];
    assign s_axi_rresp[2] = r_rresp_demux[2];
    assign s_axi_rresp[3] = r_rresp_demux[3];

    // Slave Read Outputs
    assign m_axi_araddr[0]  = r_latched_addr;
    assign m_axi_arprot[0]  = r_latched_prot;
    assign m_axi_arvalid[0] = s0_arvalid_mux;
    assign m_axi_rready[0]  = s0_rready_mux;

    assign m_axi_araddr[1]  = r_latched_addr;
    assign m_axi_arprot[1]  = r_latched_prot;
    assign m_axi_arvalid[1] = s1_arvalid_mux;
    assign m_axi_rready[1]  = s1_rready_mux;

`ifdef ASSERTIONS
    // SVA Assertions for protocol safety & isolation
    property p_single_w_owner;
        @(posedge aclk) disable iff (!aresetn)
        $onehot0(s_axi_awready);
    endproperty
    assert property (p_single_w_owner)
        else $error("[axi4lite_arbiter_top] Multiple AWREADY asserted simultaneously!");

    property p_single_wready_owner;
        @(posedge aclk) disable iff (!aresetn)
        $onehot0(s_axi_wready);
    endproperty
    assert property (p_single_wready_owner)
        else $error("[axi4lite_arbiter_top] Multiple WREADY asserted simultaneously!");

    property p_single_bvalid_owner;
        @(posedge aclk) disable iff (!aresetn)
        $onehot0(s_axi_bvalid);
    endproperty
    assert property (p_single_bvalid_owner)
        else $error("[axi4lite_arbiter_top] Multiple BVALID asserted simultaneously!");

    property p_single_r_owner;
        @(posedge aclk) disable iff (!aresetn)
        $onehot0(s_axi_arready);
    endproperty
    assert property (p_single_r_owner)
        else $error("[axi4lite_arbiter_top] Multiple ARREADY asserted simultaneously!");

    property p_single_rvalid_owner;
        @(posedge aclk) disable iff (!aresetn)
        $onehot0(s_axi_rvalid);
    endproperty
    assert property (p_single_rvalid_owner)
        else $error("[axi4lite_arbiter_top] Multiple RVALID asserted simultaneously!");

    property p_single_slave_arvalid;
        @(posedge aclk) disable iff (!aresetn)
        $onehot0(m_axi_arvalid);
    endproperty
    assert property (p_single_slave_arvalid)
        else $error("[axi4lite_arbiter_top] Multiple slave ARVALID asserted simultaneously!");

    property p_single_slave_awvalid;
        @(posedge aclk) disable iff (!aresetn)
        $onehot0(m_axi_awvalid);
    endproperty
    assert property (p_single_slave_awvalid)
        else $error("[axi4lite_arbiter_top] Multiple slave AWVALID asserted simultaneously!");

    property p_w_owner_stable;
        @(posedge aclk) disable iff (!aresetn)
        (w_state != W_IDLE) |=> (w_owner_m_id == $past(w_owner_m_id));
    endproperty
    assert property (p_w_owner_stable)
        else $error("[axi4lite_arbiter_top] Write transaction owner changed mid-flight!");

    property p_r_owner_stable;
        @(posedge aclk) disable iff (!aresetn)
        (r_state != R_IDLE) |=> (r_owner_m_id == $past(r_owner_m_id));
    endproperty
    assert property (p_r_owner_stable)
        else $error("[axi4lite_arbiter_top] Read transaction owner changed mid-flight!");
`endif

endmodule
