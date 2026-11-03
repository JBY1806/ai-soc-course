`timescale 1ns / 1ps

// PPA 판 (): 수업 btn_debounce 에서 분주 카운터를 빼고 공통 2 kHz tick(i_tick)을 받음.
// 시프트는 clk(100 MHz) 로 돌되 i_tick 일 때만 한 칸 -> 수업 판(posedge clk_1mhz)과 같은 시점에 읽음, 파생 클럭 없음
module btn_debounce (
    input  clk,
    input  reset,
    input  i_tick,
    input  i_btn,
    output o_btn
);
    reg [7:0] q_reg;
    wire debounce;
    reg edge_reg;

    // 8bit shift register: SIPO (i_tick 일 때만)
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            q_reg <= 8'h0;
        end else if (i_tick) begin
            q_reg <= {i_btn, q_reg[7:1]};
        end
    end

    // 8-input AND gate
    assign debounce = &q_reg;

    // edge detection
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            edge_reg <= 1'b0;
        end else begin
            edge_reg <= debounce;
        end
    end

    assign o_btn = ~edge_reg & debounce;
endmodule
