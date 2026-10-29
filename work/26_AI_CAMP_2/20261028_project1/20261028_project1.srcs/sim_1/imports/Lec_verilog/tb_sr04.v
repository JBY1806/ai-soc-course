`timescale 1ns / 1ps

module tb_sr04 ();

    reg clk, rst, sr04_start, echo;
    wire trig;

    top_sr04 dut (
        .clk       (clk),
        .rst       (rst),
        .sr04_start(sr04_start),
        .echo      (echo),
        .trig      (trig)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        sr04_start = 0;
        echo = 0;

        #10;
        rst = 0;
        #10;
        // sr04 start btn
        @(negedge clk);
        sr04_start = 1;
        @(negedge clk);
        sr04_start = 0;          // ← 추가 : 1 클럭 펄스로
        wait (trig == 1);        // ← @(posedge trig) 대신 : 이미 올라가 있어도 바로 통과
        @(negedge trig);

        // monitor, sr04 trigger 

        // start state
        @(posedge trig);
        @(negedge trig);

        #(2000);  // wait state

        echo = 1;  // distance state
        #(600 * 1_000);  // 10cm, 600*1usec

        echo = 0;
        // stop state
        #(10_000_000);
        #(2000);
        $finish;
    end


endmodule
