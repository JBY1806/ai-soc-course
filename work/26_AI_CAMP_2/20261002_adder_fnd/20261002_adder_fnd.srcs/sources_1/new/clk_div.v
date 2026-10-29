`timescale 1ns / 1ps

module clk_div #(
    parameter PERIOD = 125_000,  // 출력 1주기 = 입력 클럭 수 (100 MHz / 800 Hz)
    parameter HIGH   = 62_500    // 그중 High 구간 클럭 수 (duty = HIGH : PERIOD - HIGH)
) (
    input      clk,
    input      reset,
    output reg o_clk
);

    reg [$clog2(PERIOD)-1:0] counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            o_clk       <= 1'b0;
        end else begin
            if (counter_reg == PERIOD - 1) counter_reg <= 0;
            else counter_reg <= counter_reg + 1;

            if (counter_reg == PERIOD - HIGH - 1) o_clk <= 1'b1;  // Low 구간 끝 -> High
            else if (counter_reg == PERIOD - 1) o_clk <= 1'b0;  // 한 주기 끝 -> Low
        end
    end

endmodule