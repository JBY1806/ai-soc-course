# verification_v2/source_file (정안성 10/16 20:14 포트 통일판) 기준 비교 판 4개
#   before : 그대로 (4 kHz 공유 + 100 Hz tick 공유)
#   after  : 4 kHz 를 클럭 대신 enable, 100 Hz 를 4 kHz tick 40 번
#   class  : 수업 방식 — 디바운서 안 분주(4 kHz) + 스톱워치 · 타이머 · 시계 tick_gen 각각
#   hybrid : before + 스톱워치 · 타이머만 자기 tick_gen
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

def edit(d, fn, a, b):
    p = os.path.join(d, fn)
    raw = open(p, 'rb').read().decode('utf-8'); crlf = '\r\n' in raw
    s = raw.replace('\r\n', '\n')
    assert s.count(a) == 1, (fn, a[:60])
    s = s.replace(a, b)
    open(p, 'wb').write((s.replace('\n', '\r\n') if crlf else s).encode('utf-8'))

def write(d, fn, text):
    open(os.path.join(d, fn), 'w', encoding='utf-8', newline='\r\n').write(text)

TICK_RS = '''`timescale 1ns / 1ps
// 수업 방식 tick_gen (run_stop 이면 셈, clear 면 0 부터) — 비교용
module tick_gen_100hz_rs (
    input      i_clk,
    input      i_rst,
    input      i_run_stop,
    input      i_clear,
    output reg o_tick_10ms
);
    parameter F_COUNT = 100_000_000 / 100;
    reg [$clog2(F_COUNT)-1:0] counter_reg;
    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst | i_clear) begin
            counter_reg <= 0;
            o_tick_10ms <= 1'b0;
        end else if (i_run_stop) begin
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                o_tick_10ms <= 1'b1;
            end else begin
                counter_reg <= counter_reg + 1;
                o_tick_10ms <= 1'b0;
            end
        end else begin
            o_tick_10ms <= 1'b0;
        end
    end
endmodule
'''

def own_ticks(d):
    write(d, 'tick_gen_100hz_rs.v', TICK_RS)
    edit(d, 'stopwatch_watch.v', '''        .o_tick_10ms(w_tick_10ms)
    );''', '''        .o_tick_10ms(w_tick_10ms)
    );
    wire w_tick_sw, w_tick_tm;
    tick_gen_100hz_rs U_TICK_GEN_SW (   // 비교용: 스톱워치 전용 (시작 순간부터 셈)
        .i_clk(clk), .i_rst(rst), .i_run_stop(w_sw_run_stop), .i_clear(w_sw_clear), .o_tick_10ms(w_tick_sw));
    tick_gen_100hz_rs U_TICK_GEN_TM (   // 비교용: 타이머 전용 (취소하면 0 부터)
        .i_clk(clk), .i_rst(rst), .i_run_stop(w_tm_run), .i_clear(w_tm_clear), .o_tick_10ms(w_tick_tm));''')
    edit(d, 'stopwatch_watch.v', '''        .i_tick_10ms  (w_tick_10ms),
        .i_sw_run_stop(w_sw_run_stop),''', '''        .i_tick_10ms  (w_tick_sw),
        .i_sw_run_stop(w_sw_run_stop),''')
    edit(d, 'stopwatch_watch.v', '''        .i_tick_10ms(w_tick_10ms),
        .i_tm_run   (w_tm_run),''', '''        .i_tick_10ms(w_tick_tm),
        .i_tm_run   (w_tm_run),''')

# before
fresh('before')

# after
d = fresh('after')
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

# class
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
own_ticks(d)

# hybrid
d = fresh('hybrid')
own_ticks(d)
print('ok')
