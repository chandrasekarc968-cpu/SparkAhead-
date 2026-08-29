// =============================================================================
// File       : age_counter.sv
// Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
// Description: An 8-bit saturating age counter to prevent starvation.
//              Increments every cycle a master has a pending request but is
//              not currently being served. Resets when served or unrequested.
// =============================================================================

`timescale 1ns / 1ps

module age_counter (
    input  logic       aclk,
    input  logic       aresetn, // Synchronous active-low reset
    input  logic       req,
    input  logic       is_active,
    output logic [7:0] age
);

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            age <= 8'd0;
        end else begin
            if (req && !is_active) begin
                if (age < 8'hFF) begin
                    age <= age + 8'd1;
                end
            end else if (!req || is_active) begin
                age <= 8'd0;
            end
        end
    end

endmodule
