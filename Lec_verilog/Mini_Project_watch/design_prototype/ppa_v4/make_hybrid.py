# ④ 절충안: 팀 판(before) 그대로 + 스톱워치 · 타이머용 tick_gen 을 따로 (시작할 때 0 부터 세도록)
#   - 디바운서 4 kHz 공유는 유지
#   - 시계: 공유 tick (항상 흐름)
#   - 스톱워치: 자기 tick_gen (run_stop · clear)
#   - 타이머: 자기 tick_gen (run, 취소 clear)
import os, shutil
base = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(base, 'before', 'src')
d = os.path.join(base, 'hybrid', 'src')
if os.path.exists(d): shutil.rmtree(d)
shutil.copytree(src, d)
p = os.path.join(d, 'stopwatch_watch.v')
raw = open(p, 'rb').read().decode('utf-8'); crlf = '\r\n' in raw
s = raw.replace('\r\n', '\n')
def rep(a, b):
    global s
    assert s.count(a) == 1, a[:60]
    s = s.replace(a, b)
rep('''        .o_tick  (w_tick_10ms)
    );''', '''        .o_tick  (w_tick_10ms)
    );
    wire w_tick_sw, w_tick_tm;
    tick_gen_100hz U_TICK_GEN_SW (              // 절충안: 스톱워치 전용 (시작 순간부터 셈)
        .clk     (clk),
        .rst     (rst),
        .run_stop(w_run_stop),
        .clear   (w_clear),
        .o_tick  (w_tick_sw)
    );
    tick_gen_100hz U_TICK_GEN_TM (              // 절충안: 타이머 전용 (취소하면 0 부터)
        .clk     (clk),
        .rst     (rst),
        .run_stop(w_tm_run),
        .clear   (w_tm_clear),
        .o_tick  (w_tick_tm)
    );''')
rep('''    stopwatch_datapath U_STOPWATCH_DATAPATH (
        .clk     (clk),
        .rst     (rst),
        .i_tick_10ms(w_tick_10ms),''', '''    stopwatch_datapath U_STOPWATCH_DATAPATH (
        .clk     (clk),
        .rst     (rst),
        .i_tick_10ms(w_tick_sw),''')
rep('''    timer_datapath U_TIMER_DATAPATH (
        .clk   (clk),
        .rst   (rst),
        .i_tick_10ms(w_tick_10ms),''', '''    timer_datapath U_TIMER_DATAPATH (
        .clk   (clk),
        .rst   (rst),
        .i_tick_10ms(w_tick_tm),''')
open(p, 'wb').write((s.replace('\n', '\r\n') if crlf else s).encode('utf-8'))
print('ok')
