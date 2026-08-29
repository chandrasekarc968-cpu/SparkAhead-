# ==============================================================================
# File       : timing.sdc
# Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
# Description: Synopsys Design Constraints (SDC) for synthesis and STA.
#              Tool-neutral — compatible with any SDC-compliant synthesis tool.
#              Target: 100 MHz (10 ns period), AMBA AXI4-Lite clock domain.
#
# Reset Convention: Synchronous active-low reset (aresetn).
#   RTL uses: always_ff @(posedge aclk) begin if (!aresetn) ...
#   SDC must include aresetn in timing analysis.
# ==============================================================================

# ------------------------------------------------------------------------------
# Clock Definition — 100 MHz
# ------------------------------------------------------------------------------
create_clock -name aclk -period 10.0 [get_ports aclk]

# ------------------------------------------------------------------------------
# Clock Uncertainty — covers PLL jitter + board skew
# For setup analysis:   Tperiod_effective = Tperiod - Tuncertainty
# ------------------------------------------------------------------------------
set_clock_uncertainty -setup 0.3 [get_clocks aclk]
set_clock_uncertainty -hold  0.1 [get_clocks aclk]

# ------------------------------------------------------------------------------
# Input Delays — Master-side (upstream) inputs to arbiter
# Budgeted at 30% of clock period for external master timing
# s_axi_* = inputs from masters
# m_axi_*ready = inputs from slaves (ready signals)
# m_axi_b* = inputs from slaves (write response)
# m_axi_r* = inputs from slaves (read response)
# ------------------------------------------------------------------------------
set_input_delay -clock aclk -max 3.0 [get_ports {s_axi_awaddr* s_axi_awprot* s_axi_awvalid*}]
set_input_delay -clock aclk -min 0.5 [get_ports {s_axi_awaddr* s_axi_awprot* s_axi_awvalid*}]

set_input_delay -clock aclk -max 3.0 [get_ports {s_axi_wdata* s_axi_wstrb* s_axi_wvalid*}]
set_input_delay -clock aclk -min 0.5 [get_ports {s_axi_wdata* s_axi_wstrb* s_axi_wvalid*}]

set_input_delay -clock aclk -max 3.0 [get_ports {s_axi_bready*}]
set_input_delay -clock aclk -min 0.5 [get_ports {s_axi_bready*}]

set_input_delay -clock aclk -max 3.0 [get_ports {s_axi_araddr* s_axi_arprot* s_axi_arvalid*}]
set_input_delay -clock aclk -min 0.5 [get_ports {s_axi_araddr* s_axi_arprot* s_axi_arvalid*}]

set_input_delay -clock aclk -max 3.0 [get_ports {s_axi_rready*}]
set_input_delay -clock aclk -min 0.5 [get_ports {s_axi_rready*}]

# Slave-side inputs
set_input_delay -clock aclk -max 3.0 [get_ports {m_axi_awready* m_axi_wready*}]
set_input_delay -clock aclk -min 0.5 [get_ports {m_axi_awready* m_axi_wready*}]

set_input_delay -clock aclk -max 3.0 [get_ports {m_axi_bresp* m_axi_bvalid*}]
set_input_delay -clock aclk -min 0.5 [get_ports {m_axi_bresp* m_axi_bvalid*}]

set_input_delay -clock aclk -max 3.0 [get_ports {m_axi_arready*}]
set_input_delay -clock aclk -min 0.5 [get_ports {m_axi_arready*}]

set_input_delay -clock aclk -max 3.0 [get_ports {m_axi_rdata* m_axi_rresp* m_axi_rvalid*}]
set_input_delay -clock aclk -min 0.5 [get_ports {m_axi_rdata* m_axi_rresp* m_axi_rvalid*}]

# QoS sideband inputs — quasi-static, generous timing
set_input_delay -clock aclk -max 5.0 [get_ports {cfg_weight_m* cfg_master0_priority cfg_age_threshold* cfg_master0_burst_limit*}]
set_input_delay -clock aclk -min 0.5 [get_ports {cfg_weight_m* cfg_master0_priority cfg_age_threshold* cfg_master0_burst_limit*}]

# ------------------------------------------------------------------------------
# Output Delays — to masters and slaves
# Budgeted at 30% of clock period
# ------------------------------------------------------------------------------
set_output_delay -clock aclk -max 3.0 [get_ports {s_axi_awready* s_axi_wready*}]
set_output_delay -clock aclk -min 0.5 [get_ports {s_axi_awready* s_axi_wready*}]

set_output_delay -clock aclk -max 3.0 [get_ports {s_axi_bresp* s_axi_bvalid*}]
set_output_delay -clock aclk -min 0.5 [get_ports {s_axi_bresp* s_axi_bvalid*}]

set_output_delay -clock aclk -max 3.0 [get_ports {s_axi_arready*}]
set_output_delay -clock aclk -min 0.5 [get_ports {s_axi_arready*}]

set_output_delay -clock aclk -max 3.0 [get_ports {s_axi_rdata* s_axi_rresp* s_axi_rvalid*}]
set_output_delay -clock aclk -min 0.5 [get_ports {s_axi_rdata* s_axi_rresp* s_axi_rvalid*}]

# To slaves
set_output_delay -clock aclk -max 3.0 [get_ports {m_axi_awaddr* m_axi_awprot* m_axi_awvalid*}]
set_output_delay -clock aclk -min 0.5 [get_ports {m_axi_awaddr* m_axi_awprot* m_axi_awvalid*}]

set_output_delay -clock aclk -max 3.0 [get_ports {m_axi_wdata* m_axi_wstrb* m_axi_wvalid*}]
set_output_delay -clock aclk -min 0.5 [get_ports {m_axi_wdata* m_axi_wstrb* m_axi_wvalid*}]

set_output_delay -clock aclk -max 3.0 [get_ports {m_axi_bready*}]
set_output_delay -clock aclk -min 0.5 [get_ports {m_axi_bready*}]

set_output_delay -clock aclk -max 3.0 [get_ports {m_axi_araddr* m_axi_arprot* m_axi_arvalid*}]
set_output_delay -clock aclk -min 0.5 [get_ports {m_axi_araddr* m_axi_arprot* m_axi_arvalid*}]

set_output_delay -clock aclk -max 3.0 [get_ports {m_axi_rready*}]
set_output_delay -clock aclk -min 0.5 [get_ports {m_axi_rready*}]

# ------------------------------------------------------------------------------
# Synchronous Active-Low Reset
# The RTL uses: always_ff @(posedge aclk) begin if (!aresetn) ...
# Reset is part of the datapath timing graph and must be timed.
# ------------------------------------------------------------------------------
# set_false_path -from [get_ports aresetn]  <-- Removed for synchronous reset

# ------------------------------------------------------------------------------
# QoS Config Multicycle Paths
# These are quasi-static control registers. Allow 2-cycle setup.
# This relaxes timing on the config input fanout cone.
# ------------------------------------------------------------------------------
set_multicycle_path 2 -setup -from [get_ports {cfg_weight_m* cfg_master0_priority cfg_age_threshold* cfg_master0_burst_limit*}]
set_multicycle_path 1 -hold  -from [get_ports {cfg_weight_m* cfg_master0_priority cfg_age_threshold* cfg_master0_burst_limit*}]
