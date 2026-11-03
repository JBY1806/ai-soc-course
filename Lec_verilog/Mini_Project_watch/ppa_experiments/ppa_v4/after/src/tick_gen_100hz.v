`timescale 1ns / 1ps

// 100hz(10ms) tick 생성기 — top 에서 한 번만 인스턴스해서 스톱워치·시계·타이머에 공급
module tick_gen_100hz (
    input clk,
    input rst,
    input i_tick_4k,   // PPA after: 4 kHz tick 을 40 번 세서 100 Hz
    input run_stop,
    input clear,
    output reg o_tick
);

    parameter F_COUNT = 4000 / 100;   // 40

    reg [$clog2(F_COUNT)-1:0] counter_reg;



    always @(posedge clk, posedge rst) begin
        if (rst | clear) begin
            counter_reg <= 0;
            o_tick <= 1'b0;
        end else begin
            if (run_stop & i_tick_4k) begin
                counter_reg <= counter_reg + 1;
                if (counter_reg == F_COUNT - 1) begin
                    counter_reg <= 0;
                    o_tick <= 1'b1;
                end else begin
                    o_tick <= 1'b0;
                end
            end else begin
                o_tick <= 1'b0;
            end
        end
    end


endmodule
