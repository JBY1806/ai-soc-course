`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/11 21:26:14
// Design Name: 
// Module Name: tb_led_fsm_1
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


module tb_led_fsm_1 ();
    reg clk, reset;
    reg  [1:0] sw;
    wire [2:0] led;


    led_fsm_1 dut (
        .clk(clk),
        .reset(reset),
        .sw(sw),
        .led(led)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        sw = 2'b00;  // 리셋하면 S0

        #10 reset = 0;  // 리셋 풀어도 그대로

        #30
        sw = 2'b10;  // 시각 40ns, 상태 S0 그대로. S0는 01에만 반응.

        #30 sw = 2'b01;  // 시각 70ns, 75ns에서 S1 / 001 (S0->S1)

        #30 sw = 2'b11;  // 시각 100ns, S1 그대로. S1는 10에만 반응

        #30 sw = 2'b10;  // 시각 130 ns, 135에서 S2 / 010 (S1 -> S2)

        #30 sw = 2'b00;  // 시각 160 ns. s2 그대로. s2는 11에만 반응

        #30 sw = 2'b11;  // 시각 190ns. 195ns에서 S3 / 100 (S2 -> S3)

        #30 sw = 2'b10;  // 시각 220ns. 225ns S4 / 111 (S3 -> S4)

        #30 sw = 2'b01;  // 시각 250ns. S4 (S4는 00에만 반응)

        #30 sw = 2'b00;  // 시각 280ns. 285ns S0 / 000 (S4 -> S0)

        //S3의 다른 출구를 보러 다시 올라감.
        #30 sw = 2'b01;  // 시각 310ns. 315ns S1 
        #30 sw = 2'b10;  // 시각 340ns. 345ns S2 
        #30 sw = 2'b11;  // 시각 370ns. 375ns S3 
        #30 sw = 2'b00;  // 시각 400ns. 405ns S0 (S3->S0)

        //S3의 다른 출구를 보러 다시 올라감.
        #30 sw = 2'b01;  //S1
        #30 sw = 2'b10;  //S2
        #30 sw = 2'b11;  //S3
        #30 sw = 2'b01;  // 시각 520ns. 525ns S1 (S3->S1)

        #30 sw = 2'b10;  // 555ns S2

        #30 reset = 1;  // 580 ns 바로 S0

        #10 reset = 0;  // S0 그대로 (S0는 01에만 반응)

        #30;

        $stop;




    end


endmodule
