`timescale 1ns / 1ps

// 100hz(10ms) tick 생성기 — top 에서 한 번만 인스턴스해서 스톱워치·시계·타이머에 공급
// (v2) 상수로 묶여 있던 run_stop(1) · clear(0) 포트 삭제 → 항상 흐름 (동작 동일)
// o_tick_10ms : 100 MHz 클럭 1,000,000 개마다 1 클럭(10 ns) 펄스 → 주기 10 ms
module tick_gen_100hz (
    input      i_clk,
    input      i_rst,
    input      i_tick_4khz,   // PPA after: 4 kHz tick 40 번 = 100 Hz
    output reg o_tick_10ms
);

    parameter F_COUNT = 4000 / 100;   // 40

    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
            counter_reg <= 0;
            o_tick_10ms <= 1'b0;
        end else if (i_tick_4khz) begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                o_tick_10ms <= 1'b1;
            end else begin
                o_tick_10ms <= 1'b0;
            end
        end else begin
            o_tick_10ms <= 1'b0;
        end
    end

endmodule
