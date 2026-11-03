`timescale 1ns / 1ps
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
