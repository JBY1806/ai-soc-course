# fifo_SV검증 (2026-11-10 과제) — Vivado 에서 판 하나를 시뮬레이션하고 파형·색·마커까지 한 번에
#
#   사용 : Vivado 를 새로 켜고 (프로젝트 안 연 상태) Tcl Console 에 (v = 1 ~ 4)
#     set v 1; source -notrace C:/Users/LG/Developer/Lec_verilog/HW_fifo_sv/src/run_one.tcl
#
#   v 1 = 과제 최종판 (run 100)        : tb_fifo_sv.sv         + fifo_sv.sv
#   v 2 = 커버리지 100 % 판 (run 1000) : tb_fifo_sv_cov1000.sv + fifo_sv.sv
#   v 3 = 최종판 + bug FIFO ①          : tb_fifo_sv.sv         + fifo_sv_bad_full.sv
#           full 을 세우는 줄을 지움 → 4 칸을 넘겨 덮어씀 (scoreboard 가 잡는다)
#   v 4 = 최종판 + bug FIFO ②          : tb_fifo_sv.sv         + fifo_sv_bad_rst.sv
#           리셋 값 full <= 1 → interface 의 reset assertion 이 잡는다
#
#   프로젝트 : C:/work/fifo_hw_prj (없으면 만들고, 있으면 그대로 씀).
#   판을 바꿀 때는 set v 만 바꿔 다시 source 하면 된다.
#
#   ※ 마커 시각은 툴바의 시간 단위로 읽힌다. 툴바가 ns 인지 먼저 확인할 것.

set src [file dirname [info script]]
if {![info exists prj]} { set prj C:/work/fifo_hw_prj }
if {![info exists v]}   { set v 1 }

array set TBF  {1 tb_fifo_sv.sv 2 tb_fifo_sv_cov1000.sv 3 tb_fifo_sv.sv 4 tb_fifo_sv.sv}
array set DUTF {1 fifo_sv.sv    2 fifo_sv.sv            3 fifo_sv_bad_full.sv 4 fifo_sv_bad_rst.sv}
# Tcl Console 에 찍히는 글은 한글이 깨지므로 영문으로 둔다 (주석은 한글 그대로)
array set DESC {
    1 "FINAL  (run 100,  300 items)"
    2 "COVERAGE 100% (run 1000, 3000 items)"
    3 "BUG1 full never set  -> scoreboard catches it"
    4 "BUG2 reset full=1    -> reset assertion catches it"
}

if {![catch {current_project} curp] && $curp ne "fifo_hw"} {
    error "Another project '$curp' is open. File > Close Project, then run this again."
}
if {[catch {current_project}]} {
    if {[file exists $prj/fifo_hw.xpr]} {
        open_project $prj/fifo_hw.xpr
    } else {
        create_project -force fifo_hw $prj -part xc7a35tcpg236-1
    }
}
catch {close_sim -force}

# 앞 판의 컴파일 결과를 지워 항상 새로 컴파일한다
#   (안 지우면 Vivado 가 'No Change in HDL' 로 판단해 앞 판을 그대로 다시 쓴다)
catch {file delete -force [file join $prj fifo_hw.sim]}

set old [get_files -quiet -of_objects [get_filesets sources_1] */fifo_sv*.sv]
if {[llength $old]} { remove_files -fileset sources_1 $old }
add_files -fileset sources_1 -norecurse [file join $src $DUTF($v)]
set_property top fifo_sv [get_filesets sources_1]

set old [get_files -quiet -of_objects [get_filesets sim_1] */tb_fifo_sv*.sv]
if {[llength $old]} { remove_files -fileset sim_1 $old }
add_files -fileset sim_1 -norecurse [file join $src $TBF($v)]
set_property top tb_fifo_sv [get_filesets sim_1]

set_property -name {xsim.simulate.runtime}        -value {0ns}  -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]
set_property -name {xsim.compile.incremental}      -value {false} -objects [get_filesets sim_1]

puts "\n===== v$v : $DESC($v) ====="
puts "      TB  = $TBF($v)"
puts "      DUT = $DUTF($v)"
launch_simulation

# ── 파형 : 빨강·파랑 안 씀 (Vivado 가 X 를 빨강, Z 를 파랑으로 그려 헷갈린다) ──
set tb /tb_fifo_sv
set i  $tb/fifo_if
create_wave_config fifo_v$v
add_wave -color #FFFFFF $tb/clk
add_wave -color #FF69B4 $i/rst
add_wave -color #FFFF00 $i/push
add_wave -color #FFA500 -radix unsigned $i/push_data
add_wave -color #ADFF2F $i/pop
add_wave -color #00FF00 -radix unsigned $i/pop_data
add_wave -color #FF00FF $i/full
add_wave -color #D2B48C $i/empty

run all

# ── 마커 : 보고서에서 잘라 쓸 구간 ──
proc mk {t name} { add_wave_marker -name $name $t; puts [format "  marker %6d ns : %s" $t $name] }
puts "===== v$v markers ====="
mk    5 "rst_assert_sample1"
mk   15 "rst_assert_sample2"
mk   20 "rst_release"
# DUT 는 posedge 에서 바뀌고(35·65), monitor 는 반 클럭 뒤 negedge 에 읽는다(40·70).
mk   35 "empty_1to0_DUT"
mk   40 "empty_MON_read"
mk   65 "full_0to1_DUT"
mk   70 "full_MON_read"
if {$v != 2} {
    mk 1070 "scenario2_first_empty_1"
    mk 2030 "scenario3_first_push_pop"
    mk 3020 "last_SCB"
}
puts "===== v$v end (time [current_time]) ====="
