import sys
from dump_vcd import parse_vcd, print_sig
sigs = parse_vcd('formal/arbiter_bmc/engine_0/trace.vcd')
print_sig(sigs, 's_axi_rvalid')
print_sig(sigs, 's_axi_rresp')
print_sig(sigs, 's_axi_rready')
print_sig(sigs, 'm_axi_rresp')
print_sig(sigs, 'm_axi_rvalid')
print_sig(sigs, 'r_target_slave_r')
