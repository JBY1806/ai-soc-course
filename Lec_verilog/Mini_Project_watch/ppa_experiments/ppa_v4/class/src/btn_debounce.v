`timescale 1ns / 1ps
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
