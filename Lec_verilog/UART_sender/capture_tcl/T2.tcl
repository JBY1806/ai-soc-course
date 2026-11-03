# 3 단계 : uart_sender (FSM) — tb_sd2_sender 시나리오 (1) ~ (13)
source [file join [file dirname [info script]] common.tcl]
set tb /tb_sd2_sender; set d $tb/dut
add_wave -color $WHT $tb/clk
add_wave -color $WHT $tb/rst
set g [add_wave_group send_in]
add_wave -into $g -color $YEL $d/i_send_go
add_wave -into $g -color $YEL -radix unsigned $d/i_send_sel
add_wave -into $g -color $YEL -radix hex $d/i_send_data
add_wave -into $g -color $YEL -radix ascii $tb/in_text
add_wave -into $g -color $CYN $d/i_tx_full
set g [add_wave_group CU]
add_wave -into $g -color $PNK -radix unsigned $d/c_state
add_wave -into $g -color $PNK $d/o_send_busy
set g [add_wave_group DP]
add_wave -into $g -color $ORG -radix unsigned $d/c_sel
add_wave -into $g -color $ORG -radix hex $d/c_data
add_wave -into $g -color $ORG -radix ascii $tb/c_text
add_wave -into $g -color $ORG -radix unsigned $d/c_idx
add_wave -into $g -color $ORG -radix unsigned $d/w_last_idx
set g [add_wave_group next_comb]
add_wave -into $g -color $WHT -radix unsigned $d/n_state
add_wave -into $g -color $WHT -radix unsigned $d/n_sel
add_wave -into $g -color $WHT -radix hex $d/n_data
add_wave -into $g -color $WHT -radix unsigned $d/n_idx
set g [add_wave_group to_TX_FIFO]
add_wave -into $g -color $GRN $d/o_tx_push
add_wave -into $g -color $GRN -radix ascii $d/o_tx_push_data
add_wave -into $g -color $GRN -radix hex $d/o_tx_push_data
set g [add_wave_group tb_count]
add_wave -into $g -color $WHT -radix unsigned $tb/cnt
add_wave -into $g -color $WHT -radix unsigned $tb/busy_cnt
add_wave -into $g -color $WHT -radix unsigned $tb/err
add_condition -notrace "$d/i_send_go == 1" {rec go}
add_condition -notrace "$d/o_send_busy == 1" {rec bon}
add_condition -notrace "$d/o_send_busy == 0" {rec boff}
add_condition -notrace "$d/i_tx_full == 1" {rec fon}
add_condition -notrace "$d/i_tx_full == 0" {rec foff}
add_condition -notrace "$tb/rst == 1" {rec rst}
run all
foreach k {go bon boff fon foff rst} { dumpev $k }
# go 순서 : 1 S1 · 2 S2 · 3 S3 · 4 S4 · 5 S5 · 6 S6 · 7 S6 무시 · 8 S7 · 9~13 S8 · 14 S9 · 15 S10 · 16 S11 · 17 S11 마지막 글자 클럭 · 18 S12 · 19 S12 rst 뒤 · 20 ~ S13
# boff · foff · rst 는 1 번째가 시각 0 (리셋 초기값) 이라 하나씩 밀림
markn go 1 S1_go;  markn boff 2 S1_end
markn go 2 S2_go;  markn boff 3 S2_end
markn go 3 S3_go;  markn boff 4 S3_end
markn go 4 S4_go;  markn boff 5 S4_end
markn go 5 S5_go;  markn fon 1 S5_full_on; markn foff 2 S5_full_off; markn boff 6 S5_end
markn go 6 S6_go;  markn go 7 S6_go2_ignored; markn boff 7 S6_end
markn go 8 S7_go;  markn boff 8 S7_end
markn go 9 S8_go1; markn go 13 S8_go5; markn boff 13 S8_end
markn go 14 S9_go; markn fon 2 S9_full_on; markn foff 3 S9_full_off; markn boff 14 S9_end
markn go 15 S10_go; markn fon 3 S10_full_on; markn foff 4 S10_full_off; markn boff 15 S10_end
markn go 16 S11_go; markn go 17 S11_go_last_clk; markn boff 16 S11_end
markn go 18 S12_go; markn rst 2 S12_rst; markn go 19 S12_go_after; markn boff 18 S12_end
markn go 20 S13_start
