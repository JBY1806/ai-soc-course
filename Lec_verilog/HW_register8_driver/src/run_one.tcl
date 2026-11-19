# hw register 8bit driver task run 차이점 — Vivado 에서 버전 하나만 시뮬레이션 + 파형 · 마커
#   사용 : Vivado Tcl Console 에 (V = 1 또는 2)
#     set v 1; source -notrace C:/Users/LG/Developer/Lec_verilog/HW_register8_driver/src/run_one.tcl
#   버전 1 = get → @(posedge clk) (drive 2 cycle) · 버전 2 = @(posedge clk) → get (drive 1 cycle)
#   두 파일은 driver run 의 그 줄 순서만 다르고 나머지는 work\...\20261105_register8_sv 의 TB 와 같다.
#   프로젝트 : C:/work/reg8drv_prj (없으면 만들고, 있으면 그대로 씀)
set src [file dirname [info script]]
set prj C:/work/reg8drv_prj
set tbs {tb_v1_get_posedge.sv tb_v2_posedge_get.sv}
set f [lindex $tbs [expr {$v - 1}]]
if {[catch {current_project}]} {
    if {[file exists $prj/reg8drv.xpr]} { open_project $prj/reg8drv.xpr } else { create_project reg8drv $prj -part xc7a35tcpg236-1 }
}
catch {close_sim -force}
if {![llength [get_files -quiet -of_objects [get_filesets sources_1] register_8.sv]]} {
    add_files -fileset sources_1 -norecurse [file join $src register_8.sv]
}
set old [get_files -quiet -of_objects [get_filesets sim_1] tb_v*.sv]
if {[llength $old]} { remove_files -fileset sim_1 $old }
add_files -fileset sim_1 -norecurse [file join $src $f]
set_property top tb_register_8_sv_verification [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {1000ns} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]
puts "\n===== Version $v : $f ====="
launch_simulation
puts "===== Version $v end (time [current_time]) ====="
# 파형 : clk · reset · d · q (빨강 · 파랑 안 씀), 16 진수
create_wave_config reg8_version$v
set i /tb_register_8_sv_verification/reg_if
add_wave -color #FFFFFF /tb_register_8_sv_verification/clk
add_wave -color #FFA500 $i/reset
add_wave -color #FFFF00 -radix hex $i/d
add_wave -color #00FF00 -radix hex $i/q
proc mark {name t} { add_wave_marker -name $name $t }
if {$v == 1} {
    mark M15_GEN_GET 15; mark M26_DRIVE 26; mark M35_MON_SCB 35; mark M46_DRIVE 46; mark M55_SCB 55
} else {
    mark M15_GEN 15; mark M25_GET 25; mark M26_DRIVE 26; mark M35_MON_SCB 35; mark M36_DRIVE 36; mark M45_SCB 45
}
