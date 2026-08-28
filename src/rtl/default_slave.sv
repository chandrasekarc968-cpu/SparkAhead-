// =============================================================================
// File       : default_slave.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: Synthesizable Default AXI4-Lite Slave Responder
//              - Absorbs invalid/unmapped address transactions internally
//              - Returns BRESP = 2'b11 (DECERR) for invalid write accesses
//              - Returns RRESP = 2'b11 (DECERR) and RDATA = 32'h0 for invalid reads
//              - Isolates external downstream slaves from unmapped traffic
// =============================================================================

`timescale 1ns / 1ps

module default_slave #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int STRB_WIDTH = DATA_WIDTH / 8
) (
    input  logic                  aclk,
    input  logic                  aresetn,

    // Write Address Channel
    input  logic [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic [2:0]            s_axi_awprot,
    input  logic                  s_axi_awvalid,
    output logic                  s_axi_awready,

    // Write Data Channel
    input  logic [DATA_WIDTH-1:0] s_axi_wdata,
    input  logic [STRB_WIDTH-1:0] s_axi_wstrb,
    input  logic                  s_axi_wvalid,
    output logic                  s_axi_wready,

    // Write Response Channel
    output logic [1:0]            s_axi_bresp,
    output logic                  s_axi_bvalid,
    input  logic                  s_axi_bready,

    // Read Address Channel
    input  logic [ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic [2:0]            s_axi_arprot,
    input  logic                  s_axi_arvalid,
    output logic                  s_axi_arready,

    // Read Data Channel
    output logic [DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]            s_axi_rresp,
    output logic                  s_axi_rvalid,
    input  logic                  s_axi_rready
);

    localparam logic [1:0] RESP_DECERR = 2'b11;

    // Unused input suppression
    /* verilator lint_off UNUSEDSIGNAL */
    wire [ADDR_WIDTH-1:0] unused_awaddr = s_axi_awaddr;
    wire [2:0]            unused_awprot = s_axi_awprot;
    wire [DATA_WIDTH-1:0] unused_wdata  = s_axi_wdata;
    wire [STRB_WIDTH-1:0] unused_wstrb  = s_axi_wstrb;
    wire [ADDR_WIDTH-1:0] unused_araddr = s_axi_araddr;
    wire [2:0]            unused_arprot = s_axi_arprot;
    /* verilator lint_on UNUSEDSIGNAL */

    // -------------------------------------------------------------------------
    // Write Response DECERR Generator
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        W_IDLE   = 2'b00,
        W_ACCEPT = 2'b01,
        W_RESP   = 2'b10
    } def_w_state_t;

    def_w_state_t w_state;
    logic aw_done, w_done;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            w_state       <= W_IDLE;
            aw_done       <= 1'b0;
            w_done        <= 1'b0;
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= RESP_DECERR;
        end else begin
            case (w_state)
                W_IDLE: begin
                    s_axi_bvalid <= 1'b0;
                    s_axi_bresp  <= RESP_DECERR;
                    if (s_axi_awvalid || s_axi_wvalid) begin
                        s_axi_awready <= s_axi_awvalid;
                        s_axi_wready  <= s_axi_wvalid;
                        aw_done       <= s_axi_awvalid;
                        w_done        <= s_axi_wvalid;
                        if (s_axi_awvalid && s_axi_wvalid) begin
                            w_state      <= W_RESP;
                            s_axi_bvalid <= 1'b1;
                        end else begin
                            w_state <= W_ACCEPT;
                        end
                    end
                end

                W_ACCEPT: begin
                    if (!aw_done && s_axi_awvalid) begin
                        s_axi_awready <= 1'b1;
                        aw_done       <= 1'b1;
                    end else begin
                        s_axi_awready <= 1'b0;
                    end

                    if (!w_done && s_axi_wvalid) begin
                        s_axi_wready <= 1'b1;
                        w_done       <= 1'b1;
                    end else begin
                        s_axi_wready <= 1'b0;
                    end

                    if ((aw_done || s_axi_awvalid) && (w_done || s_axi_wvalid)) begin
                        w_state      <= W_RESP;
                        s_axi_bvalid <= 1'b1;
                    end
                end

                W_RESP: begin
                    s_axi_awready <= 1'b0;
                    s_axi_wready  <= 1'b0;
                    if (s_axi_bready && s_axi_bvalid) begin
                        s_axi_bvalid <= 1'b0;
                        aw_done      <= 1'b0;
                        w_done       <= 1'b0;
                        w_state      <= W_IDLE;
                    end
                end

                default: w_state <= W_IDLE;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Read Response DECERR Generator
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        R_IDLE = 2'b00,
        R_RESP = 2'b01
    } def_r_state_t;

    def_r_state_t r_state;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            r_state       <= R_IDLE;
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= RESP_DECERR;
            s_axi_rdata   <= '0;
        end else begin
            case (r_state)
                R_IDLE: begin
                    s_axi_rvalid <= 1'b0;
                    s_axi_rresp  <= RESP_DECERR;
                    s_axi_rdata  <= '0;
                    if (s_axi_arvalid) begin
                        s_axi_arready <= 1'b1;
                        s_axi_rvalid  <= 1'b1;
                        r_state       <= R_RESP;
                    end else begin
                        s_axi_arready <= 1'b0;
                    end
                end

                R_RESP: begin
                    s_axi_arready <= 1'b0;
                    if (s_axi_rready && s_axi_rvalid) begin
                        s_axi_rvalid <= 1'b0;
                        r_state      <= R_IDLE;
                    end
                end

                default: r_state <= R_IDLE;
            endcase
        end
    end

endmodule
