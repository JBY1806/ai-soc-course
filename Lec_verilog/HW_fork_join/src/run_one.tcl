# hw fork join — Vivado 에서 예제 하나만 시뮬레이션 (결과 창은 열어 둔 채로 끝남)
#   사용 : Vivado Tcl Console 에 (N = 1 ~ 5)
#     set ex 1; source -notrace C:/Users/LG/Developer/Lec_verilog/HW_fork_join/src/run_one.tcl
#   → 캡처 → 다음은 set ex 2; source … (앞 시뮬은 이 스크립트가 닫고 새로 띄움)
#   프로젝트 : C:/work/forkjoin_prj (없으면 만들고, 있으면 그대로 씀)
set src [file dirname [info script]]
set prj C:/work/forkjoin_prj
set files {ex1_join.sv ex2_join_any.sv ex3_join_none.sv ex4_nested.sv ex5_disable_fork.sv}
set f [lindex $files [expr {$ex - 1}]]
if {[catch {current_project}]} {
    if {[file exists $prj/forkjoin.xpr]} { open_project $prj/forkjoin.xpr } else { create_project forkjoin $prj -part xc7a35tcpg236-1 }
}
catch {close_sim -force}
set old [get_files -quiet -of_objects [get_filesets sim_1] *.sv]
if {[llength $old]} { remove_files -fileset sim_1 $old }
add_files -fileset sim_1 -norecurse [file join $src $f]
set_property top tb_fork_join [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {200ns} -objects [get_filesets sim_1]
puts "\n===== Example $ex : $f ====="
launch_simulation
puts "===== Example $ex end (time [current_time]) ====="
