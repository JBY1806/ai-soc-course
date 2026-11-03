#!/bin/bash
# 단위 TB 전부 iverilog 로 실행. 사용: bash run_units.sh  (merged_v3/verif 에서)
cd "$(dirname "$0")"
SRC=../src
mkdir -p log
run() {   # name  tb  srcs...
  n=$1; tb=$2; shift 2
  if iverilog -g2005 -o log/$n.vvp v/$tb "$@" 2> log/$n.compile.log; then
    timeout 1500 vvp -n log/$n.vvp > log/$n.log 2>&1
    echo "== $n: $(grep -m1 'TOTAL' log/$n.log) $(grep -c 'FAIL' log/$n.log) FAIL lines, $(grep -c DEVIATION log/$n.log) DEVIATION"
  else
    echo "== $n: COMPILE ERROR"; head -5 log/$n.compile.log
  fi
}
run debounce   tb_btn_debounce_unit.v  $SRC/btn_debounce.v $SRC/clock_tick_generator.v &
run tickgens   tb_tickgens_unit.v      $SRC/tick_gen_100hz.v $SRC/clock_tick_generator.v &
run sw_cu      tb_stopwatch_cu_unit.v  $SRC/stopwatch_control_unit.v
run lap        tb_lap_unit.v           $SRC/lap_controller.v
run timer      tb_timer_unit.v         $SRC/timer_control_unit.v $SRC/timer_datapath.v
run hour1224   tb_hour_12_24_unit.v    $SRC/hour_12_24.v
run fnd        tb_fnd_unit.v           $SRC/SW2_FND_CONTROLLER.v $SRC/SW2_ANODE_CHOICE.v $SRC/counter8.v $SRC/decoder_2x4.v $SRC/digit_splitter.v $SRC/dot.v $SRC/fnd_decoder.v $SRC/mux_8x1.v
run watch_cu   tb_watch_cu_unit.v      $SRC/watch_control_unit.v
run watch_cnt  tb_watch_tick_counter.v $SRC/watch_datapath.v
run watch_dp   tb_watch_dp_unit.v      $SRC/watch_datapath.v
run sw_dp      tb_stopwatch_dp_unit.v  $SRC/stopwatch_datapath.v $SRC/lap_controller.v
wait
