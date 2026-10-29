`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/12 16:47:44
// Design Name: 
// Module Name: tb_btn_debounce
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


module tb_btn_debounce();

    reg clk, reset, i_btn;
    wire o_btn;

    btn_debounce dut (
    .clk(clk),
    .reset(reset),
    .i_btn(i_btn),
    .o_btn(o_btn)
);

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        i_btn = 0;
        #10 reset = 0;

        // 시나리오 A. o_btn: 145~155 ns, 1번
        #10 i_btn = 1; //20->1
        #10 i_btn = 1;
        #10 i_btn = 0; //40->0
        #10 i_btn = 1; //50->1
        #10 i_btn = 0; //60->0

        #10 i_btn = 1; //70->1

        #100 i_btn = 0; //170->0

        #100; //270ns. 목적: 시나리오 사이에 i_btn = 0 을 100 ns(10클럭) 동안 두는 것이 reset 역할
        // 시나리오 B. o_btn: 없음.
        #10 i_btn = 1; //280->1
        #70 i_btn = 0; //350->0
        
        #100; //450ns. 목적: 시나리오 사이에 i_btn = 0 을 100 ns(10클럭) 동안 두는 것이 reset 역할
        // 시나리오 C. o_btn: 525~535 ns, 1번
        i_btn = 1; //450->1
        #80 i_btn = 0; //530->0
        
        #100; //630ns. 목적: 시나리오 사이에 i_btn = 0 을 100 ns(10클럭) 동안 두는 것이 reset 역할
        // 시나리오 D. o_btn: 705~715 ns, 1번만
        i_btn = 1; //630->1
        #1000 i_btn = 0; //1630->0

        #100; //1730ns. 목적: 시나리오 사이에 i_btn = 0 을 100 ns(10클럭) 동안 두는 것이 reset 역할
        // 시나리오 E. o_btn: 1805, 2015 ns, 2번 (약점)
        i_btn = 1; //1730->1
        #200 i_btn = 0; //1930->0
        #10 i_btn = 1; //1940->1
        #300 i_btn = 0; //2240->0

        #100; //2340ns. 목적: 시나리오 사이에 i_btn = 0 을 100 ns(10클럭) 동안 두는 것이 reset 역할
        // 시나리오 F. o_btn: 2415, 2635 ns, 2번 (약점)
        i_btn = 1; //2340->1
        #200 i_btn = 0; //2540->0
        #20 i_btn = 1; //2560->1
        #90 i_btn = 0; //2650->0

        #100 $stop;

    end


endmodule
