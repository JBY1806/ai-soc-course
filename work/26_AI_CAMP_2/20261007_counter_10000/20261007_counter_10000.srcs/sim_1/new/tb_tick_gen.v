`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/07 12:57:03
// Design Name: 
// Module Name: tb_tick_gen
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


module tb_tick_gen();

reg clk, reset;
wire o_tick;

tick_gen DUT(
    .clk(clk),
    .reset(reset),
    .o_tick(o_tick)
);

always #5 clk = ~clk;

initial begin
    clk = 0;    
    reset = 1;

    #10;

    reset = 0;
    #1000000;
    #50;
    $finish;
end

endmodule
