# 사용: vivado -mode batch -source ../build.tcl  (hybrid/ before/ after/ class/ 폴더에서)
# ppa_v2/build.tcl 과 같은 기본 옵션 (비트스트림만 생략 — 자원 · 타이밍 결과에는 영향 없음)
foreach f [glob src/*.v]  { read_verilog $f }
foreach f [glob src/*.sv] { read_verilog -sv $f }
read_xdc src/stopwatch_watch.xdc
synth_design -top stopwatch_watch -part xc7a35tcpg236-1
report_utilization -file util_synth.rpt
opt_design
place_design
route_design
report_utilization -file util_impl.rpt
report_utilization -hierarchical -file util_hier.rpt
report_timing_summary -file timing.rpt
report_methodology -file methodology.rpt
report_power -file power.rpt
