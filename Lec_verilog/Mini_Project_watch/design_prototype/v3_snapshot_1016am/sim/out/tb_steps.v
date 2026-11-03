`timescale 1ns / 1ps
module tb_steps;
    reg clk=0, rst=1, btnR=0, btnL=0, btnU=0, btnD=0, sw_mode=0, sw_display_mode=0, sw_set=0, sw_12h=0;
    wire [3:0] fnd_com; wire [7:0] fnd_font; wire [4:0] led;
    parameter PUSH = 20_000;
    defparam dut.U_WATCH_DATAPATH.U_TICK_GEN_100HZ.F_COUNT = 100;
    defparam dut.U_STOPWATCH_DATAPATH.U_TICK_GEN_100HZ.F_COUNT = 100;
    stopwatch_watch dut(.clk(clk),.rst(rst),.btnR(btnR),.btnL(btnL),.btnU(btnU),.btnD(btnD),.sw_mode(sw_mode),.sw_display_mode(sw_display_mode),.sw_set(sw_set),.sw_12h(sw_12h),.fnd_com(fnd_com),.fnd_font(fnd_font),.led(led));
    always #5 clk = ~clk;
    integer i, nb;
    initial begin
        #100 rst = 0; #100;
        sw_display_mode = 1; #1000;                     // 3
        sw_set = 1; #1000;                              // 4
        btnU=1;#PUSH;btnU=0;#PUSH; btnD=1;#PUSH;btnD=0;#PUSH; btnD=1;#PUSH;btnD=0;#PUSH; btnU=1;#PUSH;btnU=0;#PUSH; // 5
        btnR=1;#PUSH;btnR=0;#PUSH;                      // 6
        btnD=1;#PUSH;btnD=0;#PUSH; btnU=1;#PUSH;btnU=0;#PUSH;   // 7
        btnU=1;#PUSH;btnU=0;#PUSH; btnU=1;#PUSH;btnU=0;#PUSH; btnU=1;#PUSH;btnU=0;#PUSH; // 8
        btnR=1;#PUSH;btnR=0;#PUSH;                      // 9
        $display("after9: cursor=%0d %0d:%0d:%0d", dut.w_cursor, dut.w_wt_hour, dut.w_wt_min, dut.w_wt_sec);
        sw_display_mode = 0; #1000;                     // 10
        nb = 0;
        for (i=0;i<400;i=i+1) begin #250; if (dut.U_FND_CNTL.w_blank_sec) nb = nb + 1; end
        $display("step10: blank_sec high in %0d/400 samples (expect ~200)", nb);
        $display("before11 sec=%0d", dut.w_wt_sec);
        btnU=1;#PUSH;btnU=0;#PUSH; btnU=1;#PUSH;btnU=0;#PUSH;   // 11
        $display("after11 sec=%0d (expect +2 plus natural ticks)", dut.w_wt_sec);
        $finish;
    end
endmodule
