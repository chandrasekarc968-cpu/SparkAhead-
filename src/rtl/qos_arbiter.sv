// =============================================================================
// File       : qos_arbiter.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: Synthesizable QoS Arbiter supporting:
//              - Master 0 immediate priority (preemption at decision boundaries)
//              - Weighted Round-Robin (WRR) scheduling for M1..M3
//              - Anti-starvation aging timer for lower-priority traffic
//              - Seamless back-to-back scheduling with zero dead-cycle penalty
//              - Safe weights (clamped to >= 1) and deterministic active-low reset
// =============================================================================

`timescale 1ns / 1ps

/* verilator lint_off MULTITOP */

module qos_arbiter #(
    parameter int NUM_MASTERS   = 4,
    parameter int M0_WEIGHT     = 1,
    parameter int M1_WEIGHT     = 3,
    parameter int M2_WEIGHT     = 2,
    parameter int M3_WEIGHT     = 1,
    parameter int AGE_THRESHOLD = 64
) (
    input  logic                     aclk,
    input  logic                     aresetn,

    // Master request vector (bit 0: M0, bit 1: M1, ..., bit 3: M3)
    input  logic [NUM_MASTERS-1:0]   req,

    // Handshake indicating the active transaction has finished
    input  logic                     transaction_complete,

    // Arbitration outputs
    output logic [NUM_MASTERS-1:0]   grant,           // One-hot grant vector
    output logic [$clog2(NUM_MASTERS)-1:0] master_id, // Granted master ID (0..NUM_MASTERS-1)
    output logic                     grant_valid,     // 1 if an active grant exists
    output logic                     starvation_flag  // 1 if age timer reached threshold
);

    localparam int ID_WIDTH = (NUM_MASTERS > 1) ? $clog2(NUM_MASTERS) : 1;

    // Weight sanitization (clamped to at least 1)
    /* verilator lint_off UNUSEDPARAM */
    localparam int W0 = (M0_WEIGHT > 0) ? M0_WEIGHT : 1;
    /* verilator lint_on UNUSEDPARAM */
    localparam int W1 = (M1_WEIGHT > 0) ? M1_WEIGHT : 1;
    localparam int W2 = (M2_WEIGHT > 0) ? M2_WEIGHT : 1;
    localparam int W3 = (M3_WEIGHT > 0) ? M3_WEIGHT : 1;

    // Individual request wires (avoids constant select warnings in older simulators)
    logic m0_req;
    logic m1_req;
    logic m2_req;
    logic m3_req;
    logic has_lower_req;

    assign m0_req        = req[0];
    assign m1_req        = (NUM_MASTERS > 1) ? req[1] : 1'b0;
    assign m2_req        = (NUM_MASTERS > 2) ? req[2] : 1'b0;
    assign m3_req        = (NUM_MASTERS > 3) ? req[3] : 1'b0;
    assign has_lower_req = m1_req | m2_req | m3_req;

    // -------------------------------------------------------------------------
    // Internal Registers & State
    // -------------------------------------------------------------------------
    logic [ID_WIDTH-1:0]      current_master;
    logic                     is_active;

    // WRR tracking for M1..M3
    int                       quota_1;
    int                       quota_2;
    int                       quota_3;
    logic [ID_WIDTH-1:0]      rr_ptr;

    // Starvation / aging timer
    int unsigned              age_counter;

    // -------------------------------------------------------------------------
    // Effective Quota & Pointer & Starvation for next decision
    // -------------------------------------------------------------------------
    int                  eff_q1, eff_q2, eff_q3;
    logic [ID_WIDTH-1:0] eff_rr_ptr;
    logic                eff_starvation;

    always_comb begin
        eff_q1         = quota_1;
        eff_q2         = quota_2;
        eff_q3         = quota_3;
        eff_rr_ptr     = rr_ptr;
        eff_starvation = starvation_flag;

        if (is_active && transaction_complete) begin
            if (current_master != 0) begin
                eff_starvation = 1'b0;
            end
            case (current_master)
                ID_WIDTH'(1): begin
                    if (quota_1 > 1) eff_q1 = quota_1 - 1;
                    else begin eff_q1 = W1; eff_rr_ptr = ID_WIDTH'(2); end
                end
                ID_WIDTH'(2): begin
                    if (quota_2 > 1) eff_q2 = quota_2 - 1;
                    else begin eff_q2 = W2; eff_rr_ptr = ID_WIDTH'(3); end
                end
                ID_WIDTH'(3): begin
                    if (quota_3 > 1) eff_q3 = quota_3 - 1;
                    else begin eff_q3 = W3; eff_rr_ptr = ID_WIDTH'(1); end
                end
                default: ;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Next Candidate Selection Function
    // -------------------------------------------------------------------------
    logic [ID_WIDTH-1:0] next_cand;
    logic                cand_valid;

    always_comb begin
        next_cand  = '0;
        cand_valid = 1'b0;

        // Check M0 priority first (if requesting and not starved)
        if (m0_req && !eff_starvation) begin
            next_cand  = '0;
            cand_valid = 1'b1;
        end else if (has_lower_req) begin
            // WRR evaluation based on eff_rr_ptr and positive eff_quotas
            case (eff_rr_ptr)
                ID_WIDTH'(1): begin
                    if (m1_req && (eff_q1 > 0)) begin next_cand = ID_WIDTH'(1); cand_valid = 1'b1; end
                    else if (m2_req && (eff_q2 > 0)) begin next_cand = ID_WIDTH'(2); cand_valid = 1'b1; end
                    else if (m3_req && (eff_q3 > 0)) begin next_cand = ID_WIDTH'(3); cand_valid = 1'b1; end
                end
                ID_WIDTH'(2): begin
                    if (m2_req && (eff_q2 > 0)) begin next_cand = ID_WIDTH'(2); cand_valid = 1'b1; end
                    else if (m3_req && (eff_q3 > 0)) begin next_cand = ID_WIDTH'(3); cand_valid = 1'b1; end
                    else if (m1_req && (eff_q1 > 0)) begin next_cand = ID_WIDTH'(1); cand_valid = 1'b1; end
                end
                ID_WIDTH'(3): begin
                    if (m3_req && (eff_q3 > 0)) begin next_cand = ID_WIDTH'(3); cand_valid = 1'b1; end
                    else if (m1_req && (eff_q1 > 0)) begin next_cand = ID_WIDTH'(1); cand_valid = 1'b1; end
                    else if (m2_req && (eff_q2 > 0)) begin next_cand = ID_WIDTH'(2); cand_valid = 1'b1; end
                end
                default: ;
            endcase

            // If all quotas exhausted, fall back to simple round-robin
            if (!cand_valid) begin
                case (eff_rr_ptr)
                    ID_WIDTH'(1): begin
                        if (m1_req) begin next_cand = ID_WIDTH'(1); cand_valid = 1'b1; end
                        else if (m2_req) begin next_cand = ID_WIDTH'(2); cand_valid = 1'b1; end
                        else if (m3_req) begin next_cand = ID_WIDTH'(3); cand_valid = 1'b1; end
                    end
                    ID_WIDTH'(2): begin
                        if (m2_req) begin next_cand = ID_WIDTH'(2); cand_valid = 1'b1; end
                        else if (m3_req) begin next_cand = ID_WIDTH'(3); cand_valid = 1'b1; end
                        else if (m1_req) begin next_cand = ID_WIDTH'(1); cand_valid = 1'b1; end
                    end
                    ID_WIDTH'(3): begin
                        if (m3_req) begin next_cand = ID_WIDTH'(3); cand_valid = 1'b1; end
                        else if (m1_req) begin next_cand = ID_WIDTH'(1); cand_valid = 1'b1; end
                        else if (m2_req) begin next_cand = ID_WIDTH'(2); cand_valid = 1'b1; end
                    end
                    default: ;
                endcase
            end
        end else if (m0_req) begin
            next_cand  = '0;
            cand_valid = 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    // Sequential State & Quota Management
    // -------------------------------------------------------------------------
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            current_master   <= '0;
            is_active        <= 1'b0;
            rr_ptr           <= ID_WIDTH'(1);
            age_counter      <= 0;
            starvation_flag  <= 1'b0;

            quota_1          <= W1;
            quota_2          <= W2;
            quota_3          <= W3;
        end else begin
            // --- Aging Timer Logic ---
            if (m0_req && has_lower_req && (current_master == 0 || !is_active)) begin
                if (age_counter < AGE_THRESHOLD) begin
                    age_counter <= age_counter + 1;
                end
            end else if (!m0_req || !has_lower_req) begin
                if (!starvation_flag) begin
                    age_counter <= 0;
                end
            end

            // Starvation threshold
            if (age_counter >= AGE_THRESHOLD) begin
                starvation_flag <= 1'b1;
            end

            // --- State Transition & Quota Update ---
            if (is_active) begin
                if (transaction_complete || !req[current_master]) begin
                    if (transaction_complete) begin
                        quota_1 <= eff_q1;
                        quota_2 <= eff_q2;
                        quota_3 <= eff_q3;
                        rr_ptr  <= eff_rr_ptr;

                        if (current_master != 0) begin
                            age_counter     <= 0;
                            starvation_flag <= 1'b0;
                        end
                    end

                    // Transition to next candidate if available, else idle
                    if (cand_valid) begin
                        current_master <= next_cand;
                        is_active      <= 1'b1;
                    end else begin
                        is_active      <= 1'b0;
                    end
                end
            end else begin
                // Transition from IDLE
                if (cand_valid) begin
                    current_master <= next_cand;
                    is_active      <= 1'b1;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Output Generation
    // -------------------------------------------------------------------------
    always_comb begin
        grant       = '0;
        master_id   = '0;
        grant_valid = 1'b0;

        if (is_active && req[current_master]) begin
            grant[current_master] = 1'b1;
            master_id             = current_master;
            grant_valid           = 1'b1;
        end else if (cand_valid) begin
            grant[next_cand]      = 1'b1;
            master_id             = next_cand;
            grant_valid           = 1'b1;
        end
    end

`ifdef ASSERTIONS
    // SVA Assertions
    property p_grant_onehot0;
        @(posedge aclk) disable iff (!aresetn)
        $onehot0(grant);
    endproperty
    assert property (p_grant_onehot0)
        else $error("[qos_arbiter] Multiple masters granted simultaneously!");

    property p_grant_implies_req;
        @(posedge aclk) disable iff (!aresetn)
        grant_valid |-> (req[master_id]);
    endproperty
    assert property (p_grant_implies_req)
        else $error("[qos_arbiter] Grant given to non-requesting master!");
`endif

endmodule
