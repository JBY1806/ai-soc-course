# ① 수업 구조 판 (다시): merged_v4 기능 그대로, 분주를 수업 방식으로
#   - btn_debounce: 수업(8일차) 판처럼 모듈 안에 자체 분주 카운터 (4 kHz = F_COUNT 25,000, 창 길이 2 ms 를 팀 판과 같게)
#   - FND 스캔: 기존 4 kHz 생성기를 FND 전용으로
#   - 100 Hz tick_gen: 스톱워치 · 시계 · 타이머 각각 (9일차 판서)
import os, shutil
src = r'C:\work\BEST_Stop_watch_project\boyun\merged_v4\src'
base = os.path.dirname(os.path.abspath(__file__))
d = os.path.join(base, 'class2', 'src')
if os.path.exists(d): shutil.rmtree(d)
shutil.copytree(src, d)

deb = '''`timescale 1ns / 1ps
// 수업 구조(8일차 btn_debounce): 디바운서마다 자체 분주 카운터. 팀 판과 같은 4 kHz (8칸 = 2 ms)
// clk_remake 포트는 Top 연결을 그대로 두려고 남겨 둠 (안 씀)
module btn_debounce (
    input  clk_remake,
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);
    reg [7:0] q_reg;
    wire debounce;
    reg edge_reg;

    parameter F_COUNT = 25_000;  // 100 MHz / 4 kHz
    reg [$clog2(F_COUNT)-1:0] counter_reg;
    reg clk_4khz;
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            clk_4khz <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == (F_COUNT - 1)) begin
                counter_reg <= 0;
                clk_4khz <= 1'b1;
            end else begin
                clk_4khz <= 1'b0;
            end
        end
    end

    always @(posedge clk_4khz, posedge reset) begin
        if (reset) q_reg <= 8'h0;
        else       q_reg <= {i_btn, q_reg[7:1]};
    end

    assign debounce = &q_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) edge_reg <= 1'b0;
        else       edge_reg <= debounce;
    end

    assign o_btn = ~edge_reg & debounce;
endmodule
'''
open(os.path.join(d, 'btn_debounce.v'), 'w', encoding='utf-8', newline='\r\n').write(deb)

p = os.path.join(d, 'stopwatch_watch.v')
raw = open(p, 'rb').read().decode('utf-8'); crlf = '\r\n' in raw
s = raw.replace('\r\n', '\n')
def rep(a, b):
    global s
    assert s.count(a) == 1, a[:60]
    s = s.replace(a, b)
rep('''    tick_gen_100hz U_TICK_GEN_100HZ (
        .clk     (clk),
        .rst     (rst),
        .run_stop(1'b1),
        .clear   (1'b0),
        .o_tick  (w_tick_10ms)
    );''', '''    tick_gen_100hz U_TICK_GEN_100HZ (          // 수업 구조: 시계용 (항상 흐름)
        .clk     (clk),
        .rst     (rst),
        .run_stop(1'b1),
        .clear   (1'b0),
        .o_tick  (w_tick_10ms)
    );
    wire w_tick_sw, w_tick_tm;
    tick_gen_100hz U_TICK_GEN_SW (              // 수업 구조: 스톱워치용
        .clk     (clk),
        .rst     (rst),
        .run_stop(w_run_stop),
        .clear   (w_clear),
        .o_tick  (w_tick_sw)
    );
    tick_gen_100hz U_TICK_GEN_TM (              // 수업 구조: 타이머용
        .clk     (clk),
        .rst     (rst),
        .run_stop(w_tm_run),
        .clear   (1'b0),
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
