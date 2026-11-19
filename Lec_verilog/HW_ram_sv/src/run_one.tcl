# HW RAM SV (방법 B 수업 판 vs 방법 A 과제판) — Vivado 에서 판 하나 시뮬레이션 + 파형 · 색 · 마커
#   사용 : Vivado 를 새로 켜고 (프로젝트 안 연 상태) Tcl Console 에 (v = 1 ~ 4)
#     set v 1; source -notrace C:/Users/LG/Developer/Lec_verilog/HW_ram_sv/src/run_one.tcl
#   v 1 = B 수업 판 그대로 (=== 만, skip 없음)          : tb_B_noskip.sv + ram_ip_sv.sv
#   v 2 = B + skip · 합 계산 report (11/12)       : tb_B_skip.sv  + ram_ip_sv.sv
#   v 3 = A 과제판 (gen2scb · 매 cycle 판독)      : tb_A_final.sv + ram_ip_sv.sv
#   v 4 = A 과제판 + bug RAM (쓰기를 안 함)       : tb_A_final.sv + ram_ip_sv_bad_write.sv
#   프로젝트 : C:/work/ram_hw_prj (없으면 만들고, 있으면 그대로 씀). 판을 바꿀 때는 set v 만 바꿔 다시 source.
set src [file dirname [info script]]
if {![info exists prj]} { set prj C:/work/ram_hw_prj }
array set TBF  {1 tb_B_noskip.sv 2 tb_B_skip.sv 3 tb_A_final.sv 4 tb_A_final.sv}
array set DUTF {1 ram_ip_sv.sv 2 ram_ip_sv.sv 3 ram_ip_sv.sv 4 ram_ip_sv_bad_write.sv}
array set DESC {1 "B : no skip (=== only)" 2 "B + skip report" 3 "A final (gen2scb, every cycle)" 4 "A final + bug RAM (no write)"}
set A [expr {$v >= 3}]
if {![catch {current_project} curp] && $curp ne "ram_hw"} {
    error "Another project '$curp' is open. File > Close Project, then run this again."
}
if {[catch {current_project}]} {
    if {[file exists $prj/ram_hw.xpr]} { open_project $prj/ram_hw.xpr } else { create_project -force ram_hw $prj -part xc7a35tcpg236-1 }
}
catch {close_sim -force}
# 앞 판 컴파일 결과를 지워 항상 새로 컴파일 (Vivado 가 'No Change in HDL' 로 앞 판을 다시 쓰는 일 방지)
catch {file delete -force [file join $prj ram_hw.sim]}
set old [get_files -quiet -of_objects [get_filesets sources_1] */ram_ip_sv*.sv]
if {[llength $old]} { remove_files -fileset sources_1 $old }
add_files -fileset sources_1 -norecurse [file join $src $DUTF($v)]
set_property top ram_ip_sv [get_filesets sources_1]
set old [get_files -quiet -of_objects [get_filesets sim_1] */tb_*.sv]
if {[llength $old]} { remove_files -fileset sim_1 $old }
add_files -fileset sim_1 -norecurse [file join $src $TBF($v)]
set_property top tb_ram_sv [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {0ns} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]
set_property -name {xsim.compile.incremental} -value {false} -objects [get_filesets sim_1]
puts "\n===== v$v : $DESC($v) : $TBF($v) + $DUTF($v) ====="
launch_simulation
set_property -name {xsim.simulate.runtime} -value {1000ns} -objects [get_filesets sim_1]

# 파형 : 빨강 · 파랑 안 씀, 10 진수
set tb /tb_ram_sv
set i $tb/ram_if
create_wave_config ram_v$v
add_wave -color #FFFFFF $tb/clk
add_wave -color #FFFF00 -radix unsigned $i/addr
add_wave -color #FFA500 -radix unsigned $i/wdata
add_wave -color #FF69B4 $i/we
add_wave -color #00FF00 -radix unsigned $i/rdata
proc gv {s} { set x [get_value -radix unsigned $s]; if {[string is integer -strict $x]} { return $x } else { return X } }

# 걸어가기 : 객체 k 는 하강 엣지 10k ns 에 드라이브
#   B : monitor 가 다음 상승 엣지 10k+5 에 읽음 → 10k+4 값 = monitor 가 읽는 값
#   A : monitor 가 그다음 하강 엣지 10k+10 에 읽음 → 10k+9 값 (사이 10k+5 상승 엣지에 RAM 쓰기 끝)
set n 100
set rd_off [expr {$A ? 9 : 4}]
set ts_off [expr {$A ? 10 : 5}]
catch {array unset ex}; array set ex {}
set W 0; set R 0; set newa 0; set ovw 0; set pas 0; set fal 0; set skp 0; set wpas 0
set fw ""; set fo ""; set fs ""; set fp ""; set fx ""; set fwc ""; set ff ""
run [expr {10 + $rd_off}] ns
for {set k 1} {$k <= $n} {incr k} {
    set we [gv $i/we]; set a [gv $i/addr]; set wd [gv $i/wdata]; set rd [gv $i/rdata]
    set tw [expr {10 * $k + 5}]
    set ts [expr {10 * $k + $ts_off}]
    if {$we == 1} {
        incr W
        if {[info exists ex($a)]} { incr ovw; if {$fo eq ""} { set fo [list $tw $a] } } else { incr newa; if {$fw eq ""} { set fw [list $tw $a $wd] } }
        set ex($a) $wd
        if {$A} {
            if {$rd eq $wd} { incr pas; incr wpas; if {$fwc eq ""} { set fwc [list $ts $a $rd] } } else { incr fal; if {$ff eq ""} { set ff [list $ts $a $rd $wd] } }
        }
    } else {
        incr R
        if {![info exists ex($a)]} {
            if {$v == 1} { if {$rd eq "X"} { incr pas; if {$fx eq ""} { set fx [list $ts $a] } } else { incr fal } } else { incr skp; if {$fs eq ""} { set fs [list $ts $a] } }
        } elseif {$rd eq $ex($a)} { incr pas; if {$fp eq ""} { set fp [list $ts $a $rd] } } else { incr fal; if {$ff eq ""} { set ff [list $ts $a $rd $ex($a)] } }
    }
    if {$k < $n} { run 10 ns }
}
run all
set last [expr {10 * $n + $ts_off}]

catch {array unset M}; array set M {}
proc am {t name} { upvar M M; if {[info exists M($t)]} { append M($t) "__$name" } else { set M($t) $name } }
proc mk {t name} { add_wave_marker -name $name $t; puts [format "  marker %5d ns : %s" $t $name] }
am 10 "DRV_obj1"
am [expr {10 + $ts_off}] "MON_SCB_obj1"
if {$fw ne ""}  { lassign $fw t a wd;  am $t [format "first_write_addr%d_data%d" $a $wd] }
if {$fwc ne ""} { lassign $fwc t a rd; am $t [format "first_write_check_addr%d_rdata%d" $a $rd] }
if {$fo ne ""}  { lassign $fo t a;     am $t [format "first_overwrite_addr%d" $a] }
if {$fs ne ""}  { lassign $fs t a;     am $t [format "first_skip_addr%d" $a] }
if {$fx ne ""}  { lassign $fx t a;     am $t [format "first_x_pass_addr%d" $a] }
if {$fp ne ""}  { lassign $fp t a rd;  am $t [format "first_read_pass_addr%d_data%d" $a $rd] }
if {$ff ne ""}  { lassign $ff t a rd e; am $t [format "FIRST_FAIL_addr%d_rdata%s_expect%s" $a $rd $e] }
am $last [format "SCB_obj%d" $n]
am [expr {$last + 10}] "report_finish"
puts "===== v$v markers ====="
foreach t [lsort -integer [array names M]] { mk $t $M($t) }
puts "===== v$v summary (tcl model : same rule as this TB) ====="
puts [format "  objects %d = write %d (new %d + overwrite %d) + read %d" [expr {$W + $R}] $W $newa $ovw $R]
puts [format "  pass %d (write check %d) / fail %d / skip %d" $pas $wpas $fal $skp]
puts "===== v$v end (time [current_time]) ====="
