# HW counter 256 (3 클럭 이상 연속 + 신호별 pass / fail) — Vivado 에서 판 하나 시뮬레이션 + 파형 · 마커
#   사용 : Vivado Tcl Console 에 (v = 1 ~ 5)
#     set v 3; source -notrace C:/Users/LG/Developer/Lec_verilog/HW_counter256/src/run_one.tcl
#   v 1 = before : hold 없음 (11/06 TB 그대로) : tb_before_nohold.sv + counter_256.sv
#   v 2 = HW, hold 3 ~ 16 (교수님 값)         : tb_hw_hold16.sv + counter_256.sv
#   v 3 = HW, hold 3 ~ 8 (최종)               : tb_hw_hold8.sv  + counter_256.sv
#   v 4 = HW, hold 3 ~ 16 + clear 고장 DUT    : tb_hw_hold16.sv + counter_256_bad_clear.sv
#   v 5 = HW, hold 3 ~ 8  + clear 고장 DUT    : tb_hw_hold8.sv  + counter_256_bad_clear.sv
#   프로젝트 : C:/work/counter256_hw_prj (없으면 만들고, 있으면 그대로 씀)
#   스크립트가 301 클럭을 10 ns 씩 걸어가며 값을 읽어 마커 위치를 정하고, TB scoreboard 와 같은 규칙으로 다시 세어 대조한다.
set src [file dirname [info script]]
if {![info exists prj]} { set prj C:/work/counter256_hw_prj }
array set TBF  {1 tb_before_nohold.sv 2 tb_hw_hold16.sv 3 tb_hw_hold8.sv 4 tb_hw_hold16.sv 5 tb_hw_hold8.sv}
array set DUTF {1 counter_256.sv 2 counter_256.sv 3 counter_256.sv 4 counter_256_bad_clear.sv 5 counter_256_bad_clear.sv}
array set DESC {1 "before : no hold" 2 "HW hold 3~16" 3 "HW hold 3~8 (final)" 4 "HW hold 3~16 + bad clear DUT" 5 "HW hold 3~8 + bad clear DUT"}
set hw [expr {$v != 1}]
# 다른 프로젝트 (예: 내 실습 프로젝트) 가 열려 있으면 그 파일을 빼 버리므로 멈춘다
if {![catch {current_project} curp] && $curp ne "counter256_hw"} {
    error "Another project '$curp' is open. File > Close Project, then run this again."
}
if {[catch {current_project}]} {
    if {[file exists $prj/counter256_hw.xpr]} { open_project $prj/counter256_hw.xpr } else { create_project counter256_hw $prj -part xc7a35tcpg236-1 }
}
catch {close_sim -force}
# 앞 판 파일 빼기 : get_files 의 이름 패턴은 전체 경로와 맞춰 보므로 앞에 */ 가 있어야 한다
set old [get_files -quiet -of_objects [get_filesets sources_1] */counter_256*.sv]
if {[llength $old]} { remove_files -fileset sources_1 $old }
add_files -fileset sources_1 -norecurse [file join $src $DUTF($v)]
set_property top counter_256 [get_filesets sources_1]
set old [get_files -quiet -of_objects [get_filesets sim_1] */tb_*.sv]
if {[llength $old]} { remove_files -fileset sim_1 $old }
add_files -fileset sim_1 -norecurse [file join $src $TBF($v)]
set_property top tb_counter_sv [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {0ns} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]
# 판을 바꿀 때마다 처음부터 다시 컴파일
set_property -name {xsim.compile.incremental} -value {false} -objects [get_filesets sim_1]
puts "\n===== v$v : $DESC($v) : $TBF($v) + $DUTF($v) ====="
set fl {}; foreach f [get_files -of_objects [get_filesets sim_1]] { lappend fl [file tail $f] }
puts "  files in project : $fl"
launch_simulation
# 0ns 는 0 ns 부터 걸어가려고 잠깐 바꾼 것 → 프로젝트 설정을 기본값 1000ns 로 되돌림
set_property -name {xsim.simulate.runtime} -value {1000ns} -objects [get_filesets sim_1]

# 파형 : 빨강 · 파랑 안 씀, 10 진수
set tb /tb_counter_sv
set i $tb/counter_if
create_wave_config hw_v$v
add_wave -color #FFFFFF $tb/clk
add_wave -color #FFA500 $i/rst
add_wave -color #FFFF00 $i/run_stop
add_wave -color #FF69B4 $i/mode
add_wave -color #90EE90 $i/clear
add_wave -color #00FF00 -radix unsigned $i/counter
if {$hw} {
    add_wave -color #C0C0C0 -radix unsigned $i/obj_no
    add_wave -color #DDA0DD -radix unsigned $i/hold
}
proc mk {t name} { add_wave_marker -name $name $t; puts [format "  marker %5d ns : %s" $t $name] }
proc gv {s} { set x [get_value -radix unsigned $s]; if {[string is integer -strict $x]} { return $x } else { return X } }

# 걸어가기 : 24 · 34 · … · 3024 ns (상승 엣지 1 ns 앞 = monitor 가 읽는 값과 같음)
set NMK 5
set exp 0; set pv 0; set tot 0; set pas 0; set fal 0; set ffail ""
set pclr 0; set prs 0
array set cp {mode 0 run_stop 0 clear 0}; array set fp {mode 0 run_stop 0 clear 0}
array set last {}; array set len {mode 0 run_stop 0 clear 0}; array set h3 {mode 0 run_stop 0 clear 0}; array set sh {mode 0 run_stop 0 clear 0}
set pobj 0; set objs {}; set clr1 ""
run 24 ns
for {set k 0} {$k <= 300} {incr k} {
    set t [expr {24 + 10 * $k}]
    set rst [gv $i/rst]; set md [gv $i/mode]; set rs [gv $i/run_stop]; set cl [gv $i/clear]; set c [gv $i/counter]
    if {$hw} {
        set ob [gv $i/obj_no]; set ho [gv $i/hold]
        if {$ob ne $pobj && $ob ne "X" && $ob > 0} { lappend objs [list $ob [expr {$t - 8}] $ho $md $rs $cl]; set pobj $ob }
    }
    if {$cl == 1 && $clr1 eq ""} { set clr1 [expr {$t - 8}] }
    if {$rst == 1} {
        set exp 0; set pv 0
    } else {
        if {$pv} {
            incr tot
            set ok [expr {$c eq $exp}]
            if {$ok} { incr pas } else { incr fal; if {$ffail eq ""} { set ffail [list [expr {$t + 1}] $c $exp] } }
            if {$pclr} { if {$ok} { incr cp(clear) } else { incr fp(clear) } } else {
                if {$ok} { incr cp(run_stop) } else { incr fp(run_stop) }
                if {$prs} { if {$ok} { incr cp(mode) } else { incr fp(mode) } }
            }
        }
        if {$cl == 1} { set exp 0 } elseif {$rs == 1} { if {$md == 1} { set exp [expr {($exp + 255) % 256}] } else { set exp [expr {($exp + 1) % 256}] } }
        set pv 1; set pclr $cl; set prs $rs
        foreach {n val} [list mode $md run_stop $rs clear $cl] {
            if {$len($n) > 0 && $val eq $last($n)} { incr len($n) } else { if {$len($n) > 0 && $len($n) < 3 && $k - $len($n) > 0} { incr sh($n) }; set len($n) 1 }
            if {$len($n) == 3} { incr h3($n) }
            set last($n) $val
        }
    }
    if {$k < 300} { run 10 ns }
}
run all

# 마커
mk 20 "preset_end_rst0"
if {$hw} {
    for {set j 0} {$j < $NMK && $j < [llength $objs]} {incr j} {
        lassign [lindex $objs $j] ob td ho md rs cl
        mk $td [format "O%d_hold%d_rs%d_m%d_c%d" $ob $ho $rs $md $cl]
    }
    foreach o $objs { lassign $o ob td ho md rs cl; if {$cl == 1} { if {$ob > $NMK} { mk $td [format "CLR_O%d_hold%d_rs%d_m%d" $ob $ho $rs $md] }; break } }
} else {
    mk 26 "first_drive"
    if {$clr1 ne ""} { mk $clr1 "first_clear1" }
}
if {$ffail ne ""} { lassign $ffail tf fc fe; mk $tf [format "FIRST_FAIL_counter%s_expect%s" $fc $fe] }
mk 3020 "enable_0"
mk 3030 "report_finish"

# 요약 (보고서 · 캡처 대조용)
puts "===== v$v summary : $DESC($v) ====="
puts [format "  check (tcl model) : total %d  pass %d  fail %d" $tot $pas $fal]
puts [format "  per signal pass/fail : mode %d/%d  run_stop %d/%d  clear %d/%d" $cp(mode) $fp(mode) $cp(run_stop) $fp(run_stop) $cp(clear) $fp(clear)]
puts [format "  runs of same value >= 3 clocks : mode %d  run_stop %d  clear %d" $h3(mode) $h3(run_stop) $h3(clear)]
puts [format "  runs shorter than 3 clocks (1 or 2, preset not counted) : mode %d  run_stop %d  clear %d" $sh(mode) $sh(run_stop) $sh(clear)]
if {$ffail ne ""} { puts [format "  first fail : %s ns  counter %s  expect %s" {*}$ffail] } else { puts "  first fail : none" }
if {$hw} {
    puts [format "  objects : %d   (first %d below : drive time / hold / next drive expected = drive + 10 x hold)" [llength $objs] $NMK]
    set bad 0
    for {set j 0} {$j < [llength $objs]} {incr j} {
        lassign [lindex $objs $j] ob td ho md rs cl
        set nx [expr {$td + 10 * $ho}]
        set real [expr {$j + 1 < [llength $objs] ? [lindex [lindex $objs [expr {$j + 1}]] 1] : "-"}]
        if {$real ne "-" && $real != $nx} { incr bad }
        if {$j < $NMK + 3} { puts [format "    O%-3d %5d ns  hold %2d  rs %d m %d c %d  next expect %5d  real %s" $ob $td $ho $rs $md $cl $nx $real] }
    }
    puts "  next-drive time mismatch : $bad"
    if {$clr1 ne ""} { puts "  first clear=1 object drive : $clr1 ns" }
} else {
    if {$clr1 ne ""} { puts "  first clear=1 drive : $clr1 ns" }
}
puts "===== v$v end (time [current_time]) ====="
