// =============================================================================
// File       : axi4lite_arbiter_top.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: Synthesizable 4-Master, 2-Slave AXI4-Lite Shared-Bus Interconnect
//              Top-level module featuring:
//              - Independent Write Arbiter with AW/W per-master buffering
//              - Independent Read Arbiter with QoS scheduling
//              - Centralized Response Router for B and R channels
//              - Dynamic runtime QoS configuration via sideband ports
//              - Internal DECERR generation for unmapped addresses
//              - Single outstanding read + single outstanding write (conservative)
//              - Strict AXI4-Lite handshake compliance (ARM IHI 0022E)
//
// Module Hierarchy:
//   axi4lite_arbiter_top
//   ├── axi4lite_write_arbiter
//   │   ├── axi4lite_qos_scheduler
//   │   └── axi4lite_address_decoder
//   ├── axi4lite_read_arbiter
//   │   ├── axi4lite_qos_scheduler
//   │   └── axi4lite_address_decoder
//   └── axi4lite_response_router
//
// Conservative Outstanding-Transaction Policy (Intentional):
//   - At most 1 outstanding write transaction system-wide
//   - At most 1 outstanding read transaction system-wide
//   - Write arbitrated only after the same master has both AW and W buffered
//   - Write owner locked until B response accepted
//   - Read owner locked until R response accepted
//   - No response routed to the wrong master
//   - No request duplicated, dropped, reordered, or overwritten
// =============================================================================

`timescale 1ns / 1ps

module axi4lite_arbiter_top #(
    parameter int NUM_MASTERS   = 4,
    parameter int NUM_SLAVES    = 2,
    parameter int ADDR_WIDTH    = 32,
    parameter int DATA_WIDTH    = 32,
    parameter int STRB_WIDTH    = DATA_WIDTH / 8,

    // Slave Address Regions
    parameter logic [ADDR_WIDTH-1:0] S0_BASE = 32'h0000_0000,
    parameter logic [ADDR_WIDTH-1:0] S0_SIZE = 32'h0001_0000,
    parameter logic [ADDR_WIDTH-1:0] S1_BASE = 32'h0001_0000,
    parameter logic [ADDR_WIDTH-1:0] S1_SIZE = 32'h0001_0000
) (
    input  logic                                            aclk,
    input  logic                                            aresetn,

    // -------------------------------------------------------------------------
    // Sideband QoS Configuration Interface
    // -------------------------------------------------------------------------
    // Per-master 4-bit weights. Valid range: 1–15. Zero is clamped to 1.
    input  logic [3:0]                                      cfg_weight_m0,
    input  logic [3:0]                                      cfg_weight_m1,
    input  logic [3:0]                                      cfg_weight_m2,
    input  logic [3:0]                                      cfg_weight_m3,
    // Master 0 preemptive priority enable
    input  logic                                            cfg_master0_priority,
    // Anti-starvation aging threshold (cycles). Zero is clamped to 1.
    input  logic [7:0]                                      cfg_age_threshold,
    // Max consecutive M0 grants before yielding. Zero is clamped to 1.
    input  logic [7:0]                                      cfg_master0_burst_limit,

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

    // Compile-time parameter assertions
    initial begin
        if (NUM_MASTERS != 4)
            $fatal(1, "[axi4lite_arbiter_top] NUM_MASTERS must be 4 (got %0d)", NUM_MASTERS);
        if (NUM_SLAVES != 2)
            $fatal(1, "[axi4lite_arbiter_top] NUM_SLAVES must be 2 (got %0d)", NUM_SLAVES);
    end

    // =========================================================================
    // 1. Write Arbiter ↔ Response Router Interconnect
    // =========================================================================
    logic [M_ID_WIDTH-1:0]  w_owner_id;
    logic [NUM_SLAVES-1:0]  w_target_slave;
    logic                   w_target_invalid;
    logic                   w_resp_phase;
    logic                   w_resp_handshake;
    logic                   w_owner_bready;

    // =========================================================================
    // 2. Read Arbiter ↔ Response Router Interconnect
    // =========================================================================
    logic [M_ID_WIDTH-1:0]  r_owner_id;
    logic [NUM_SLAVES-1:0]  r_target_slave;
    logic                   r_target_invalid;
    logic                   r_resp_phase;
    logic                   r_resp_handshake;

    /* verilator lint_off UNUSEDSIGNAL */
    logic                   r_owner_rready_unused;
    /* verilator lint_on UNUSEDSIGNAL */

    // =========================================================================
    // 3. Write Arbiter Instance
    // =========================================================================
    axi4lite_write_arbiter #(
        .NUM_MASTERS (NUM_MASTERS),
        .NUM_SLAVES  (NUM_SLAVES),
        .ADDR_WIDTH  (ADDR_WIDTH),
        .DATA_WIDTH  (DATA_WIDTH),
        .STRB_WIDTH  (STRB_WIDTH),
        .S0_BASE     (S0_BASE),
        .S0_SIZE     (S0_SIZE),
        .S1_BASE     (S1_BASE),
        .S1_SIZE     (S1_SIZE)
    ) u_write_arbiter (
        .aclk                   (aclk),
        .aresetn                (aresetn),
        // QoS config
        .cfg_weight_m0          (cfg_weight_m0),
        .cfg_weight_m1          (cfg_weight_m1),
        .cfg_weight_m2          (cfg_weight_m2),
        .cfg_weight_m3          (cfg_weight_m3),
        .cfg_master0_priority   (cfg_master0_priority),
        .cfg_age_threshold      (cfg_age_threshold),
        .cfg_master0_burst_limit(cfg_master0_burst_limit),
        // Master AW
        .s_axi_awaddr           (s_axi_awaddr),
        .s_axi_awprot           (s_axi_awprot),
        .s_axi_awvalid          (s_axi_awvalid),
        .s_axi_awready          (s_axi_awready),
        // Master W
        .s_axi_wdata            (s_axi_wdata),
        .s_axi_wstrb            (s_axi_wstrb),
        .s_axi_wvalid           (s_axi_wvalid),
        .s_axi_wready           (s_axi_wready),
        // Owner/target for response router
        .w_owner_id             (w_owner_id),
        .w_target_slave         (w_target_slave),
        .w_target_invalid       (w_target_invalid),
        .w_resp_phase           (w_resp_phase),
        .w_resp_handshake       (w_resp_handshake),
        .w_owner_bready         (w_owner_bready),
        // Slave AW
        .m_axi_awaddr           (m_axi_awaddr),
        .m_axi_awprot           (m_axi_awprot),
        .m_axi_awvalid          (m_axi_awvalid),
        .m_axi_awready          (m_axi_awready),
        // Slave W
        .m_axi_wdata            (m_axi_wdata),
        .m_axi_wstrb            (m_axi_wstrb),
        .m_axi_wvalid           (m_axi_wvalid),
        .m_axi_wready           (m_axi_wready)
    );

    // =========================================================================
    // 4. Read Arbiter Instance
    // =========================================================================
    axi4lite_read_arbiter #(
        .NUM_MASTERS (NUM_MASTERS),
        .NUM_SLAVES  (NUM_SLAVES),
        .ADDR_WIDTH  (ADDR_WIDTH),
        .DATA_WIDTH  (DATA_WIDTH),
        .S0_BASE     (S0_BASE),
        .S0_SIZE     (S0_SIZE),
        .S1_BASE     (S1_BASE),
        .S1_SIZE     (S1_SIZE)
    ) u_read_arbiter (
        .aclk                   (aclk),
        .aresetn                (aresetn),
        // QoS config
        .cfg_weight_m0          (cfg_weight_m0),
        .cfg_weight_m1          (cfg_weight_m1),
        .cfg_weight_m2          (cfg_weight_m2),
        .cfg_weight_m3          (cfg_weight_m3),
        .cfg_master0_priority   (cfg_master0_priority),
        .cfg_age_threshold      (cfg_age_threshold),
        .cfg_master0_burst_limit(cfg_master0_burst_limit),
        // Master AR
        .s_axi_araddr           (s_axi_araddr),
        .s_axi_arprot           (s_axi_arprot),
        .s_axi_arvalid          (s_axi_arvalid),
        .s_axi_arready          (s_axi_arready),
        // Owner/target for response router
        .r_owner_id             (r_owner_id),
        .r_target_slave         (r_target_slave),
        .r_target_invalid       (r_target_invalid),
        .r_resp_phase           (r_resp_phase),
        .r_resp_handshake       (r_resp_handshake),
        // Slave AR
        .m_axi_araddr           (m_axi_araddr),
        .m_axi_arprot           (m_axi_arprot),
        .m_axi_arvalid          (m_axi_arvalid),
        .m_axi_arready          (m_axi_arready)
    );

    // =========================================================================
    // 5. Response Router Instance
    // =========================================================================
    axi4lite_response_router #(
        .NUM_MASTERS (NUM_MASTERS),
        .NUM_SLAVES  (NUM_SLAVES),
        .DATA_WIDTH  (DATA_WIDTH)
    ) u_response_router (
        // Write response
        .w_active           (w_resp_phase),
        .w_owner_id         (w_owner_id),
        .w_target_slave     (w_target_slave),
        .w_target_invalid   (w_target_invalid),
        .s_bresp            (m_axi_bresp),
        .s_bvalid           (m_axi_bvalid),
        .s_bready           (m_axi_bready),
        .m_bresp            (s_axi_bresp),
        .m_bvalid           (s_axi_bvalid),
        .m_bready           (s_axi_bready),
        .w_resp_handshake   (w_resp_handshake),
        .w_owner_bready     (w_owner_bready),
        // Read response
        .r_active           (r_resp_phase),
        .r_owner_id         (r_owner_id),
        .r_target_slave     (r_target_slave),
        .r_target_invalid   (r_target_invalid),
        .s_rdata            (m_axi_rdata),
        .s_rresp            (m_axi_rresp),
        .s_rvalid           (m_axi_rvalid),
        .s_rready           (m_axi_rready),
        .m_rdata            (s_axi_rdata),
        .m_rresp            (s_axi_rresp),
        .m_rvalid           (s_axi_rvalid),
        .m_rready           (s_axi_rready),
        .r_resp_handshake   (r_resp_handshake),
        .r_owner_rready     (r_owner_rready_unused)
    );

    // =========================================================================
    // 6. Synthesis-Safe SVA Assertions
    // =========================================================================
`ifdef ASSERTIONS
    // Note: Multiple AWREADYs/WREADYs are legal — each master has an independent
    // AW/W buffer, so multiple masters can be accepted simultaneously.
    // ARREADYs are at-most-one since only the owner gets ARREADY.

    property p_single_bvalid_owner;
        @(posedge aclk) disable iff (!aresetn)
        $onehot0(s_axi_bvalid);
    endproperty
    assert property (p_single_bvalid_owner)
        else $error("[axi4lite_arbiter_top] Multiple BVALID asserted!");

    property p_single_rvalid_owner;
        @(posedge aclk) disable iff (!aresetn)
        $onehot0(s_axi_rvalid);
    endproperty
    assert property (p_single_rvalid_owner)
        else $error("[axi4lite_arbiter_top] Multiple RVALID asserted!");

    // Slave-side exclusivity
    property p_single_slave_awvalid;
        @(posedge aclk) disable iff (!aresetn)
        $onehot0(m_axi_awvalid);
    endproperty
    assert property (p_single_slave_awvalid)
        else $error("[axi4lite_arbiter_top] Multiple slave AWVALID!");

    property p_single_slave_wvalid;
        @(posedge aclk) disable iff (!aresetn)
        $onehot0(m_axi_wvalid);
    endproperty
    assert property (p_single_slave_wvalid)
        else $error("[axi4lite_arbiter_top] Multiple slave WVALID!");

    property p_single_slave_arvalid;
        @(posedge aclk) disable iff (!aresetn)
        $onehot0(m_axi_arvalid);
    endproperty
    assert property (p_single_slave_arvalid)
        else $error("[axi4lite_arbiter_top] Multiple slave ARVALID!");
`endif

endmodule
