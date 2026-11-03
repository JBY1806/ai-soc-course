# merged_v4 src 복사본에 PPA After 변경 3개를 넣는다 (원본 · 팀 저장소는 안 건드림)
#  1) btn_debounce : 시프트 레지스터를 clk_remake(4 kHz 펄스)를 클럭으로 쓰지 않고, clk 로 돌리며 clk_remake 를 enable 로
#  2) counter8     : FND 스캔 카운터도 같은 방식 (i_clk 에 펄스 대신 clk + enable)
#  3) tick_gen_100hz : 1,000,000 세는 20비트 카운터 대신 4 kHz tick 을 40 번 세는 6비트 카운터
import os, shutil, re, sys
src = r'C:\work\BEST_Stop_watch_project\boyun\merged_v4\src'
base = os.path.dirname(os.path.abspath(__file__))
for tag in ('before', 'after'):
    d = os.path.join(base, tag, 'src')
    if os.path.exists(d): shutil.rmtree(d)
    shutil.copytree(src, d)
d = os.path.join(base, 'after', 'src')

def edit(fn, a, b):
    p = os.path.join(d, fn)
    raw = open(p, 'rb').read().decode('utf-8')
    crlf = '\r\n' in raw
    s = raw.replace('\r\n', '\n')
    assert s.count(a) == 1, (fn, a[:50])
    s = s.replace(a, b)
    if crlf: s = s.replace('\n', '\r\n')
    open(p, 'wb').write(s.encode('utf-8'))

# 1) 디바운서
edit('btn_debounce.v', 'always@(posedge clk_remake,posedge reset)begin', 'always@(posedge clk,posedge reset)begin   // PPA after: clk_remake 는 enable')
edit('btn_debounce.v', '\t\tq_reg <= {i_btn,q_reg[7:1]};', '\t\tif (clk_remake) q_reg <= {i_btn,q_reg[7:1]};')

# 2) counter8 : 포트 하나 추가 (i_tick), 클럭은 시스템 clk
edit('counter8.v', '\tinput i_clk,', '\tinput i_clk,\n\tinput i_tick,   // PPA after: 4 kHz enable')
edit('counter8.v', '\t\to_sel <= o_sel +1;', '\t\tif (i_tick) o_sel <= o_sel +1;')
edit('SW2_FND_CONTROLLER.v', '.i_clk(w_clk_4kHz),', '.i_clk(i_clk),\n.i_tick(w_clk_4kHz),')

# 3) 100 Hz = 4 kHz tick 40 번
edit('tick_gen_100hz.v', '    input clk,\n    input rst,', '    input clk,\n    input rst,\n    input i_tick_4k,   // PPA after: 4 kHz tick 을 40 번 세서 100 Hz')
edit('tick_gen_100hz.v', '    parameter F_COUNT = 100_000_000 / 100;', '    parameter F_COUNT = 4000 / 100;   // 40')
edit('tick_gen_100hz.v', '            if (run_stop) begin', '            if (run_stop & i_tick_4k) begin')
edit('stopwatch_watch.v', '    tick_gen_100hz U_TICK_GEN_100HZ (\n        .clk     (clk),', '    tick_gen_100hz U_TICK_GEN_100HZ (\n        .clk     (clk),\n        .i_tick_4k(w_clk_4Khz),')
print('ok')
