import sys
from dump_vcd import parse_vcd, print_sig
sigs = parse_vcd('formal/arbiter_bmc/engine_0/trace.vcd')
print_sig(sigs, 'latched_addr')
print_sig(sigs, 'r_state')
print_sig(sigs, 'm_axi_arready')
print_sig(sigs, 'm_axi_araddr')
print_sig(sigs, 'target_arready')
