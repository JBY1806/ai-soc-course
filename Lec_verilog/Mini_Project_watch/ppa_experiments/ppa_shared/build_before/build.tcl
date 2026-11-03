# PPA Before: v3 (src) + 디바운서 2 kHz (build_2khz/btn_debounce.v), 같은 옵션
foreach f [glob ../../src/*.v] { if {[file tail $f] ne "btn_debounce.v"} { read_verilog $f } }
read_verilog ../../build_2khz/btn_debounce.v
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
