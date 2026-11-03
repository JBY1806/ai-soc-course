# 10/19 모듈별 자원: 최종 소스(verification_v2/source_file) 그대로. 인자 0 = 기본 합성, 1 = -flatten_hierarchy none (모듈 경계 유지)
set keep [lindex $argv 0]
foreach f [glob ../src/*.v]  { read_verilog $f }
foreach f [glob ../src/*.sv] { read_verilog -sv $f }
read_xdc ../src/stopwatch_watch.xdc
if {$keep == 1} {
  synth_design -top stopwatch_watch -part xc7a35tcpg236-1 -flatten_hierarchy none
} else {
  synth_design -top stopwatch_watch -part xc7a35tcpg236-1
}
report_utilization -hierarchical -file util_hier_synth.rpt
opt_design
place_design
route_design
report_utilization -file util_impl.rpt
report_utilization -hierarchical -file util_hier.rpt
report_timing_summary -file timing.rpt
