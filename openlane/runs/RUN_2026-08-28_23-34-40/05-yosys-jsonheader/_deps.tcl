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
read_verilog -sv -lib /work/openlane/runs/RUN_2026-08-28_23-34-40/tmp/40062a7084be4381ada09d5706be5fcb.bb.v
set ::env(SYNTH_LIBS) /work/openlane/runs/RUN_2026-08-28_23-34-40/tmp/dae06c52dbaf469285ce8fe2b271696d.lib
