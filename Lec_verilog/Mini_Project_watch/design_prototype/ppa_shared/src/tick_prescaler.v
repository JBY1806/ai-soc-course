`timescale 1ns / 1ps

// PPA 판 (): 100 MHz 를 세는 카운터를 여기 하나만 둔다.
// 2 kHz tick(500 us 마다 1클럭) -> 디바운서 4개 · tick_gen 3개 · FND 스캔이 같이 씀
module tick_prescaler #(
    parameter F_COUNT = 100_000_000 / 2_000
) (
    input      clk,
    input      rst,
    output reg o_tick
);
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            o_tick      <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                o_tick      <= 1'b1;
            end else begin
                o_tick <= 1'b0;
            end
        end
    end
endmodule
