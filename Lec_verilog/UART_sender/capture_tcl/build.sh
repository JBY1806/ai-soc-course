#!/bin/bash
# sender 캡처용 파형 파일 만들기 (xsim 단독) : bash build.sh [T1 T2 T3]
#   소스 = 20261030_uart_sender 프로젝트 현재 파일 그대로 (sources_1/new 3 개 + imports/uart_fifo 4 개, TB = sim_1/imports/tb)
#   결과 = C:/work/uart_sender_capture/waves/<ID>.wdb · <ID>.wcfg  +  이 폴더 open_<ID>.tcl
unset NoDefaultCurrentDirectoryInExePath
HERE=$(cd "$(dirname "$0")" && pwd -W)
VIV="C:/Xilinx/Vivado/2022.2/bin"
ROOT=/c/work/uart_sender_capture; W=C:/work/uart_sender_capture/waves; mkdir -p $ROOT/waves
P=/c/Users/LG/Developer/work/26_AI_CAMP_2/20261030_uart_sender/20261030_uart_sender.srcs
IDS=${@:-T1 T2 T3}
for ID in $IDS; do
  case $ID in
    T1) TB=tb_sd1_char ;;  T2) TB=tb_sd2_sender ;;  T3) TB=tb_sd3_top ;;
  esac
  B=$ROOT/build/$ID; rm -rf $B; mkdir -p $B
  cp $P/sources_1/new/*.v $P/sources_1/imports/uart_fifo/*.v $P/sim_1/imports/tb/$TB.v $B/
  cd $B
  "$VIV/xvlog.bat" *.v > c.log 2>&1
  "$VIV/xelab.bat" $TB -s snap -debug typical > e.log 2>&1
  printf 'source %s/%s.tcl\nsave_wave_config %s/%s.wcfg\nquit\n' "$HERE" "$ID" "$W" "$ID" > wrap.tcl
  "$VIV/xsim.bat" snap -wdb $W/$ID.wdb -onfinish stop -tclbatch wrap.tcl -log $ID.log > /dev/null 2>&1
  printf '# %s 파형 열기 — 시뮬 다시 안 돌림 (저장한 파형 + 신호 · 색 · 그룹 · 마커)\n#   Vivado 시작 화면 (프로젝트 안 열어도 됨) Tcl Console 에 :\n#   source %s/open_%s.tcl\nopen_wave_database %s/%s.wdb\nopen_wave_config   %s/%s.wcfg\n' \
    "$ID" "$HERE" "$ID" "$W" "$ID" "$W" "$ID" > "$HERE/open_$ID.tcl"
  echo "== $ID ($TB): $(grep -hE 'ERROR' c.log e.log | head -2) wdb $(stat -c %s $ROOT/waves/$ID.wdb 2>/dev/null) B, marks $(grep -c '^MARK' $ID.log)"
  grep -aE "TOTAL|TIMEOUT|ERROR" $ID.log | head -4
done
