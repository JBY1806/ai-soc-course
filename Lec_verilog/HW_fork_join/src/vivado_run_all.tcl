# hw fork join — Vivado 안에서 예제 5 개를 차례로 시뮬레이션
#   사용 : Vivado 시작 화면 아래 Tcl Console 에
#     source C:/Users/LG/Developer/Lec_verilog/HW_fork_join/src/vivado_run_all.tcl
#   새 프로젝트 C:/work/forkjoin_prj (있으면 지우고 새로) 를 만들고, 예제마다
#   sim 소스를 그 파일 하나로 바꿔 Run Behavioral Simulation → run all → 닫기.
#   결과 줄은 Tcl Console 에 차례로 나온다 (예제 사이 ===== Example N ===== 표시).
set src [file dirname [info script]]
set prj C:/work/forkjoin_prj
catch {close_project}
file delete -force $prj
create_project forkjoin $prj -part xc7a35tcpg236-1 -force
set i 0
foreach f {ex1_join.sv ex2_join_any.sv ex3_join_none.sv ex4_nested.sv ex5_disable_fork.sv} {
    incr i
    set old [get_files -quiet -of_objects [get_filesets sim_1] *.sv]
    if {[llength $old]} { remove_files -fileset sim_1 $old }
    add_files -fileset sim_1 -norecurse [file join $src $f]
    set_property top tb_fork_join [get_filesets sim_1]
    set_property -name {xsim.simulate.runtime} -value {200ns} -objects [get_filesets sim_1]
    puts "\n===== Example $i : $f ====="
    launch_simulation
    puts "===== Example $i end (time [current_time]) ====="
    close_sim -force
}
puts "\nDone - 5 examples"
