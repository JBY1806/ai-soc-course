# 1 단계 : sender_char_mux (조합) — 형식마다 i_idx 0 ~ 끝 → o_char · o_last_idx
source [file join [file dirname [info script]] common.tcl]
set tb /tb_sd1_char; set d $tb/dut
set g [add_wave_group char_mux_in]
add_wave -into $g -color $YEL -radix unsigned $d/i_sel
add_wave -into $g -color $YEL -radix hex $d/i_data
add_wave -into $g -color $YEL -radix unsigned $d/i_idx
set g [add_wave_group char_mux_out]
add_wave -into $g -color $GRN -radix ascii $d/o_char
add_wave -into $g -color $CYN -radix hex $d/o_char
add_wave -into $g -color $PNK -radix unsigned $d/o_last_idx
set g [add_wave_group tb_check]
add_wave -into $g -color $ORG -radix ascii $tb/exp_c
add_wave -into $g -color $ORG -radix unsigned $tb/err
add_condition -notrace "$d/i_idx == 0" {rec line}
run all
dumpev line
set names {L1_time L2_zero L3_max L4_lead0 L5_cm0 L6_cm7 L7_cm58 L8_cm400 L9_ht45 L10_ht0 L11_ht99 L12_err7 L13_err5 L14_err6}
set i 1; foreach n $names { markn line $i $n; incr i }
