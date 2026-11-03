`timescale 1ns / 1ps
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
