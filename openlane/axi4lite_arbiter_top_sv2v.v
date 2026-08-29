module axi4lite_address_decoder (
	addr,
	slave_sel,
	valid_addr,
	invalid_addr
);
	parameter signed [31:0] ADDR_WIDTH = 32;
	parameter [ADDR_WIDTH - 1:0] S0_BASE = 32'h00000000;
	parameter [ADDR_WIDTH - 1:0] S0_SIZE = 32'h00010000;
	parameter [ADDR_WIDTH - 1:0] S1_BASE = 32'h00010000;
	parameter [ADDR_WIDTH - 1:0] S1_SIZE = 32'h00010000;
	input wire [ADDR_WIDTH - 1:0] addr;
	output reg [1:0] slave_sel;
	output reg valid_addr;
	output reg invalid_addr;
	reg match_s0;
	reg match_s1;
	function automatic [63:0] sv2v_cast_64;
		input reg [63:0] inp;
		sv2v_cast_64 = inp;
	endfunction
	always @(*) begin
		if (((S0_SIZE > 0) && (sv2v_cast_64(addr) >= sv2v_cast_64(S0_BASE))) && (sv2v_cast_64(addr) < (sv2v_cast_64(S0_BASE) + sv2v_cast_64(S0_SIZE))))
			match_s0 = 1'b1;
		else
			match_s0 = 1'b0;
		if (((S1_SIZE > 0) && (sv2v_cast_64(addr) >= sv2v_cast_64(S1_BASE))) && (sv2v_cast_64(addr) < (sv2v_cast_64(S1_BASE) + sv2v_cast_64(S1_SIZE))))
			match_s1 = 1'b1;
		else
			match_s1 = 1'b0;
		if (match_s0) begin
			slave_sel = 2'b01;
			valid_addr = 1'b1;
			invalid_addr = 1'b0;
		end
		else if (match_s1) begin
			slave_sel = 2'b10;
			valid_addr = 1'b1;
			invalid_addr = 1'b0;
		end
		else begin
			slave_sel = 2'b00;
			valid_addr = 1'b0;
			invalid_addr = 1'b1;
		end
	end
endmodule
module axi4lite_qos_scheduler (
	aclk,
	aresetn,
	cfg_weight_m0,
	cfg_weight_m1,
	cfg_weight_m2,
	cfg_weight_m3,
	cfg_master0_priority,
	cfg_age_threshold,
	cfg_master0_burst_limit,
	req,
	transaction_complete,
	grant,
	master_id,
	grant_valid,
	starvation_flag
);
	parameter signed [31:0] NUM_MASTERS = 4;
	input wire aclk;
	input wire aresetn;
	input wire [3:0] cfg_weight_m0;
	input wire [3:0] cfg_weight_m1;
	input wire [3:0] cfg_weight_m2;
	input wire [3:0] cfg_weight_m3;
	input wire cfg_master0_priority;
	input wire [7:0] cfg_age_threshold;
	input wire [7:0] cfg_master0_burst_limit;
	input wire [NUM_MASTERS - 1:0] req;
	input wire transaction_complete;
	output reg [NUM_MASTERS - 1:0] grant;
	output reg [$clog2(NUM_MASTERS) - 1:0] master_id;
	output reg grant_valid;
	output wire starvation_flag;
	localparam signed [31:0] ID_W = $clog2(NUM_MASTERS);
	reg [3:0] w0;
	reg [3:0] w1;
	reg [3:0] w2;
	reg [3:0] w3;
	always @(*) begin
		w0 = (cfg_weight_m0 == 4'd0 ? 4'd1 : cfg_weight_m0);
		w1 = (cfg_weight_m1 == 4'd0 ? 4'd1 : cfg_weight_m1);
		w2 = (cfg_weight_m2 == 4'd0 ? 4'd1 : cfg_weight_m2);
		w3 = (cfg_weight_m3 == 4'd0 ? 4'd1 : cfg_weight_m3);
	end
	reg [7:0] age_thresh;
	reg [7:0] burst_limit;
	always @(*) begin
		age_thresh = (cfg_age_threshold == 8'd0 ? 8'd1 : cfg_age_threshold);
		burst_limit = (cfg_master0_burst_limit == 8'd0 ? 8'd1 : cfg_master0_burst_limit);
	end
	wire m0_req;
	wire m1_req;
	wire m2_req;
	wire m3_req;
	assign m0_req = req[0];
	assign m1_req = (NUM_MASTERS > 1 ? req[1] : 1'b0);
	assign m2_req = (NUM_MASTERS > 2 ? req[2] : 1'b0);
	assign m3_req = (NUM_MASTERS > 3 ? req[3] : 1'b0);
	wire has_lower_req;
	assign has_lower_req = (m1_req | m2_req) | m3_req;
	reg [ID_W - 1:0] current_master;
	reg is_active;
	reg [3:0] budget_1;
	reg [3:0] budget_2;
	reg [3:0] budget_3;
	reg [ID_W - 1:0] rr_ptr;
	reg [7:0] age_m1;
	reg [7:0] age_m2;
	reg [7:0] age_m3;
	reg [7:0] m0_burst_count;
	reg m1_aged;
	reg m2_aged;
	reg m3_aged;
	reg any_aged;
	always @(*) begin
		m1_aged = (age_m1 >= age_thresh) && m1_req;
		m2_aged = (age_m2 >= age_thresh) && m2_req;
		m3_aged = (age_m3 >= age_thresh) && m3_req;
		any_aged = (m1_aged | m2_aged) | m3_aged;
	end
	assign starvation_flag = any_aged;
	wire m0_burst_exhausted;
	assign m0_burst_exhausted = m0_burst_count >= burst_limit;
	reg [3:0] eff_b1;
	reg [3:0] eff_b2;
	reg [3:0] eff_b3;
	reg [ID_W - 1:0] eff_rr_ptr;
	function automatic signed [ID_W - 1:0] sv2v_cast_1F7B3_signed;
		input reg signed [ID_W - 1:0] inp;
		sv2v_cast_1F7B3_signed = inp;
	endfunction
	always @(*) begin
		eff_b1 = budget_1;
		eff_b2 = budget_2;
		eff_b3 = budget_3;
		eff_rr_ptr = rr_ptr;
		if (is_active && transaction_complete)
			case (current_master)
				sv2v_cast_1F7B3_signed(1):
					if (budget_1 > 4'd1)
						eff_b1 = budget_1 - 4'd1;
					else begin
						eff_b1 = w1;
						eff_rr_ptr = sv2v_cast_1F7B3_signed(2);
					end
				sv2v_cast_1F7B3_signed(2):
					if (budget_2 > 4'd1)
						eff_b2 = budget_2 - 4'd1;
					else begin
						eff_b2 = w2;
						eff_rr_ptr = sv2v_cast_1F7B3_signed(3);
					end
				sv2v_cast_1F7B3_signed(3):
					if (budget_3 > 4'd1)
						eff_b3 = budget_3 - 4'd1;
					else begin
						eff_b3 = w3;
						eff_rr_ptr = sv2v_cast_1F7B3_signed(1);
					end
				default:
					;
			endcase
	end
	reg [ID_W - 1:0] next_cand;
	reg cand_valid;
	always @(*) begin
		next_cand = 1'sb0;
		cand_valid = 1'b0;
		if (any_aged)
			case (eff_rr_ptr)
				sv2v_cast_1F7B3_signed(1):
					if (m1_aged) begin
						next_cand = sv2v_cast_1F7B3_signed(1);
						cand_valid = 1'b1;
					end
					else if (m2_aged) begin
						next_cand = sv2v_cast_1F7B3_signed(2);
						cand_valid = 1'b1;
					end
					else if (m3_aged) begin
						next_cand = sv2v_cast_1F7B3_signed(3);
						cand_valid = 1'b1;
					end
				sv2v_cast_1F7B3_signed(2):
					if (m2_aged) begin
						next_cand = sv2v_cast_1F7B3_signed(2);
						cand_valid = 1'b1;
					end
					else if (m3_aged) begin
						next_cand = sv2v_cast_1F7B3_signed(3);
						cand_valid = 1'b1;
					end
					else if (m1_aged) begin
						next_cand = sv2v_cast_1F7B3_signed(1);
						cand_valid = 1'b1;
					end
				sv2v_cast_1F7B3_signed(3):
					if (m3_aged) begin
						next_cand = sv2v_cast_1F7B3_signed(3);
						cand_valid = 1'b1;
					end
					else if (m1_aged) begin
						next_cand = sv2v_cast_1F7B3_signed(1);
						cand_valid = 1'b1;
					end
					else if (m2_aged) begin
						next_cand = sv2v_cast_1F7B3_signed(2);
						cand_valid = 1'b1;
					end
				default:
					if (m1_aged) begin
						next_cand = sv2v_cast_1F7B3_signed(1);
						cand_valid = 1'b1;
					end
					else if (m2_aged) begin
						next_cand = sv2v_cast_1F7B3_signed(2);
						cand_valid = 1'b1;
					end
					else if (m3_aged) begin
						next_cand = sv2v_cast_1F7B3_signed(3);
						cand_valid = 1'b1;
					end
			endcase
		else if ((m0_req && cfg_master0_priority) && !m0_burst_exhausted) begin
			next_cand = 1'sb0;
			cand_valid = 1'b1;
		end
		else if (has_lower_req) begin
			case (eff_rr_ptr)
				sv2v_cast_1F7B3_signed(1):
					if (m1_req && (eff_b1 > 4'd0)) begin
						next_cand = sv2v_cast_1F7B3_signed(1);
						cand_valid = 1'b1;
					end
					else if (m2_req && (eff_b2 > 4'd0)) begin
						next_cand = sv2v_cast_1F7B3_signed(2);
						cand_valid = 1'b1;
					end
					else if (m3_req && (eff_b3 > 4'd0)) begin
						next_cand = sv2v_cast_1F7B3_signed(3);
						cand_valid = 1'b1;
					end
				sv2v_cast_1F7B3_signed(2):
					if (m2_req && (eff_b2 > 4'd0)) begin
						next_cand = sv2v_cast_1F7B3_signed(2);
						cand_valid = 1'b1;
					end
					else if (m3_req && (eff_b3 > 4'd0)) begin
						next_cand = sv2v_cast_1F7B3_signed(3);
						cand_valid = 1'b1;
					end
					else if (m1_req && (eff_b1 > 4'd0)) begin
						next_cand = sv2v_cast_1F7B3_signed(1);
						cand_valid = 1'b1;
					end
				sv2v_cast_1F7B3_signed(3):
					if (m3_req && (eff_b3 > 4'd0)) begin
						next_cand = sv2v_cast_1F7B3_signed(3);
						cand_valid = 1'b1;
					end
					else if (m1_req && (eff_b1 > 4'd0)) begin
						next_cand = sv2v_cast_1F7B3_signed(1);
						cand_valid = 1'b1;
					end
					else if (m2_req && (eff_b2 > 4'd0)) begin
						next_cand = sv2v_cast_1F7B3_signed(2);
						cand_valid = 1'b1;
					end
				default:
					if (m1_req && (eff_b1 > 4'd0)) begin
						next_cand = sv2v_cast_1F7B3_signed(1);
						cand_valid = 1'b1;
					end
					else if (m2_req && (eff_b2 > 4'd0)) begin
						next_cand = sv2v_cast_1F7B3_signed(2);
						cand_valid = 1'b1;
					end
					else if (m3_req && (eff_b3 > 4'd0)) begin
						next_cand = sv2v_cast_1F7B3_signed(3);
						cand_valid = 1'b1;
					end
			endcase
			if (!cand_valid)
				case (eff_rr_ptr)
					sv2v_cast_1F7B3_signed(1):
						if (m1_req) begin
							next_cand = sv2v_cast_1F7B3_signed(1);
							cand_valid = 1'b1;
						end
						else if (m2_req) begin
							next_cand = sv2v_cast_1F7B3_signed(2);
							cand_valid = 1'b1;
						end
						else if (m3_req) begin
							next_cand = sv2v_cast_1F7B3_signed(3);
							cand_valid = 1'b1;
						end
					sv2v_cast_1F7B3_signed(2):
						if (m2_req) begin
							next_cand = sv2v_cast_1F7B3_signed(2);
							cand_valid = 1'b1;
						end
						else if (m3_req) begin
							next_cand = sv2v_cast_1F7B3_signed(3);
							cand_valid = 1'b1;
						end
						else if (m1_req) begin
							next_cand = sv2v_cast_1F7B3_signed(1);
							cand_valid = 1'b1;
						end
					sv2v_cast_1F7B3_signed(3):
						if (m3_req) begin
							next_cand = sv2v_cast_1F7B3_signed(3);
							cand_valid = 1'b1;
						end
						else if (m1_req) begin
							next_cand = sv2v_cast_1F7B3_signed(1);
							cand_valid = 1'b1;
						end
						else if (m2_req) begin
							next_cand = sv2v_cast_1F7B3_signed(2);
							cand_valid = 1'b1;
						end
					default:
						if (m1_req) begin
							next_cand = sv2v_cast_1F7B3_signed(1);
							cand_valid = 1'b1;
						end
						else if (m2_req) begin
							next_cand = sv2v_cast_1F7B3_signed(2);
							cand_valid = 1'b1;
						end
						else if (m3_req) begin
							next_cand = sv2v_cast_1F7B3_signed(3);
							cand_valid = 1'b1;
						end
				endcase
		end
		else if (m0_req) begin
			next_cand = 1'sb0;
			cand_valid = 1'b1;
		end
	end
	reg f_first_cycle;
	always @(posedge aclk or negedge aresetn)
		if (!aresetn) begin
			current_master <= 1'sb0;
			is_active <= 1'b0;
			rr_ptr <= sv2v_cast_1F7B3_signed(1);
			budget_1 <= 4'd1;
			budget_2 <= 4'd1;
			budget_3 <= 4'd1;
			age_m1 <= 8'd0;
			age_m2 <= 8'd0;
			age_m3 <= 8'd0;
			m0_burst_count <= 8'd0;
			f_first_cycle <= 1'b1;
		end
		else begin
			if (f_first_cycle) begin
				budget_1 <= w1;
				budget_2 <= w2;
				budget_3 <= w3;
				f_first_cycle <= 1'b0;
			end
			if (m1_req && !(is_active && (current_master == sv2v_cast_1F7B3_signed(1))))
				age_m1 <= (age_m1 < 8'hff ? age_m1 + 8'd1 : 8'hff);
			else if (!m1_req)
				age_m1 <= 8'd0;
			if (m2_req && !(is_active && (current_master == sv2v_cast_1F7B3_signed(2))))
				age_m2 <= (age_m2 < 8'hff ? age_m2 + 8'd1 : 8'hff);
			else if (!m2_req)
				age_m2 <= 8'd0;
			if (m3_req && !(is_active && (current_master == sv2v_cast_1F7B3_signed(3))))
				age_m3 <= (age_m3 < 8'hff ? age_m3 + 8'd1 : 8'hff);
			else if (!m3_req)
				age_m3 <= 8'd0;
			if (is_active) begin
				if (transaction_complete) begin
					budget_1 <= eff_b1;
					budget_2 <= eff_b2;
					budget_3 <= eff_b3;
					rr_ptr <= eff_rr_ptr;
					case (current_master)
						sv2v_cast_1F7B3_signed(1): age_m1 <= 8'd0;
						sv2v_cast_1F7B3_signed(2): age_m2 <= 8'd0;
						sv2v_cast_1F7B3_signed(3): age_m3 <= 8'd0;
						default:
							;
					endcase
					if (current_master == {ID_W {1'sb0}}) begin
						if (cand_valid && (next_cand == {ID_W {1'sb0}}))
							m0_burst_count <= (m0_burst_count < 8'hff ? m0_burst_count + 8'd1 : 8'hff);
					end
					else
						m0_burst_count <= 8'd0;
					if (cand_valid) begin
						current_master <= next_cand;
						is_active <= 1'b1;
						if ((current_master == {ID_W {1'sb0}}) && (next_cand != {ID_W {1'sb0}}))
							m0_burst_count <= 8'd0;
					end
					else
						is_active <= 1'b0;
				end
			end
			else if (cand_valid) begin
				current_master <= next_cand;
				is_active <= 1'b1;
				if (next_cand == {ID_W {1'sb0}})
					m0_burst_count <= 8'd1;
				else
					m0_burst_count <= 8'd0;
			end
		end
	always @(*) begin
		grant = 1'sb0;
		master_id = 1'sb0;
		grant_valid = 1'b0;
		if (is_active) begin
			grant[current_master] = 1'b1;
			master_id = current_master;
			grant_valid = 1'b1;
		end
		else if (cand_valid) begin
			grant[next_cand] = 1'b1;
			master_id = next_cand;
			grant_valid = 1'b1;
		end
	end
endmodule
module axi4lite_response_router (
	w_active,
	w_owner_id,
	w_target_slave,
	w_target_invalid,
	s_bresp,
	s_bvalid,
	s_bready,
	m_bresp,
	m_bvalid,
	m_bready,
	w_resp_handshake,
	w_owner_bready,
	r_active,
	r_owner_id,
	r_target_slave,
	r_target_invalid,
	s_rdata,
	s_rresp,
	s_rvalid,
	s_rready,
	m_rdata,
	m_rresp,
	m_rvalid,
	m_rready,
	r_resp_handshake,
	r_owner_rready
);
	parameter signed [31:0] NUM_MASTERS = 4;
	parameter signed [31:0] NUM_SLAVES = 2;
	parameter signed [31:0] DATA_WIDTH = 32;
	input wire w_active;
	input wire [$clog2(NUM_MASTERS) - 1:0] w_owner_id;
	input wire [NUM_SLAVES - 1:0] w_target_slave;
	input wire w_target_invalid;
	input wire [(NUM_SLAVES * 2) - 1:0] s_bresp;
	input wire [NUM_SLAVES - 1:0] s_bvalid;
	output reg [NUM_SLAVES - 1:0] s_bready;
	output reg [(NUM_MASTERS * 2) - 1:0] m_bresp;
	output reg [NUM_MASTERS - 1:0] m_bvalid;
	input wire [NUM_MASTERS - 1:0] m_bready;
	output reg w_resp_handshake;
	output reg w_owner_bready;
	input wire r_active;
	input wire [$clog2(NUM_MASTERS) - 1:0] r_owner_id;
	input wire [NUM_SLAVES - 1:0] r_target_slave;
	input wire r_target_invalid;
	input wire [(NUM_SLAVES * DATA_WIDTH) - 1:0] s_rdata;
	input wire [(NUM_SLAVES * 2) - 1:0] s_rresp;
	input wire [NUM_SLAVES - 1:0] s_rvalid;
	output reg [NUM_SLAVES - 1:0] s_rready;
	output reg [(NUM_MASTERS * DATA_WIDTH) - 1:0] m_rdata;
	output reg [(NUM_MASTERS * 2) - 1:0] m_rresp;
	output reg [NUM_MASTERS - 1:0] m_rvalid;
	input wire [NUM_MASTERS - 1:0] m_rready;
	output reg r_resp_handshake;
	output reg r_owner_rready;
	localparam [1:0] RESP_DECERR = 2'b11;
	always @(*) begin
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < NUM_MASTERS; i = i + 1)
				begin
					m_bresp[i * 2+:2] = 2'b00;
					m_bvalid[i] = 1'b0;
				end
		end
		begin : sv2v_autoblock_2
			reg signed [31:0] i;
			for (i = 0; i < NUM_SLAVES; i = i + 1)
				s_bready[i] = 1'b0;
		end
		w_resp_handshake = 1'b0;
		w_owner_bready = 1'b0;
		if (w_active) begin
			w_owner_bready = m_bready[w_owner_id];
			if (w_target_invalid) begin
				m_bvalid[w_owner_id] = 1'b1;
				m_bresp[w_owner_id * 2+:2] = RESP_DECERR;
				w_resp_handshake = m_bready[w_owner_id];
			end
			else if (w_target_slave[0]) begin
				m_bvalid[w_owner_id] = s_bvalid[0];
				m_bresp[w_owner_id * 2+:2] = s_bresp[0+:2];
				s_bready[0] = m_bready[w_owner_id];
				w_resp_handshake = s_bvalid[0] && m_bready[w_owner_id];
			end
			else if (w_target_slave[1]) begin
				m_bvalid[w_owner_id] = s_bvalid[1];
				m_bresp[w_owner_id * 2+:2] = s_bresp[2+:2];
				s_bready[1] = m_bready[w_owner_id];
				w_resp_handshake = s_bvalid[1] && m_bready[w_owner_id];
			end
		end
	end
	always @(*) begin
		begin : sv2v_autoblock_3
			reg signed [31:0] i;
			for (i = 0; i < NUM_MASTERS; i = i + 1)
				begin
					m_rdata[i * DATA_WIDTH+:DATA_WIDTH] = 1'sb0;
					m_rresp[i * 2+:2] = 2'b00;
					m_rvalid[i] = 1'b0;
				end
		end
		begin : sv2v_autoblock_4
			reg signed [31:0] i;
			for (i = 0; i < NUM_SLAVES; i = i + 1)
				s_rready[i] = 1'b0;
		end
		r_resp_handshake = 1'b0;
		r_owner_rready = 1'b0;
		if (r_active) begin
			r_owner_rready = m_rready[r_owner_id];
			if (r_target_invalid) begin
				m_rvalid[r_owner_id] = 1'b1;
				m_rdata[r_owner_id * DATA_WIDTH+:DATA_WIDTH] = 1'sb0;
				m_rresp[r_owner_id * 2+:2] = RESP_DECERR;
				r_resp_handshake = m_rready[r_owner_id];
			end
			else if (r_target_slave[0]) begin
				m_rvalid[r_owner_id] = s_rvalid[0];
				m_rdata[r_owner_id * DATA_WIDTH+:DATA_WIDTH] = s_rdata[0+:DATA_WIDTH];
				m_rresp[r_owner_id * 2+:2] = s_rresp[0+:2];
				s_rready[0] = m_rready[r_owner_id];
				r_resp_handshake = s_rvalid[0] && m_rready[r_owner_id];
			end
			else if (r_target_slave[1]) begin
				m_rvalid[r_owner_id] = s_rvalid[1];
				m_rdata[r_owner_id * DATA_WIDTH+:DATA_WIDTH] = s_rdata[DATA_WIDTH+:DATA_WIDTH];
				m_rresp[r_owner_id * 2+:2] = s_rresp[2+:2];
				s_rready[1] = m_rready[r_owner_id];
				r_resp_handshake = s_rvalid[1] && m_rready[r_owner_id];
			end
		end
	end
endmodule
module axi4lite_write_arbiter (
	aclk,
	aresetn,
	cfg_weight_m0,
	cfg_weight_m1,
	cfg_weight_m2,
	cfg_weight_m3,
	cfg_master0_priority,
	cfg_age_threshold,
	cfg_master0_burst_limit,
	s_axi_awaddr,
	s_axi_awprot,
	s_axi_awvalid,
	s_axi_awready,
	s_axi_wdata,
	s_axi_wstrb,
	s_axi_wvalid,
	s_axi_wready,
	w_owner_id,
	w_target_slave,
	w_target_invalid,
	w_resp_phase,
	w_resp_handshake,
	w_owner_bready,
	m_axi_awaddr,
	m_axi_awprot,
	m_axi_awvalid,
	m_axi_awready,
	m_axi_wdata,
	m_axi_wstrb,
	m_axi_wvalid,
	m_axi_wready
);
	parameter signed [31:0] NUM_MASTERS = 4;
	parameter signed [31:0] NUM_SLAVES = 2;
	parameter signed [31:0] ADDR_WIDTH = 32;
	parameter signed [31:0] DATA_WIDTH = 32;
	parameter signed [31:0] STRB_WIDTH = DATA_WIDTH / 8;
	parameter [ADDR_WIDTH - 1:0] S0_BASE = 32'h00000000;
	parameter [ADDR_WIDTH - 1:0] S0_SIZE = 32'h00010000;
	parameter [ADDR_WIDTH - 1:0] S1_BASE = 32'h00010000;
	parameter [ADDR_WIDTH - 1:0] S1_SIZE = 32'h00010000;
	input wire aclk;
	input wire aresetn;
	input wire [3:0] cfg_weight_m0;
	input wire [3:0] cfg_weight_m1;
	input wire [3:0] cfg_weight_m2;
	input wire [3:0] cfg_weight_m3;
	input wire cfg_master0_priority;
	input wire [7:0] cfg_age_threshold;
	input wire [7:0] cfg_master0_burst_limit;
	input wire [(NUM_MASTERS * ADDR_WIDTH) - 1:0] s_axi_awaddr;
	input wire [(NUM_MASTERS * 3) - 1:0] s_axi_awprot;
	input wire [NUM_MASTERS - 1:0] s_axi_awvalid;
	output reg [NUM_MASTERS - 1:0] s_axi_awready;
	input wire [(NUM_MASTERS * DATA_WIDTH) - 1:0] s_axi_wdata;
	input wire [(NUM_MASTERS * STRB_WIDTH) - 1:0] s_axi_wstrb;
	input wire [NUM_MASTERS - 1:0] s_axi_wvalid;
	output reg [NUM_MASTERS - 1:0] s_axi_wready;
	output wire [$clog2(NUM_MASTERS) - 1:0] w_owner_id;
	output wire [NUM_SLAVES - 1:0] w_target_slave;
	output wire w_target_invalid;
	output wire w_resp_phase;
	input wire w_resp_handshake;
	input wire w_owner_bready;
	output reg [(NUM_SLAVES * ADDR_WIDTH) - 1:0] m_axi_awaddr;
	output reg [(NUM_SLAVES * 3) - 1:0] m_axi_awprot;
	output reg [NUM_SLAVES - 1:0] m_axi_awvalid;
	input wire [NUM_SLAVES - 1:0] m_axi_awready;
	output reg [(NUM_SLAVES * DATA_WIDTH) - 1:0] m_axi_wdata;
	output reg [(NUM_SLAVES * STRB_WIDTH) - 1:0] m_axi_wstrb;
	output reg [NUM_SLAVES - 1:0] m_axi_wvalid;
	input wire [NUM_SLAVES - 1:0] m_axi_wready;
	localparam signed [31:0] ID_W = $clog2(NUM_MASTERS);
	reg [NUM_MASTERS - 1:0] aw_buf_valid;
	reg [(NUM_MASTERS * ADDR_WIDTH) - 1:0] aw_buf_addr;
	reg [(NUM_MASTERS * 3) - 1:0] aw_buf_prot;
	reg [NUM_MASTERS - 1:0] w_buf_valid;
	reg [(NUM_MASTERS * DATA_WIDTH) - 1:0] w_buf_data;
	reg [(NUM_MASTERS * STRB_WIDTH) - 1:0] w_buf_strb;
	reg [NUM_MASTERS - 1:0] write_eligible;
	reg [NUM_MASTERS - 1:0] buf_locked;
	reg [1:0] w_state;
	reg [ID_W - 1:0] owner_id_r;
	reg [NUM_SLAVES - 1:0] target_slave_r;
	reg target_invalid_r;
	reg [ADDR_WIDTH - 1:0] latched_addr;
	reg [2:0] latched_prot;
	reg [DATA_WIDTH - 1:0] latched_wdata;
	reg [STRB_WIDTH - 1:0] latched_wstrb;
	reg arb_tx_done;
	wire [NUM_MASTERS - 1:0] arb_grant;
	wire [ID_W - 1:0] arb_master_id;
	wire arb_grant_valid;
	wire arb_starvation_unused;
	axi4lite_qos_scheduler #(.NUM_MASTERS(NUM_MASTERS)) u_write_qos(
		.aclk(aclk),
		.aresetn(aresetn),
		.cfg_weight_m0(cfg_weight_m0),
		.cfg_weight_m1(cfg_weight_m1),
		.cfg_weight_m2(cfg_weight_m2),
		.cfg_weight_m3(cfg_weight_m3),
		.cfg_master0_priority(cfg_master0_priority),
		.cfg_age_threshold(cfg_age_threshold),
		.cfg_master0_burst_limit(cfg_master0_burst_limit),
		.req(write_eligible),
		.transaction_complete(arb_tx_done),
		.grant(arb_grant),
		.master_id(arb_master_id),
		.grant_valid(arb_grant_valid),
		.starvation_flag(arb_starvation_unused)
	);
	reg [ADDR_WIDTH - 1:0] decode_addr;
	wire [1:0] decode_slave_sel;
	wire decode_invalid;
	wire decode_valid_unused;
	always @(*) begin
		decode_addr = 1'sb0;
		if (arb_grant_valid)
			decode_addr = aw_buf_addr[arb_master_id * ADDR_WIDTH+:ADDR_WIDTH];
	end
	axi4lite_address_decoder #(
		.ADDR_WIDTH(ADDR_WIDTH),
		.S0_BASE(S0_BASE),
		.S0_SIZE(S0_SIZE),
		.S1_BASE(S1_BASE),
		.S1_SIZE(S1_SIZE)
	) u_write_decoder(
		.addr(decode_addr),
		.slave_sel(decode_slave_sel),
		.valid_addr(decode_valid_unused),
		.invalid_addr(decode_invalid)
	);
	function automatic signed [ID_W - 1:0] sv2v_cast_1F7B3_signed;
		input reg signed [ID_W - 1:0] inp;
		sv2v_cast_1F7B3_signed = inp;
	endfunction
	always @(*) begin : sv2v_autoblock_1
		reg signed [31:0] m;
		for (m = 0; m < NUM_MASTERS; m = m + 1)
			buf_locked[m] = (w_state != 2'b00) && (owner_id_r == sv2v_cast_1F7B3_signed(m));
	end
	always @(*) begin : sv2v_autoblock_2
		reg signed [31:0] m;
		for (m = 0; m < NUM_MASTERS; m = m + 1)
			begin
				s_axi_awready[m] = !aw_buf_valid[m] && !buf_locked[m];
				s_axi_wready[m] = !w_buf_valid[m] && !buf_locked[m];
			end
	end
	always @(*) begin : sv2v_autoblock_3
		reg signed [31:0] m;
		for (m = 0; m < NUM_MASTERS; m = m + 1)
			write_eligible[m] = (aw_buf_valid[m] && w_buf_valid[m]) && !buf_locked[m];
	end
	always @(posedge aclk or negedge aresetn)
		if (!aresetn) begin
			aw_buf_valid <= 1'sb0;
			w_buf_valid <= 1'sb0;
			begin : sv2v_autoblock_4
				reg signed [31:0] m;
				for (m = 0; m < NUM_MASTERS; m = m + 1)
					begin
						aw_buf_addr[m * ADDR_WIDTH+:ADDR_WIDTH] <= 1'sb0;
						aw_buf_prot[m * 3+:3] <= 1'sb0;
						w_buf_data[m * DATA_WIDTH+:DATA_WIDTH] <= 1'sb0;
						w_buf_strb[m * STRB_WIDTH+:STRB_WIDTH] <= 1'sb0;
					end
			end
			w_state <= 2'b00;
			owner_id_r <= 1'sb0;
			target_slave_r <= 1'sb0;
			target_invalid_r <= 1'b0;
			latched_addr <= 1'sb0;
			latched_prot <= 1'sb0;
			latched_wdata <= 1'sb0;
			latched_wstrb <= 1'sb0;
			arb_tx_done <= 1'b0;
		end
		else begin
			arb_tx_done <= 1'b0;
			begin : sv2v_autoblock_5
				reg signed [31:0] m;
				for (m = 0; m < NUM_MASTERS; m = m + 1)
					if (s_axi_awvalid[m] && s_axi_awready[m]) begin
						aw_buf_valid[m] <= 1'b1;
						aw_buf_addr[m * ADDR_WIDTH+:ADDR_WIDTH] <= s_axi_awaddr[m * ADDR_WIDTH+:ADDR_WIDTH];
						aw_buf_prot[m * 3+:3] <= s_axi_awprot[m * 3+:3];
					end
			end
			begin : sv2v_autoblock_6
				reg signed [31:0] m;
				for (m = 0; m < NUM_MASTERS; m = m + 1)
					if (s_axi_wvalid[m] && s_axi_wready[m]) begin
						w_buf_valid[m] <= 1'b1;
						w_buf_data[m * DATA_WIDTH+:DATA_WIDTH] <= s_axi_wdata[m * DATA_WIDTH+:DATA_WIDTH];
						w_buf_strb[m * STRB_WIDTH+:STRB_WIDTH] <= s_axi_wstrb[m * STRB_WIDTH+:STRB_WIDTH];
					end
			end
			case (w_state)
				2'b00:
					if (arb_grant_valid) begin
						owner_id_r <= arb_master_id;
						latched_addr <= aw_buf_addr[arb_master_id * ADDR_WIDTH+:ADDR_WIDTH];
						latched_prot <= aw_buf_prot[arb_master_id * 3+:3];
						latched_wdata <= w_buf_data[arb_master_id * DATA_WIDTH+:DATA_WIDTH];
						latched_wstrb <= w_buf_strb[arb_master_id * STRB_WIDTH+:STRB_WIDTH];
						target_slave_r <= decode_slave_sel;
						target_invalid_r <= decode_invalid;
						w_state <= 2'b01;
					end
				2'b01:
					if (target_invalid_r)
						w_state <= 2'b10;
					else if ((target_slave_r[0] && m_axi_awready[0]) || (target_slave_r[1] && m_axi_awready[1]))
						w_state <= 2'b10;
				2'b10:
					if (target_invalid_r)
						w_state <= 2'b11;
					else if ((target_slave_r[0] && m_axi_wready[0]) || (target_slave_r[1] && m_axi_wready[1]))
						w_state <= 2'b11;
				2'b11:
					if (w_resp_handshake) begin
						aw_buf_valid[owner_id_r] <= 1'b0;
						w_buf_valid[owner_id_r] <= 1'b0;
						arb_tx_done <= 1'b1;
						w_state <= 2'b00;
					end
				default: w_state <= 2'b00;
			endcase
		end
	always @(*) begin
		begin : sv2v_autoblock_7
			reg signed [31:0] s;
			for (s = 0; s < NUM_SLAVES; s = s + 1)
				begin
					m_axi_awaddr[s * ADDR_WIDTH+:ADDR_WIDTH] = latched_addr;
					m_axi_awprot[s * 3+:3] = latched_prot;
					m_axi_awvalid[s] = 1'b0;
				end
		end
		if ((w_state == 2'b01) && !target_invalid_r) begin
			if (target_slave_r[0])
				m_axi_awvalid[0] = 1'b1;
			if (target_slave_r[1])
				m_axi_awvalid[1] = 1'b1;
		end
	end
	always @(*) begin
		begin : sv2v_autoblock_8
			reg signed [31:0] s;
			for (s = 0; s < NUM_SLAVES; s = s + 1)
				begin
					m_axi_wdata[s * DATA_WIDTH+:DATA_WIDTH] = latched_wdata;
					m_axi_wstrb[s * STRB_WIDTH+:STRB_WIDTH] = latched_wstrb;
					m_axi_wvalid[s] = 1'b0;
				end
		end
		if ((w_state == 2'b10) && !target_invalid_r) begin
			if (target_slave_r[0])
				m_axi_wvalid[0] = 1'b1;
			if (target_slave_r[1])
				m_axi_wvalid[1] = 1'b1;
		end
	end
	assign w_owner_id = owner_id_r;
	assign w_target_slave = target_slave_r;
	assign w_target_invalid = target_invalid_r;
	assign w_resp_phase = w_state == 2'b11;
endmodule
module axi4lite_read_arbiter (
	aclk,
	aresetn,
	cfg_weight_m0,
	cfg_weight_m1,
	cfg_weight_m2,
	cfg_weight_m3,
	cfg_master0_priority,
	cfg_age_threshold,
	cfg_master0_burst_limit,
	s_axi_araddr,
	s_axi_arprot,
	s_axi_arvalid,
	s_axi_arready,
	r_owner_id,
	r_target_slave,
	r_target_invalid,
	r_resp_phase,
	r_resp_handshake,
	m_axi_araddr,
	m_axi_arprot,
	m_axi_arvalid,
	m_axi_arready
);
	parameter signed [31:0] NUM_MASTERS = 4;
	parameter signed [31:0] NUM_SLAVES = 2;
	parameter signed [31:0] ADDR_WIDTH = 32;
	parameter signed [31:0] DATA_WIDTH = 32;
	parameter [ADDR_WIDTH - 1:0] S0_BASE = 32'h00000000;
	parameter [ADDR_WIDTH - 1:0] S0_SIZE = 32'h00010000;
	parameter [ADDR_WIDTH - 1:0] S1_BASE = 32'h00010000;
	parameter [ADDR_WIDTH - 1:0] S1_SIZE = 32'h00010000;
	input wire aclk;
	input wire aresetn;
	input wire [3:0] cfg_weight_m0;
	input wire [3:0] cfg_weight_m1;
	input wire [3:0] cfg_weight_m2;
	input wire [3:0] cfg_weight_m3;
	input wire cfg_master0_priority;
	input wire [7:0] cfg_age_threshold;
	input wire [7:0] cfg_master0_burst_limit;
	input wire [(NUM_MASTERS * ADDR_WIDTH) - 1:0] s_axi_araddr;
	input wire [(NUM_MASTERS * 3) - 1:0] s_axi_arprot;
	input wire [NUM_MASTERS - 1:0] s_axi_arvalid;
	output reg [NUM_MASTERS - 1:0] s_axi_arready;
	output wire [$clog2(NUM_MASTERS) - 1:0] r_owner_id;
	output wire [NUM_SLAVES - 1:0] r_target_slave;
	output wire r_target_invalid;
	output wire r_resp_phase;
	input wire r_resp_handshake;
	output reg [(NUM_SLAVES * ADDR_WIDTH) - 1:0] m_axi_araddr;
	output reg [(NUM_SLAVES * 3) - 1:0] m_axi_arprot;
	output reg [NUM_SLAVES - 1:0] m_axi_arvalid;
	input wire [NUM_SLAVES - 1:0] m_axi_arready;
	localparam signed [31:0] ID_W = $clog2(NUM_MASTERS);
	reg [1:0] r_state;
	reg [ID_W - 1:0] owner_id_r;
	reg [NUM_SLAVES - 1:0] target_slave_r;
	reg target_invalid_r;
	reg [ADDR_WIDTH - 1:0] latched_addr;
	reg [2:0] latched_prot;
	reg arb_tx_done;
	wire [NUM_MASTERS - 1:0] arb_grant;
	wire [ID_W - 1:0] arb_master_id;
	wire arb_grant_valid;
	wire arb_starvation_unused;
	wire [NUM_MASTERS - 1:0] arb_grant_unused;
	assign arb_grant_unused = arb_grant;
	axi4lite_qos_scheduler #(.NUM_MASTERS(NUM_MASTERS)) u_read_qos(
		.aclk(aclk),
		.aresetn(aresetn),
		.cfg_weight_m0(cfg_weight_m0),
		.cfg_weight_m1(cfg_weight_m1),
		.cfg_weight_m2(cfg_weight_m2),
		.cfg_weight_m3(cfg_weight_m3),
		.cfg_master0_priority(cfg_master0_priority),
		.cfg_age_threshold(cfg_age_threshold),
		.cfg_master0_burst_limit(cfg_master0_burst_limit),
		.req(s_axi_arvalid),
		.transaction_complete(arb_tx_done),
		.grant(arb_grant),
		.master_id(arb_master_id),
		.grant_valid(arb_grant_valid),
		.starvation_flag(arb_starvation_unused)
	);
	reg [ADDR_WIDTH - 1:0] decode_addr;
	wire [1:0] decode_slave_sel;
	wire decode_invalid;
	wire decode_valid_unused;
	always @(*) begin
		decode_addr = 1'sb0;
		if (arb_grant_valid)
			decode_addr = s_axi_araddr[arb_master_id * ADDR_WIDTH+:ADDR_WIDTH];
	end
	axi4lite_address_decoder #(
		.ADDR_WIDTH(ADDR_WIDTH),
		.S0_BASE(S0_BASE),
		.S0_SIZE(S0_SIZE),
		.S1_BASE(S1_BASE),
		.S1_SIZE(S1_SIZE)
	) u_read_decoder(
		.addr(decode_addr),
		.slave_sel(decode_slave_sel),
		.valid_addr(decode_valid_unused),
		.invalid_addr(decode_invalid)
	);
	reg target_arready;
	always @(*) begin
		target_arready = 1'b0;
		if (target_slave_r[0])
			target_arready = m_axi_arready[0];
		else if (target_slave_r[1])
			target_arready = m_axi_arready[1];
	end
	always @(posedge aclk or negedge aresetn)
		if (!aresetn) begin
			r_state <= 2'b00;
			owner_id_r <= 1'sb0;
			target_slave_r <= 1'sb0;
			target_invalid_r <= 1'b0;
			latched_addr <= 1'sb0;
			latched_prot <= 1'sb0;
			arb_tx_done <= 1'b0;
		end
		else begin
			arb_tx_done <= 1'b0;
			case (r_state)
				2'b00:
					if (arb_grant_valid) begin
						if (s_axi_arvalid[arb_master_id]) begin
							owner_id_r <= arb_master_id;
							latched_addr <= s_axi_araddr[arb_master_id * ADDR_WIDTH+:ADDR_WIDTH];
							latched_prot <= s_axi_arprot[arb_master_id * 3+:3];
							target_slave_r <= decode_slave_sel;
							target_invalid_r <= decode_invalid;
							r_state <= 2'b01;
						end
						else
							arb_tx_done <= 1'b1;
					end
				2'b01:
					if (target_invalid_r)
						r_state <= 2'b10;
					else if (target_arready)
						r_state <= 2'b10;
				2'b10:
					if (r_resp_handshake) begin
						arb_tx_done <= 1'b1;
						r_state <= 2'b00;
					end
				default: r_state <= 2'b00;
			endcase
		end
	always @(*) begin
		s_axi_arready = 1'sb0;
		if (r_state == 2'b01) begin
			if (target_invalid_r)
				s_axi_arready[owner_id_r] = 1'b1;
			else if (target_slave_r[0])
				s_axi_arready[owner_id_r] = m_axi_arready[0];
			else if (target_slave_r[1])
				s_axi_arready[owner_id_r] = m_axi_arready[1];
		end
	end
	always @(*) begin
		begin : sv2v_autoblock_1
			reg signed [31:0] s;
			for (s = 0; s < NUM_SLAVES; s = s + 1)
				begin
					m_axi_araddr[s * ADDR_WIDTH+:ADDR_WIDTH] = latched_addr;
					m_axi_arprot[s * 3+:3] = latched_prot;
					m_axi_arvalid[s] = 1'b0;
				end
		end
		if ((r_state == 2'b01) && !target_invalid_r) begin
			if (target_slave_r[0])
				m_axi_arvalid[0] = 1'b1;
			if (target_slave_r[1])
				m_axi_arvalid[1] = 1'b1;
		end
	end
	assign r_owner_id = owner_id_r;
	assign r_target_slave = target_slave_r;
	assign r_target_invalid = target_invalid_r;
	assign r_resp_phase = r_state == 2'b10;
endmodule
module axi4lite_arbiter_top (
	aclk,
	aresetn,
	cfg_weight_m0,
	cfg_weight_m1,
	cfg_weight_m2,
	cfg_weight_m3,
	cfg_master0_priority,
	cfg_age_threshold,
	cfg_master0_burst_limit,
	s_axi_awaddr,
	s_axi_awprot,
	s_axi_awvalid,
	s_axi_awready,
	s_axi_wdata,
	s_axi_wstrb,
	s_axi_wvalid,
	s_axi_wready,
	s_axi_bresp,
	s_axi_bvalid,
	s_axi_bready,
	s_axi_araddr,
	s_axi_arprot,
	s_axi_arvalid,
	s_axi_arready,
	s_axi_rdata,
	s_axi_rresp,
	s_axi_rvalid,
	s_axi_rready,
	m_axi_awaddr,
	m_axi_awprot,
	m_axi_awvalid,
	m_axi_awready,
	m_axi_wdata,
	m_axi_wstrb,
	m_axi_wvalid,
	m_axi_wready,
	m_axi_bresp,
	m_axi_bvalid,
	m_axi_bready,
	m_axi_araddr,
	m_axi_arprot,
	m_axi_arvalid,
	m_axi_arready,
	m_axi_rdata,
	m_axi_rresp,
	m_axi_rvalid,
	m_axi_rready
);
	parameter signed [31:0] NUM_MASTERS = 4;
	parameter signed [31:0] NUM_SLAVES = 2;
	parameter signed [31:0] ADDR_WIDTH = 32;
	parameter signed [31:0] DATA_WIDTH = 32;
	parameter signed [31:0] STRB_WIDTH = DATA_WIDTH / 8;
	parameter [ADDR_WIDTH - 1:0] S0_BASE = 32'h00000000;
	parameter [ADDR_WIDTH - 1:0] S0_SIZE = 32'h00010000;
	parameter [ADDR_WIDTH - 1:0] S1_BASE = 32'h00010000;
	parameter [ADDR_WIDTH - 1:0] S1_SIZE = 32'h00010000;
	input wire aclk;
	input wire aresetn;
	input wire [3:0] cfg_weight_m0;
	input wire [3:0] cfg_weight_m1;
	input wire [3:0] cfg_weight_m2;
	input wire [3:0] cfg_weight_m3;
	input wire cfg_master0_priority;
	input wire [7:0] cfg_age_threshold;
	input wire [7:0] cfg_master0_burst_limit;
	input wire [(NUM_MASTERS * ADDR_WIDTH) - 1:0] s_axi_awaddr;
	input wire [(NUM_MASTERS * 3) - 1:0] s_axi_awprot;
	input wire [NUM_MASTERS - 1:0] s_axi_awvalid;
	output wire [NUM_MASTERS - 1:0] s_axi_awready;
	input wire [(NUM_MASTERS * DATA_WIDTH) - 1:0] s_axi_wdata;
	input wire [(NUM_MASTERS * STRB_WIDTH) - 1:0] s_axi_wstrb;
	input wire [NUM_MASTERS - 1:0] s_axi_wvalid;
	output wire [NUM_MASTERS - 1:0] s_axi_wready;
	output wire [(NUM_MASTERS * 2) - 1:0] s_axi_bresp;
	output wire [NUM_MASTERS - 1:0] s_axi_bvalid;
	input wire [NUM_MASTERS - 1:0] s_axi_bready;
	input wire [(NUM_MASTERS * ADDR_WIDTH) - 1:0] s_axi_araddr;
	input wire [(NUM_MASTERS * 3) - 1:0] s_axi_arprot;
	input wire [NUM_MASTERS - 1:0] s_axi_arvalid;
	output wire [NUM_MASTERS - 1:0] s_axi_arready;
	output wire [(NUM_MASTERS * DATA_WIDTH) - 1:0] s_axi_rdata;
	output wire [(NUM_MASTERS * 2) - 1:0] s_axi_rresp;
	output wire [NUM_MASTERS - 1:0] s_axi_rvalid;
	input wire [NUM_MASTERS - 1:0] s_axi_rready;
	output wire [(NUM_SLAVES * ADDR_WIDTH) - 1:0] m_axi_awaddr;
	output wire [(NUM_SLAVES * 3) - 1:0] m_axi_awprot;
	output wire [NUM_SLAVES - 1:0] m_axi_awvalid;
	input wire [NUM_SLAVES - 1:0] m_axi_awready;
	output wire [(NUM_SLAVES * DATA_WIDTH) - 1:0] m_axi_wdata;
	output wire [(NUM_SLAVES * STRB_WIDTH) - 1:0] m_axi_wstrb;
	output wire [NUM_SLAVES - 1:0] m_axi_wvalid;
	input wire [NUM_SLAVES - 1:0] m_axi_wready;
	input wire [(NUM_SLAVES * 2) - 1:0] m_axi_bresp;
	input wire [NUM_SLAVES - 1:0] m_axi_bvalid;
	output wire [NUM_SLAVES - 1:0] m_axi_bready;
	output wire [(NUM_SLAVES * ADDR_WIDTH) - 1:0] m_axi_araddr;
	output wire [(NUM_SLAVES * 3) - 1:0] m_axi_arprot;
	output wire [NUM_SLAVES - 1:0] m_axi_arvalid;
	input wire [NUM_SLAVES - 1:0] m_axi_arready;
	input wire [(NUM_SLAVES * DATA_WIDTH) - 1:0] m_axi_rdata;
	input wire [(NUM_SLAVES * 2) - 1:0] m_axi_rresp;
	input wire [NUM_SLAVES - 1:0] m_axi_rvalid;
	output wire [NUM_SLAVES - 1:0] m_axi_rready;
	localparam signed [31:0] M_ID_WIDTH = (NUM_MASTERS > 1 ? $clog2(NUM_MASTERS) : 1);
	initial begin
		if (NUM_MASTERS != 4)
			$fatal(1, "[axi4lite_arbiter_top] NUM_MASTERS must be 4 (got %0d)", NUM_MASTERS);
		if (NUM_SLAVES != 2)
			$fatal(1, "[axi4lite_arbiter_top] NUM_SLAVES must be 2 (got %0d)", NUM_SLAVES);
	end
	wire [M_ID_WIDTH - 1:0] w_owner_id;
	wire [NUM_SLAVES - 1:0] w_target_slave;
	wire w_target_invalid;
	wire w_resp_phase;
	wire w_resp_handshake;
	wire w_owner_bready;
	wire [M_ID_WIDTH - 1:0] r_owner_id;
	wire [NUM_SLAVES - 1:0] r_target_slave;
	wire r_target_invalid;
	wire r_resp_phase;
	wire r_resp_handshake;
	wire r_owner_rready_unused;
	axi4lite_write_arbiter #(
		.NUM_MASTERS(NUM_MASTERS),
		.NUM_SLAVES(NUM_SLAVES),
		.ADDR_WIDTH(ADDR_WIDTH),
		.DATA_WIDTH(DATA_WIDTH),
		.STRB_WIDTH(STRB_WIDTH),
		.S0_BASE(S0_BASE),
		.S0_SIZE(S0_SIZE),
		.S1_BASE(S1_BASE),
		.S1_SIZE(S1_SIZE)
	) u_write_arbiter(
		.aclk(aclk),
		.aresetn(aresetn),
		.cfg_weight_m0(cfg_weight_m0),
		.cfg_weight_m1(cfg_weight_m1),
		.cfg_weight_m2(cfg_weight_m2),
		.cfg_weight_m3(cfg_weight_m3),
		.cfg_master0_priority(cfg_master0_priority),
		.cfg_age_threshold(cfg_age_threshold),
		.cfg_master0_burst_limit(cfg_master0_burst_limit),
		.s_axi_awaddr(s_axi_awaddr),
		.s_axi_awprot(s_axi_awprot),
		.s_axi_awvalid(s_axi_awvalid),
		.s_axi_awready(s_axi_awready),
		.s_axi_wdata(s_axi_wdata),
		.s_axi_wstrb(s_axi_wstrb),
		.s_axi_wvalid(s_axi_wvalid),
		.s_axi_wready(s_axi_wready),
		.w_owner_id(w_owner_id),
		.w_target_slave(w_target_slave),
		.w_target_invalid(w_target_invalid),
		.w_resp_phase(w_resp_phase),
		.w_resp_handshake(w_resp_handshake),
		.w_owner_bready(w_owner_bready),
		.m_axi_awaddr(m_axi_awaddr),
		.m_axi_awprot(m_axi_awprot),
		.m_axi_awvalid(m_axi_awvalid),
		.m_axi_awready(m_axi_awready),
		.m_axi_wdata(m_axi_wdata),
		.m_axi_wstrb(m_axi_wstrb),
		.m_axi_wvalid(m_axi_wvalid),
		.m_axi_wready(m_axi_wready)
	);
	axi4lite_read_arbiter #(
		.NUM_MASTERS(NUM_MASTERS),
		.NUM_SLAVES(NUM_SLAVES),
		.ADDR_WIDTH(ADDR_WIDTH),
		.DATA_WIDTH(DATA_WIDTH),
		.S0_BASE(S0_BASE),
		.S0_SIZE(S0_SIZE),
		.S1_BASE(S1_BASE),
		.S1_SIZE(S1_SIZE)
	) u_read_arbiter(
		.aclk(aclk),
		.aresetn(aresetn),
		.cfg_weight_m0(cfg_weight_m0),
		.cfg_weight_m1(cfg_weight_m1),
		.cfg_weight_m2(cfg_weight_m2),
		.cfg_weight_m3(cfg_weight_m3),
		.cfg_master0_priority(cfg_master0_priority),
		.cfg_age_threshold(cfg_age_threshold),
		.cfg_master0_burst_limit(cfg_master0_burst_limit),
		.s_axi_araddr(s_axi_araddr),
		.s_axi_arprot(s_axi_arprot),
		.s_axi_arvalid(s_axi_arvalid),
		.s_axi_arready(s_axi_arready),
		.r_owner_id(r_owner_id),
		.r_target_slave(r_target_slave),
		.r_target_invalid(r_target_invalid),
		.r_resp_phase(r_resp_phase),
		.r_resp_handshake(r_resp_handshake),
		.m_axi_araddr(m_axi_araddr),
		.m_axi_arprot(m_axi_arprot),
		.m_axi_arvalid(m_axi_arvalid),
		.m_axi_arready(m_axi_arready)
	);
	axi4lite_response_router #(
		.NUM_MASTERS(NUM_MASTERS),
		.NUM_SLAVES(NUM_SLAVES),
		.DATA_WIDTH(DATA_WIDTH)
	) u_response_router(
		.w_active(w_resp_phase),
		.w_owner_id(w_owner_id),
		.w_target_slave(w_target_slave),
		.w_target_invalid(w_target_invalid),
		.s_bresp(m_axi_bresp),
		.s_bvalid(m_axi_bvalid),
		.s_bready(m_axi_bready),
		.m_bresp(s_axi_bresp),
		.m_bvalid(s_axi_bvalid),
		.m_bready(s_axi_bready),
		.w_resp_handshake(w_resp_handshake),
		.w_owner_bready(w_owner_bready),
		.r_active(r_resp_phase),
		.r_owner_id(r_owner_id),
		.r_target_slave(r_target_slave),
		.r_target_invalid(r_target_invalid),
		.s_rdata(m_axi_rdata),
		.s_rresp(m_axi_rresp),
		.s_rvalid(m_axi_rvalid),
		.s_rready(m_axi_rready),
		.m_rdata(s_axi_rdata),
		.m_rresp(s_axi_rresp),
		.m_rvalid(s_axi_rvalid),
		.m_rready(s_axi_rready),
		.r_resp_handshake(r_resp_handshake),
		.r_owner_rready(r_owner_rready_unused)
	);
endmodule
