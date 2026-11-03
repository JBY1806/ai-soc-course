# PPA After: 공통 2 kHz 분주기 하나 (../src)
foreach f [glob ../src/*.v] { read_verilog $f }
read_xdc ../../src/stopwatch_watch.xdc
synth_design -top stopwatch_watch -part xc7a35tcpg236-1
opt_design
place_design
route_design
report_utilization -file util_impl.rpt
report_utilization -hierarchical -file util_hier.rpt
report_timing_summary -file timing.rpt
report_methodology -file methodology.rpt
report_power -file power.rpt
write_bitstream -force stopwatch_watch_ppa_shared.bit
