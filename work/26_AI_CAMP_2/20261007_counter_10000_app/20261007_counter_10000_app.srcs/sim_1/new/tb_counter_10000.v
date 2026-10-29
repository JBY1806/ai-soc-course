`timescale 1ns / 1ps

module tb_counter_10000 ();

    reg clk, reset;
    reg run_stop, clear, up_down;  // 추가: 스위치 3개
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;

    counter_10000 dut (
        .clk(clk),
        .reset(reset),
        .run_stop(run_stop),
        .clear(clear),
        .up_down(up_down),
        .fnd_com(fnd_com),
        .fnd_font(fnd_font)
    );

    // 시뮬레이션에서만 tick 을 10 클럭(100 ns)마다 -> 설계 파일의 10_000_000
    defparam dut.U_COUNTER_DATAPATH.U_TICK_GEN.F_COUNT = 10;

    // gen 100MHz clock
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        run_stop = 0;
        clear = 0;
        up_down = 0;
        #10;
        reset   = 0;

        // 1. up : clear -> 9900, run -> 9999 -> 0
        up_down = 0;
        clear   = 1;
        #20;
        clear = 0;
        run_stop = 1;
        #(110 * 100);  // tick 약 110번 -> 9999 -> 0 을 지나 10 근처

        // 2. stop : 값 유지
        run_stop = 0;
        #(10 * 100);  // 1 us 동안 멈춤
        run_stop = 1;
        #(5 * 100);  // 다시 run

        // 3. down : clear -> 0, run -> 9999 -> 9998 ...
        up_down = 1;
        clear   = 1;
        #20;
        clear = 0;
        #(10 * 100);  // 0 -> 9999 -> 9998 ...

        $stop;
    end

endmodule
