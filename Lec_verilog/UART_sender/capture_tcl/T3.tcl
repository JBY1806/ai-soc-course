# 4 단계 : sender_tx_top (sender → TX FIFO 64 → uart_tx → tx) — PC 쪽에서 받은 글자
source [file join [file dirname [info script]] common.tcl]
set tb /tb_sd3_top; set d $tb/dut
set f $d/U_FIFO_TX; set u $d/U_UART_TX
set g [add_wave_group send_in]
add_wave -into $g -color $YEL $tb/i_send_go
add_wave -into $g -color $YEL -radix unsigned $tb/i_send_sel
add_wave -into $g -color $YEL -radix hex $tb/i_send_data
add_wave -into $g -color $PNK $tb/o_send_busy
set g [add_wave_group sender_to_fifo]
add_wave -into $g -color $GRN $d/w_tx_push
add_wave -into $g -color $GRN -radix ascii $d/w_tx_push_data
add_wave -into $g -color $CYN $d/w_tx_full
set g [add_wave_group TX_FIFO]
add_wave -into $g -color $ORG -radix unsigned $f/w_wptr
add_wave -into $g -color $ORG -radix unsigned $f/w_rptr
add_wave -into $g -color $ORG $f/empty
add_wave -into $g -color $ORG $f/pop
add_wave -into $g -color $ORG -radix ascii $f/pop_data
set g [add_wave_group UART_TX]
add_wave -into $g -color $PNK $u/tx_start
add_wave -into $g -color $PNK $u/tx_busy
add_wave -into $g -color $PNK -radix unsigned $u/c_state
add_wave -into $g -color $PNK -radix ascii $u/data_reg
add_wave -into $g -color $PNK -radix unsigned $u/bit_count_reg
add_wave -color $YEL $tb/tx
set g [add_wave_group PC_rx]
add_wave -into $g -color $WHT -radix ascii $tb/rdata
add_wave -into $g -color $WHT -radix unsigned $tb/rcnt
add_wave -into $g -color $WHT -radix unsigned $tb/busy_cnt
add_wave -into $g -color $WHT -radix unsigned $tb/err
add_condition -notrace "$tb/i_send_go == 1" {rec go}
add_condition -notrace "$tb/o_send_busy == 0" {rec boff}
add_condition -notrace "$tb/tx == 0" {rec txlow}
add_condition -notrace "$tb/rcnt == 1" {rec r1}
# rcnt 비교 값은 2 진으로 적어야 함 (xsim add_condition : 13 → 1101, 14 → 1110, 67 → 1000011)
add_condition -notrace "$tb/rcnt == 1101" {rec r13}
add_condition -notrace "$tb/rcnt == 1110" {rec r14}
add_condition -notrace "$tb/rcnt == 1000011" {rec r67}
run all
foreach k {go boff r1 r13 r14 r67} { dumpev $k }
puts "EV txlow first [lrange $::ev(txlow) 0 3]"
# boff 1 번째는 시각 0 (리셋 초기값) 이라 하나씩 밀림
markn go 1 A1_go; markn boff 2 A1_busy_end; markn txlow 1 A1_start_bit; markn r1 1 A1_char1_done; markn r13 1 A1_line_done
markn go 2 A2_go1; markn go 6 A2_go5; markn boff 7 A2_busy_end; markn r14 1 A2_char1_done; markn r67 1 A2_all_done
