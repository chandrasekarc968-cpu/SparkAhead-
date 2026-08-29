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
read_verilog -sv -lib /work/openlane/runs/RUN_2026-08-28_23-29-59/tmp/1049b111d40f4b91bb1aceb19e56fb74.bb.v
set ::env(SYNTH_LIBS) /work/openlane/runs/RUN_2026-08-28_23-29-59/tmp/894aaf13ea054fb3b708cde6df779e56.lib
