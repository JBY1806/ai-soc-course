# 사용: vivado -mode batch -source ../strat.tcl -tclargs <tag> <synth_directive> <opt_directive> <power 0/1> <perf 0/1>
#   A_area  : AreaOptimized_high  Default      0 0   (= 합성 전략 Flow_AreaOptimized_high)
#   B_area2 : AreaOptimized_high  ExploreArea  0 0   (= + 구현 Area_Explore 의 opt 단계)
#   C_power : Default             Default      1 0   (= 구현 Power_DefaultOpt, power_opt_design)
#   D_perf  : PerformanceOptimized Explore     0 1   (= Flow_PerfOptimized_high + Performance_Explore)
set tag [lindex $argv 0]; set sd [lindex $argv 1]; set od [lindex $argv 2]; set pw [lindex $argv 3]; set pf [lindex $argv 4]
foreach f [glob src/*.v]  { read_verilog $f }
foreach f [glob src/*.sv] { read_verilog -sv $f }
read_xdc src/stopwatch_watch.xdc
if {$sd eq "Default"} { synth_design -top stopwatch_watch -part xc7a35tcpg236-1 } else { synth_design -top stopwatch_watch -part xc7a35tcpg236-1 -directive $sd }
if {$od eq "Default"} { opt_design } else { opt_design -directive $od }
if {$pw} { power_opt_design }
if {$pf} {
    place_design -directive Explore
    phys_opt_design -directive Explore
    route_design -directive Explore
} else {
    place_design
    route_design
}
report_utilization -file ${tag}_util_impl.rpt
report_timing_summary -file ${tag}_timing.rpt
report_power -file ${tag}_power.rpt
