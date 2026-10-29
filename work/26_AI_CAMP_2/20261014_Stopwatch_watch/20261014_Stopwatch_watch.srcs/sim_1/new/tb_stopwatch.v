`timescale 1ns / 1ps

module tb_stopwatch_datapath ();

    reg clk, rst, run_stop, clear, mode;
    wire [6:0] msec;
    wire [5:0] sec, min;
    wire [4:0] hour;

    parameter MSEC = 100_000*10;

    stopwatch_datapath dut (
        .clk(clk),
        .rst(rst),
        .run_stop(run_stop),
        .clear(clear),
        .mode(mode),
        .msec(msec),
        .sec(sec),
        .min(min),
        .hour(hour)
    );

    // gen 100MHz clock
    always #5 clk = ~clk;

    initial begin
        clk      = 0;
        rst      = 1;
        run_stop = 0;
        clear    = 0;
        mode     = 0;  // up count
        #10 rst = 0;
        #10 run_stop = 1;
        // RUN: 10 ms 마다 msec +1, 1 s 에 msec 99 -> 0 이면서 sec +1


        repeat(1000) #(MSEC); // 50msec
        $stop;
    end

endmodule
