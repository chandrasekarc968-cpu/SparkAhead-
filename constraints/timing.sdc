# ==============================================================================
# File       : timing.sdc
# Project    : VELTRAXX'26 PS02 — Multi-Master AXI4-Lite Arbiter
# Description: Synopsys Design Constraints (SDC) template.
#              Tool-neutral — compatible with any SDC-compliant synthesis tool.
# ==============================================================================

# ------------------------------------------------------------------------------
# Clock Definition
# ------------------------------------------------------------------------------
# TODO: Adjust period to match target frequency.
#       100 MHz → 10.0 ns period
create_clock -name aclk -period 10.0 [get_ports aclk]

# ------------------------------------------------------------------------------
# Clock Uncertainty
# ------------------------------------------------------------------------------
# TODO: Set based on PLL jitter and board-level skew.
set_clock_uncertainty 0.2 [get_clocks aclk]

# ------------------------------------------------------------------------------
# Input Delays (master-side)
# ------------------------------------------------------------------------------
# TODO: Constrain setup/hold for all AXI4-Lite master input ports.
# set_input_delay  -clock aclk -max 2.0 [get_ports m_axi_*]
# set_input_delay  -clock aclk -min 0.5 [get_ports m_axi_*]

# ------------------------------------------------------------------------------
# Output Delays (slave-side)
# ------------------------------------------------------------------------------
# TODO: Constrain setup/hold for all AXI4-Lite slave output ports.
# set_output_delay -clock aclk -max 2.0 [get_ports s_axi_*]
# set_output_delay -clock aclk -min 0.5 [get_ports s_axi_*]

# ------------------------------------------------------------------------------
# False Paths / Multicycle Paths
# ------------------------------------------------------------------------------
# TODO: Add any false/multicycle path exceptions here.

# ------------------------------------------------------------------------------
# Reset
# ------------------------------------------------------------------------------
# Treat aresetn as asynchronous; constrain recovery/removal.
# TODO: Uncomment once ports exist.
# set_false_path -from [get_ports aresetn]
