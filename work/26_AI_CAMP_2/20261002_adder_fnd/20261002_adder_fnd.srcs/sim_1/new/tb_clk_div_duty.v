`timescale 1ns / 1ps

module tb_clk_div_duty ();

    reg clk, reset;
    wire o_1_1, o_1_2, o_2_1, o_1_4, o_4_1;

    clk_div #(
        .PERIOD(125_000),
        .HIGH  (62_500)
    ) U_DUTY_1_1 (
        .clk  (clk),
        .reset(reset),
        .o_clk(o_1_1)
    );

    clk_div #(
        .PERIOD(124_998),
        .HIGH  (41_666)
    ) U_DUTY_1_2 (
        .clk  (clk),
        .reset(reset),
        .o_clk(o_1_2)
    );  // 124,998 = 3 x 41,666

    clk_div #(
        .PERIOD(124_998),
        .HIGH  (83_332)
    ) U_DUTY_2_1 (
        .clk  (clk),
        .reset(reset),
        .o_clk(o_2_1)
    );
    
    clk_div #(
        .PERIOD(125_000),
        .HIGH  (25_000)
    ) U_DUTY_1_4 (
        .clk  (clk),
        .reset(reset),
        .o_clk(o_1_4)
    );

    clk_div #(
        .PERIOD(125_000),
        .HIGH  (100_000)
    ) U_DUTY_4_1 (
        .clk  (clk),
        .reset(reset),
        .o_clk(o_4_1)
    );

    always #5 clk = ~clk;  // 100 MHz, duty 1:1

    initial begin
        clk   = 0;
        reset = 0;
        #1 reset = 1;
        #10 reset = 0;
        #(250_000 * 10);  // 250,000 클럭 = 2.5 ms = 출력 2주기
        #100;
        $finish;
    end

endmodule
