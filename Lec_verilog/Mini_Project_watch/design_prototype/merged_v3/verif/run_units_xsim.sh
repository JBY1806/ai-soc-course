#!/bin/bash
# 단위 TB 전부를 xsim 으로 (Icarus 결과와 비교용). 사용: bash run_units_xsim.sh
cd "$(dirname "$0")"; X="C:/Xilinx/Vivado/2022.2/bin"; SRC=$(cd ../src; pwd); mkdir -p xsim_units; cd xsim_units
printf 'run all\nquit\n' > run.tcl
run() { n=$1; tb=$2; shift 2; files=""; for f in "$@"; do files="$files $SRC/$f"; done
  "$X/xvlog.bat" ../v/$tb $files > $n.xvlog.log 2>&1 && "$X/xelab.bat" ${tb%.v} -s ${n}_snap -timescale 1ns/1ps > $n.xelab.log 2>&1 && "$X/xsim.bat" ${n}_snap --tclbatch run.tcl > $n.log 2>&1
  echo "== $n (xsim): $(grep -m1 'TOTAL' $n.log) | $(grep -c 'FAIL' $n.log) FAIL, $(grep -c DEVIATION $n.log) DEVIATION"; }
run sw_cu      tb_stopwatch_cu_unit.v  stopwatch_control_unit.v
run lap        tb_lap_unit.v           lap_controller.v
run timer      tb_timer_unit.v         timer_control_unit.v timer_datapath.v
run hour1224   tb_hour_12_24_unit.v    hour_12_24.v
run fnd        tb_fnd_unit.v           SW2_FND_CONTROLLER.v SW2_ANODE_CHOICE.v counter8.v decoder_2x4.v digit_splitter.v dot.v fnd_decoder.v mux_8x1.v
run watch_cu   tb_watch_cu_unit.v      watch_control_unit.v
run watch_cnt  tb_watch_tick_counter.v watch_datapath.v
run watch_dp   tb_watch_dp_unit.v      watch_datapath.v
run sw_dp      tb_stopwatch_dp_unit.v  stopwatch_datapath.v lap_controller.v
run tickgens   tb_tickgens_unit.v      tick_gen_100hz.v clock_tick_generator.v
run debounce   tb_btn_debounce_unit.v  btn_debounce.v clock_tick_generator.v
