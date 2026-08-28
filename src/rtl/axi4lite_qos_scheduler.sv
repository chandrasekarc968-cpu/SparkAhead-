// =============================================================================
// File       : axi4lite_qos_scheduler.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: Dynamic QoS Weighted Round-Robin Arbiter with:
//              - Runtime-configurable 4-bit weights (clamped: 0→1)
//              - Master 0 preemptive priority (arbitration-boundary only)
//              - Master 0 consecutive burst limiting (saturating counter)
//              - Per-master anti-starvation aging (saturating counters)
//              - Budget-based WRR with deterministic round boundaries
//              - Zero dead-cycle back-to-back scheduling
//
// Weight Clamping: A weight of 0 is internally treated as 1. Valid range: 1–15.
//
// Budget-Based WRR Algorithm:
//   Each master M1–M3 maintains a budget counter initialized to its weight.
//   On each grant, the budget decrements by 1. When the budget reaches 0,
//   it reloads to the weight value and the round-robin pointer advances.
//   A new round begins when the pointer wraps or all budgets are exhausted.
//
// Master 0 Priority ("Preemption"):
//   Master 0 may win arbitration whenever cfg_master0_priority is asserted
//   and M0 has a pending request, UNLESS:
//     (a) The M0 burst counter has reached cfg_master0_burst_limit, OR
//     (b) Any lower-priority master has aged to cfg_age_threshold.
//   "Preemption" means priority at the arbitration decision boundary.
//   M0 can NEVER interrupt an in-flight AXI transaction.
//
// Anti-Starvation Aging:
//   Each master M1–M3 has an 8-bit saturating age counter that increments
//   every cycle the master has a pending request but is not granted.
//   When age >= cfg_age_threshold, that master is promoted above normal WRR
//   and M0 priority. Ties among aged masters are broken by the RR pointer.
//   The age counter resets to 0 after a grant.
// =============================================================================

`timescale 1ns / 1ps

module axi4lite_qos_scheduler #(
    parameter int NUM_MASTERS = 4
) (
    input  logic                                aclk,
    input  logic                                aresetn,

    // --- Runtime QoS Configuration ---
    input  logic [3:0]                          cfg_weight_m0,
    input  logic [3:0]                          cfg_weight_m1,
    input  logic [3:0]                          cfg_weight_m2,
    input  logic [3:0]                          cfg_weight_m3,
    input  logic                                cfg_master0_priority,
    input  logic [7:0]                          cfg_age_threshold,
    input  logic [7:0]                          cfg_master0_burst_limit,

    // --- Arbiter Interface ---
    input  logic [NUM_MASTERS-1:0]              req,
    input  logic                                transaction_complete,

    output logic [NUM_MASTERS-1:0]              grant,
    output logic [$clog2(NUM_MASTERS)-1:0]      master_id,
    output logic                                grant_valid,
    output logic                                starvation_flag
);

    localparam int ID_W = $clog2(NUM_MASTERS);  // 2 bits for 4 masters

    // =========================================================================
    // 1. Weight Clamping (zero → 1)
    // =========================================================================
    logic [3:0] w0, w1, w2, w3;
    always_comb begin
        w0 = (cfg_weight_m0 == 4'd0) ? 4'd1 : cfg_weight_m0;
        w1 = (cfg_weight_m1 == 4'd0) ? 4'd1 : cfg_weight_m1;
        w2 = (cfg_weight_m2 == 4'd0) ? 4'd1 : cfg_weight_m2;
        w3 = (cfg_weight_m3 == 4'd0) ? 4'd1 : cfg_weight_m3;
    end

    // Clamp age threshold and burst limit (0 → 1)
    logic [7:0] age_thresh;
    logic [7:0] burst_limit;
    always_comb begin
        age_thresh  = (cfg_age_threshold == 8'd0) ? 8'd1 : cfg_age_threshold;
        burst_limit = (cfg_master0_burst_limit == 8'd0) ? 8'd1 : cfg_master0_burst_limit;
    end

    // =========================================================================
    // 2. Internal State
    // =========================================================================

    // Per-master request aliases
    logic m0_req, m1_req, m2_req, m3_req;
    assign m0_req = req[0];
    assign m1_req = (NUM_MASTERS > 1) ? req[1] : 1'b0;
    assign m2_req = (NUM_MASTERS > 2) ? req[2] : 1'b0;
    assign m3_req = (NUM_MASTERS > 3) ? req[3] : 1'b0;

    logic has_lower_req;
    assign has_lower_req = m1_req | m2_req | m3_req;

    // Active transaction tracking
    logic [ID_W-1:0]  current_master;
    logic              is_active;

    // WRR budget counters for M1–M3
    logic [3:0] budget_1, budget_2, budget_3;
    // Round-robin pointer (ranges over M1=1, M2=2, M3=3)
    logic [ID_W-1:0] rr_ptr;

    // Per-master aging counters (8-bit, saturating)
    logic [7:0] age_m1, age_m2, age_m3;

    // Master 0 consecutive burst counter (8-bit, saturating)
    logic [7:0] m0_burst_count;

    // =========================================================================
    // 3. Aging Status
    // =========================================================================
    logic m1_aged, m2_aged, m3_aged;
    logic any_aged;

    always_comb begin
        m1_aged = (age_m1 >= age_thresh) && m1_req;
        m2_aged = (age_m2 >= age_thresh) && m2_req;
        m3_aged = (age_m3 >= age_thresh) && m3_req;
        any_aged = m1_aged | m2_aged | m3_aged;
    end

    assign starvation_flag = any_aged;

    // =========================================================================
    // 4. M0 Burst Limit Check
    // =========================================================================
    logic m0_burst_exhausted;
    assign m0_burst_exhausted = (m0_burst_count >= burst_limit);

    // =========================================================================
    // 5. Effective State for Next Decision (Combinational)
    // =========================================================================
    // When the current transaction completes, update budgets and RR pointer
    // for the next decision cycle.
    logic [3:0]       eff_b1, eff_b2, eff_b3;
    logic [ID_W-1:0]  eff_rr_ptr;

    always_comb begin
        eff_b1     = budget_1;
        eff_b2     = budget_2;
        eff_b3     = budget_3;
        eff_rr_ptr = rr_ptr;

        if (is_active && transaction_complete) begin
            case (current_master)
                ID_W'(1): begin
                    if (budget_1 > 4'd1) begin
                        eff_b1 = budget_1 - 4'd1;
                    end else begin
                        eff_b1     = w1;
                        eff_rr_ptr = ID_W'(2);
                    end
                end
                ID_W'(2): begin
                    if (budget_2 > 4'd1) begin
                        eff_b2 = budget_2 - 4'd1;
                    end else begin
                        eff_b2     = w2;
                        eff_rr_ptr = ID_W'(3);
                    end
                end
                ID_W'(3): begin
                    if (budget_3 > 4'd1) begin
                        eff_b3 = budget_3 - 4'd1;
                    end else begin
                        eff_b3     = w3;
                        eff_rr_ptr = ID_W'(1);
                    end
                end
                default: ;
            endcase
        end
    end

    // =========================================================================
    // 6. Next Candidate Selection (Combinational)
    // =========================================================================
    logic [ID_W-1:0] next_cand;
    logic             cand_valid;

    always_comb begin
        next_cand  = '0;
        cand_valid = 1'b0;

        // --- Priority 1: Anti-starvation override ---
        // Aged masters get highest priority. Tie-break by RR pointer.
        if (any_aged) begin
            case (eff_rr_ptr)
                ID_W'(1): begin
                    if (m1_aged)      begin next_cand = ID_W'(1); cand_valid = 1'b1; end
                    else if (m2_aged) begin next_cand = ID_W'(2); cand_valid = 1'b1; end
                    else if (m3_aged) begin next_cand = ID_W'(3); cand_valid = 1'b1; end
                end
                ID_W'(2): begin
                    if (m2_aged)      begin next_cand = ID_W'(2); cand_valid = 1'b1; end
                    else if (m3_aged) begin next_cand = ID_W'(3); cand_valid = 1'b1; end
                    else if (m1_aged) begin next_cand = ID_W'(1); cand_valid = 1'b1; end
                end
                ID_W'(3): begin
                    if (m3_aged)      begin next_cand = ID_W'(3); cand_valid = 1'b1; end
                    else if (m1_aged) begin next_cand = ID_W'(1); cand_valid = 1'b1; end
                    else if (m2_aged) begin next_cand = ID_W'(2); cand_valid = 1'b1; end
                end
                default: begin
                    if (m1_aged)      begin next_cand = ID_W'(1); cand_valid = 1'b1; end
                    else if (m2_aged) begin next_cand = ID_W'(2); cand_valid = 1'b1; end
                    else if (m3_aged) begin next_cand = ID_W'(3); cand_valid = 1'b1; end
                end
            endcase
        end

        // --- Priority 2: Master 0 preemptive priority ---
        else if (m0_req && cfg_master0_priority && !m0_burst_exhausted) begin
            next_cand  = '0;
            cand_valid = 1'b1;
        end

        // --- Priority 3: WRR among M1–M3 ---
        else if (has_lower_req) begin
            // Try budget-based WRR first
            case (eff_rr_ptr)
                ID_W'(1): begin
                    if (m1_req && (eff_b1 > 4'd0)) begin next_cand = ID_W'(1); cand_valid = 1'b1; end
                    else if (m2_req && (eff_b2 > 4'd0)) begin next_cand = ID_W'(2); cand_valid = 1'b1; end
                    else if (m3_req && (eff_b3 > 4'd0)) begin next_cand = ID_W'(3); cand_valid = 1'b1; end
                end
                ID_W'(2): begin
                    if (m2_req && (eff_b2 > 4'd0)) begin next_cand = ID_W'(2); cand_valid = 1'b1; end
                    else if (m3_req && (eff_b3 > 4'd0)) begin next_cand = ID_W'(3); cand_valid = 1'b1; end
                    else if (m1_req && (eff_b1 > 4'd0)) begin next_cand = ID_W'(1); cand_valid = 1'b1; end
                end
                ID_W'(3): begin
                    if (m3_req && (eff_b3 > 4'd0)) begin next_cand = ID_W'(3); cand_valid = 1'b1; end
                    else if (m1_req && (eff_b1 > 4'd0)) begin next_cand = ID_W'(1); cand_valid = 1'b1; end
                    else if (m2_req && (eff_b2 > 4'd0)) begin next_cand = ID_W'(2); cand_valid = 1'b1; end
                end
                default: begin
                    if (m1_req && (eff_b1 > 4'd0)) begin next_cand = ID_W'(1); cand_valid = 1'b1; end
                    else if (m2_req && (eff_b2 > 4'd0)) begin next_cand = ID_W'(2); cand_valid = 1'b1; end
                    else if (m3_req && (eff_b3 > 4'd0)) begin next_cand = ID_W'(3); cand_valid = 1'b1; end
                end
            endcase

            // Fallback: all budgets exhausted — reload and try simple RR
            if (!cand_valid) begin
                case (eff_rr_ptr)
                    ID_W'(1): begin
                        if (m1_req) begin next_cand = ID_W'(1); cand_valid = 1'b1; end
                        else if (m2_req) begin next_cand = ID_W'(2); cand_valid = 1'b1; end
                        else if (m3_req) begin next_cand = ID_W'(3); cand_valid = 1'b1; end
                    end
                    ID_W'(2): begin
                        if (m2_req) begin next_cand = ID_W'(2); cand_valid = 1'b1; end
                        else if (m3_req) begin next_cand = ID_W'(3); cand_valid = 1'b1; end
                        else if (m1_req) begin next_cand = ID_W'(1); cand_valid = 1'b1; end
                    end
                    ID_W'(3): begin
                        if (m3_req) begin next_cand = ID_W'(3); cand_valid = 1'b1; end
                        else if (m1_req) begin next_cand = ID_W'(1); cand_valid = 1'b1; end
                        else if (m2_req) begin next_cand = ID_W'(2); cand_valid = 1'b1; end
                    end
                    default: begin
                        if (m1_req) begin next_cand = ID_W'(1); cand_valid = 1'b1; end
                        else if (m2_req) begin next_cand = ID_W'(2); cand_valid = 1'b1; end
                        else if (m3_req) begin next_cand = ID_W'(3); cand_valid = 1'b1; end
                    end
                endcase
            end
        end

        // --- Priority 4: M0 without priority flag or after burst exhaustion ---
        else if (m0_req) begin
            next_cand  = '0;
            cand_valid = 1'b1;
        end
    end

    // =========================================================================
    // 7. Sequential State & Budget Management
    // =========================================================================
    logic f_first_cycle;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            current_master   <= '0;
            is_active        <= 1'b0;
            rr_ptr           <= ID_W'(1);
            budget_1         <= 4'd1;  // Safe constant; reloaded on first active cycle
            budget_2         <= 4'd1;
            budget_3         <= 4'd1;
            age_m1           <= 8'd0;
            age_m2           <= 8'd0;
            age_m3           <= 8'd0;
            m0_burst_count   <= 8'd0;
            f_first_cycle    <= 1'b1;
        end else begin

            // B5 fix: reload budgets from clamped weights on first cycle after reset
            if (f_first_cycle) begin
                budget_1      <= w1;
                budget_2      <= w2;
                budget_3      <= w3;
                f_first_cycle <= 1'b0;
            end

            // -----------------------------------------------------------------
            // Aging Timer Logic: increment for waiting, unrequested masters
            // Saturate at 8'hFF to avoid wrap-around.
            // -----------------------------------------------------------------
            if (m1_req && !(is_active && current_master == ID_W'(1)))
                age_m1 <= (age_m1 < 8'hFF) ? age_m1 + 8'd1 : 8'hFF;
            else if (!m1_req)
                age_m1 <= 8'd0;

            if (m2_req && !(is_active && current_master == ID_W'(2)))
                age_m2 <= (age_m2 < 8'hFF) ? age_m2 + 8'd1 : 8'hFF;
            else if (!m2_req)
                age_m2 <= 8'd0;

            if (m3_req && !(is_active && current_master == ID_W'(3)))
                age_m3 <= (age_m3 < 8'hFF) ? age_m3 + 8'd1 : 8'hFF;
            else if (!m3_req)
                age_m3 <= 8'd0;

            // -----------------------------------------------------------------
            // State Transitions
            // -----------------------------------------------------------------
            if (is_active) begin
                if (transaction_complete) begin
                    // Update WRR state
                    budget_1 <= eff_b1;
                    budget_2 <= eff_b2;
                    budget_3 <= eff_b3;
                    rr_ptr   <= eff_rr_ptr;

                    // Reset age for the completing master
                    case (current_master)
                        ID_W'(1): age_m1 <= 8'd0;
                        ID_W'(2): age_m2 <= 8'd0;
                        ID_W'(3): age_m3 <= 8'd0;
                        default: ;
                    endcase

                    // Update M0 burst counter
                    if (current_master == '0) begin
                        // M0 just finished; check if next is also M0
                        if (cand_valid && next_cand == '0) begin
                            m0_burst_count <= (m0_burst_count < 8'hFF) ?
                                              m0_burst_count + 8'd1 : 8'hFF;
                        end
                        // If next is not M0, counter will be reset below
                    end else begin
                        // Non-M0 just finished; reset M0 burst counter
                        m0_burst_count <= 8'd0;
                    end

                    // Transition to next candidate if available
                    if (cand_valid) begin
                        current_master <= next_cand;
                        is_active      <= 1'b1;
                        // If transitioning to non-M0 from M0, reset burst count
                        if (current_master == '0 && next_cand != '0)
                            m0_burst_count <= 8'd0;
                    end else begin
                        is_active <= 1'b0;
                    end
                end
            end else begin
                // IDLE → grant first candidate
                if (cand_valid) begin
                    current_master <= next_cand;
                    is_active      <= 1'b1;
                    // Start M0 burst count if M0 is first
                    if (next_cand == '0)
                        m0_burst_count <= 8'd1;
                    else
                        m0_burst_count <= 8'd0;
                end
            end
        end
    end

    // =========================================================================
    // 8. Output Generation
    // =========================================================================
    always_comb begin
        grant       = '0;
        master_id   = '0;
        grant_valid = 1'b0;

        if (is_active) begin
            grant[current_master] = 1'b1;
            master_id             = current_master;
            grant_valid           = 1'b1;
        end else if (cand_valid) begin
            grant[next_cand]      = 1'b1;
            master_id             = next_cand;
            grant_valid           = 1'b1;
        end
    end

    // =========================================================================
    // 9. Synthesis-Safe Assertions
    // =========================================================================
`ifdef ASSERTIONS
    property p_grant_onehot0;
        @(posedge aclk) disable iff (!aresetn)
        $onehot0(grant);
    endproperty
    assert property (p_grant_onehot0)
        else $error("[axi4lite_qos_scheduler] Multiple masters granted simultaneously!");

    property p_active_implies_grant;
        @(posedge aclk) disable iff (!aresetn)
        is_active |-> grant_valid;
    endproperty
    assert property (p_active_implies_grant)
        else $error("[axi4lite_qos_scheduler] Active without grant_valid!");

    property p_owner_stable_when_active;
        @(posedge aclk) disable iff (!aresetn)
        (is_active && !transaction_complete) |=> (current_master == $past(current_master));
    endproperty
    assert property (p_owner_stable_when_active)
        else $error("[axi4lite_qos_scheduler] Owner changed while active without tx_complete!");
`endif

endmodule
