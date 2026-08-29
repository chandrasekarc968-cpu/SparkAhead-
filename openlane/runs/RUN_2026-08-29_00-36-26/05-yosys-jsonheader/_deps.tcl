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
read_verilog -sv -lib /work/openlane/runs/RUN_2026-08-29_00-36-26/tmp/0ea3cdae120244328da29c765caeb2b2.bb.v
set ::env(SYNTH_LIBS) /work/openlane/runs/RUN_2026-08-29_00-36-26/tmp/e23a3c9120c84408a959379b819bc9f2.lib
