# 최종 코드(동시 입력 무시까지, 팀 저장소 로컬 10/18 저녁) 기준으로 TS② 비교 판 4개를 다시 만든다
#   hybrid (④) : 최종 코드 그대로 (4 kHz 공유 + 100 Hz 기능마다)
#   before (②) : ④ 에서 스톱워치 · 타이머 전용 tick_gen 을 빼고 시계 tick 하나를 셋이 공유
#   after  (③) : ② + 4 kHz 를 클럭 대신 enable, 100 Hz 를 4 kHz tick 40 번
#   class  (①) : ④ + 수업 방식 디바운서 (디바운서마다 자체 분주)
# 바꾸는 방법은 ppa_v2/make_v2.py 와 같다 (기준 소스만 최종 코드)
import os, shutil
SRC = r'C:\work\BEST_Stop_watch_project\verification_v2\source_file'
base = os.path.dirname(os.path.abspath(__file__))

def fresh(tag):
    d = os.path.join(base, tag, 'src')
    if os.path.exists(d): shutil.rmtree(d)
    shutil.copytree(SRC, d)
    for f in os.listdir(d):
        if f.endswith('.md'): os.remove(os.path.join(d, f))
    return d

def read(d, fn):
    raw = open(os.path.join(d, fn), 'rb').read().decode('utf-8')
    return raw.replace('\r\n', '\n'), '\r\n' in raw

def save(d, fn, s, crlf):
    open(os.path.join(d, fn), 'wb').write((s.replace('\n', '\r\n') if crlf else s).encode('utf-8'))

def edit(d, fn, a, b):
    s, crlf = read(d, fn)
    assert s.count(a) == 1, (fn, a[:60])
    save(d, fn, s.replace(a, b), crlf)

def cut(d, fn, start, end):
    # start 줄부터 end 문자열 끝까지 지움
    s, crlf = read(d, fn)
    i = s.index(start); j = s.index(end, i) + len(end)
    assert s.count(start) == 1
    save(d, fn, s[:i] + s[j:], crlf)

def write(d, fn, text):
    open(os.path.join(d, fn), 'w', encoding='utf-8', newline='\r\n').write(text)

def shared_tick(d):
    # 스톱워치 · 타이머 전용 tick_gen 을 빼고 시계 tick(w_tick_10ms) 을 같이 씀
    cut(d, 'stopwatch_watch.v', '    tick_gen_100hz_run U_TICK_GEN_SW (', '''        .o_tick_10ms(w_tm_tick_10ms)
    );
''')
    edit(d, 'stopwatch_watch.v', '.i_tick_10ms  (w_sw_tick_10ms),', '.i_tick_10ms  (w_tick_10ms),   // PPA ②: 공유 tick')
    edit(d, 'stopwatch_watch.v', '.i_tick_10ms(w_tm_tick_10ms),', '.i_tick_10ms(w_tick_10ms),   // PPA ②: 공유 tick')
    os.remove(os.path.join(d, 'tick_gen_100hz_run.v'))

# ④ hybrid
fresh('hybrid')

# ② before
d = fresh('before')
shared_tick(d)

# ③ after
d = fresh('after')
shared_tick(d)
edit(d, 'btn_debounce.v', 'always @(posedge i_clk_4khz, posedge i_rst) begin', 'always @(posedge i_clk, posedge i_rst) begin   // PPA after: i_clk_4khz 는 enable')
edit(d, 'btn_debounce.v', "q_reg <= {i_btn, q_reg[7:1]};", "if (i_clk_4khz) q_reg <= {i_btn, q_reg[7:1]};")
edit(d, 'counter8.v', '    input            i_clk_4khz,', '    input            i_clk,\n    input            i_clk_4khz,   // PPA after: enable')
edit(d, 'counter8.v', 'always @(posedge i_clk_4khz, posedge i_rst) begin', 'always @(posedge i_clk, posedge i_rst) begin')
edit(d, 'counter8.v', 'else       o_scan_sel <= o_scan_sel + 1;', 'else if (i_clk_4khz) o_scan_sel <= o_scan_sel + 1;')
edit(d, 'SW2_FND_CONTROLLER.v', '    input                       i_clk_4khz,', '    input                       i_clk,\n    input                       i_clk_4khz,')
edit(d, 'SW2_FND_CONTROLLER.v', '        .i_clk_4khz(i_clk_4khz),\n        .i_rst     (i_rst),', '        .i_clk     (i_clk),\n        .i_clk_4khz(i_clk_4khz),\n        .i_rst     (i_rst),')
edit(d, 'stopwatch_watch.v', '        .i_rst      (rst),\n        .i_clk_4khz (w_clk_4khz),', '        .i_clk      (clk),\n        .i_rst      (rst),\n        .i_clk_4khz (w_clk_4khz),')
edit(d, 'tick_gen_100hz.v', '    input      i_rst,', '    input      i_rst,\n    input      i_tick_4khz,   // PPA after: 4 kHz tick 40 번 = 100 Hz')
edit(d, 'tick_gen_100hz.v', 'parameter F_COUNT = 100_000_000 / 100;', 'parameter F_COUNT = 4000 / 100;   // 40')
edit(d, 'tick_gen_100hz.v', '''        end else begin
            counter_reg <= counter_reg + 1;''', '''        end else if (i_tick_4khz) begin
            counter_reg <= counter_reg + 1;''')
edit(d, 'tick_gen_100hz.v', '''                o_tick_10ms <= 1'b0;
            end
        end
    end''', '''                o_tick_10ms <= 1'b0;
            end
        end else begin
            o_tick_10ms <= 1'b0;
        end
    end''')
edit(d, 'stopwatch_watch.v', '        .i_rst      (rst),\n        .o_tick_10ms(w_tick_10ms)', '        .i_rst      (rst),\n        .i_tick_4khz(w_clk_4khz),\n        .o_tick_10ms(w_tick_10ms)')

# ① class
d = fresh('class')
write(d, 'btn_debounce.v', '''`timescale 1ns / 1ps
// 수업 방식(8일차): 디바운서 안에 자체 분주 카운터 (4 kHz, 8칸 = 2 ms). i_clk_4khz 포트는 Top 연결용으로 남김 (안 씀)
module btn_debounce (
    input  i_clk,
    input  i_rst,
    input  i_clk_4khz,
    input  i_btn,
    output o_btn
);
    reg [7:0] q_reg;
    reg       debounce_reg;
    wire      debounce;
    parameter F_COUNT = 25_000;
    reg [$clog2(F_COUNT)-1:0] counter_reg;
    reg clk_4khz;
    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
            counter_reg <= 0;
            clk_4khz <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                clk_4khz <= 1'b1;
            end else begin
                clk_4khz <= 1'b0;
            end
        end
    end
    always @(posedge clk_4khz, posedge i_rst) begin
        if (i_rst) q_reg <= 8'h00;
        else       q_reg <= {i_btn, q_reg[7:1]};
    end
    assign debounce = &q_reg;
    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) debounce_reg <= 0;
        else       debounce_reg <= debounce;
    end
    assign o_btn = ~debounce_reg & debounce;
endmodule
''')
print('ok')
