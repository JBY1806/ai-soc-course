`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/12 16:26:35
// Design Name: 
// Module Name: btn_debounce
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module btn_debounce (
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);
    reg [7:0] q_reg;
    wire debounce;  //debounced
    reg edge_reg;

    // 8bit shift register: SIPO
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            q_reg <= 8'h0;
        end else begin
            q_reg <= {i_btn, q_reg[7:1]}; // right shift. (쉬프트 연산자 써도 됨.), msb : in, 7:1 -> 6:0
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

    //rising edge, tick gen
    assign o_btn = ~edge_reg & debounce;


endmodule
