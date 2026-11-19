# uart SV 검증 (2026-11-11 과제) — Vivado 에서 판 하나를 시뮬레이션하고 파형 · 색 · 마커까지 한 번에
#
#   사용 : Vivado 를 새로 켜고 (프로젝트 안 연 상태) Tcl Console 에 (v = 1 ~ 3)
#     set v 1; source -notrace C:/Users/LG/Developer/Lec_verilog/HW_uart_sv/src/run_one.tcl
#
#   v 1 = 최종판 (수정 후, 20 글자)       : tb_uart_sv.sv        + uart_tx.sv
#           driver 99 줄 repeat (tr.interval + 1)
#   v 2 = 수정 전 (20 글자)               : tb_uart_sv_before.sv + uart_tx.sv
#           driver 99 줄 repeat (tr.interval) — 16 번째 글자 interval 0 에서 멈춤
#           → run all 대신 15,700 us 까지만 돌린다 (그 뒤로는 아무 일도 안 일어남)
#   v 3 = 최종판 + bug uart_tx             : tb_uart_sv.sv        + uart_tx_bad_stop.sv
#           STOP 상태 96 줄 b_tick_cnt_reg == 15 → == 3 (stop 비트가 b_tick 4 번으로 짧아짐)
#
#   프로젝트 : C:/work/uart_hw_prj (없으면 만들고, 있으면 그대로 씀).
#   판을 바꿀 때는 set v 만 바꿔 다시 source 하면 된다.
#
#   ※ 마커 시각은 툴바의 시간 단위로 읽힌다. 파형 창 위 단위가 ns 인지 먼저 확인할 것.

set src [file dirname [info script]]
if {![info exists prj]} { set prj C:/work/uart_hw_prj }
if {![info exists v]}   { set v 1 }

array set TBF {1 tb_uart_sv.sv 2 tb_uart_sv_before.sv 3 tb_uart_sv.sv}
array set TXF {1 uart_tx.sv    2 uart_tx.sv           3 uart_tx_bad_stop.sv}
# Tcl Console 에 찍히는 글은 한글이 깨지므로 영문으로 둔다 (주석은 한글 그대로)
array set DESC {
    1 "FINAL (fixed, repeat interval+1, 20 chars)"
    2 "BEFORE fix (repeat interval) -> hangs at char 16 (15,650,075 ns)"
    3 "FINAL + BUG uart_tx stop bit 4 ticks -> stop / frame fail"
}

if {![catch {current_project} curp] && $curp ne "uart_hw"} {
    error "Another project '$curp' is open. File > Close Project, then run this again."
}
if {[catch {current_project}]} {
    if {[file exists $prj/uart_hw.xpr]} {
        open_project $prj/uart_hw.xpr
    } else {
        create_project -force uart_hw $prj -part xc7a35tcpg236-1
    }
}
catch {close_sim -force}

# 앞 판의 컴파일 결과를 지워 항상 새로 컴파일한다
#   (안 지우면 Vivado 가 'No Change in HDL' 로 판단해 앞 판을 그대로 다시 쓴다)
catch {file delete -force [file join $prj uart_hw.sim]}

set old [get_files -quiet -of_objects [get_filesets sources_1] */uart*.sv]
if {[llength $old]} { remove_files -fileset sources_1 $old }
add_files -fileset sources_1 -norecurse [list [file join $src uart.sv] [file join $src $TXF($v)]]
set_property top uart [get_filesets sources_1]

set old [get_files -quiet -of_objects [get_filesets sim_1] */tb_uart_sv*.sv]
if {[llength $old]} { remove_files -fileset sim_1 $old }
add_files -fileset sim_1 -norecurse [file join $src $TBF($v)]
set_property top tb_uart_sv [get_filesets sim_1]

set_property -name {xsim.simulate.runtime}         -value {0ns}   -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true}  -objects [get_filesets sim_1]
set_property -name {xsim.compile.incremental}      -value {false} -objects [get_filesets sim_1]

puts "\n===== v$v : $DESC($v) ====="
puts "      TB = $TBF($v)"
puts "      TX = $TXF($v)"
launch_simulation

# ── 파형 : 빨강 · 파랑 안 씀 (Vivado 가 X 를 빨강, Z 를 파랑으로 그려 헷갈린다) ──
set tb /tb_uart_sv
set i  $tb/uart_if
set u  $tb/dut/U_UART_TX
create_wave_config uart_v$v
add_wave -color #FFFFFF $tb/clk
add_wave -color #FF69B4 $i/rst
add_wave -color #FFFF00 $i/start
add_wave -color #FFA500 -radix unsigned $i/tx_data
add_wave -color #00FF00 $i/tx
add_wave -color #FF00FF $i/tx_busy
add_wave -color #D2B48C $tb/dut/b_tick
add_wave -color #ADFF2F $u/c_state
add_wave -color #F0E68C -radix unsigned $u/b_tick_cnt_reg
add_wave -color #EE82EE -radix unsigned $u/bit_cnt_reg
add_wave -color #FFDAB9 -radix bin      $u/data_reg

if {$v == 2} {
    run 15700 us
} else {
    run all
}

# ── 마커 : 보고서에서 잘라 쓸 구간 ──
proc mk {t name} { add_wave_marker -name $name $t; puts [format "  marker %12d ns : %s" $t $name] }
puts "===== v$v markers ====="
mk       20 "rst_release"
mk       30 "DRV_get_char1"
if {$v == 2} {
    mk  6480 "start_up_char1"
} else {
    mk  6490 "start_up_char1"
}
if {$v == 2} {
    mk  6485 "DUT_START_char1"
    mk  6495 "tx_fall_char1"
    mk 15650075 "char16_start_up_at_posedge"
    mk 15650080 "char16_start_down"
} else {
    mk  6495 "DUT_START_char1"
    mk  6505 "tx_fall_char1"
    mk 110675 "start_bit_end_char1"
    if {$v == 1} {
        mk 1041635 "frame1_end"
        mk 15650075 "char16_DRV_get"
        mk 15650080 "char16_start_up"
        mk 15650085 "char16_DUT_START"
    } else {
        mk 937470 "STOP_start_char1"
        mk 963510 "IDLE_back_char1_short_stop"
    }
}
puts "===== v$v end (time [current_time]) ====="
