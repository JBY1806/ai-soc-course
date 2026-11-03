#!/bin/bash
# SV 랜덤 5 시드 (xsim). 사용: bash run_seeds.sh
cd "$(dirname "$0")/xsim"; X="C:/Xilinx/Vivado/2022.2/bin"
"$X/xvlog.bat" -sv ../sv/tb_top_random.sv ../../src/*.v > xvlog_rand.log 2>&1 && "$X/xelab.bat" tb_top_random -s rand_snap -timescale 1ns/1ps > xelab_rand.log 2>&1 || { echo COMPILE FAIL; exit 1; }
printf 'run all\nquit\n' > run.tcl
for sd in 1 2 3 4 5; do s0=$(date +%s); "$X/xsim.bat" rand_snap --tclbatch run.tcl --sv_seed $sd > run_seed$sd.log 2>&1; echo "== seed $sd ($(( $(date +%s) - s0 )) s)"; grep -n "FAIL" run_seed$sd.log | head -5; grep "cycles compared\|alarms\|coincidences\|coverage\|TOTAL" run_seed$sd.log; done
