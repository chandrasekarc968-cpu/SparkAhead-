set ::_synlig_defines [list]
verilog_defines -DPDK_sky130A
lappend ::_synlig_defines +define+PDK_sky130A
verilog_defines "-DSCL_sky130_fd_sc_hd\""
lappend ::_synlig_defines "+define+SCL_sky130_fd_sc_hd\""
verilog_defines -D__openlane__
lappend ::_synlig_defines +define+__openlane__
verilog_defines -D__pnr__
lappend ::_synlig_defines +define+__pnr__
verilog_defines -DUSE_POWER_PINS
lappend ::_synlig_defines +define+USE_POWER_PINS
read_verilog -sv -lib /work/openlane/runs/RUN_2026-08-28_23-33-37/tmp/7cf924d420c1488190147f68b18f30fb.bb.v
set ::env(SYNTH_LIBS) /work/openlane/runs/RUN_2026-08-28_23-33-37/tmp/7d890448c012437f9519791ffa6a66a7.lib
