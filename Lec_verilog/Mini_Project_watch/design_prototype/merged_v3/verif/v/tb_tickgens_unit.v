`timescale 1ns / 1ps
// [검증 TB] tick_gen_100hz · clock_tick_generator — 실제 파라미터로 주기 · 폭 · run_stop · clear 확인
module tb_tickgens_unit ();
    reg clk, rst, run_stop, clear;
    wire t100, t4k;

    tick_gen_100hz U_T100 (.clk(clk), .rst(rst), .run_stop(run_stop), .clear(clear), .o_tick(t100));
    clock_tick_generator #(.CLK_FRQ(4000)) U_T4K (.i_clk(clk), .i_reset(rst), .o_clk(t4k));

    always #5 clk = ~clk;

    integer err, t_prev, n, i;
    reg t100_d, t4k_d;
    always @(posedge clk) begin
        t100_d <= t100; t4k_d <= t4k;
        if (t100 && t100_d) begin err = err + 1; $display("FAIL t100 wider than 1 clk"); end
        if (t4k && t4k_d) begin err = err + 1; $display("FAIL t4k wider than 1 clk"); end
    end

    initial begin
        clk = 0; rst = 1; run_stop = 1; clear = 0; err = 0; t100_d = 0; t4k_d = 0;
        #100 rst = 0;
        // 4 kHz: 연속 5 펄스 간격 = 250,000 ns
        @(posedge t4k); t_prev = $time;
        for (i = 0; i < 5; i = i + 1) begin
            @(posedge t4k);
            if ($time - t_prev !== 250_000) begin err = err + 1; $display("FAIL t4k period %0d", $time - t_prev); end
            t_prev = $time;
        end
        $display("4 kHz tick period ok (250,000 ns)");
        // 100 Hz: 첫 tick 은 리셋 해제 후 10 ms, 이후 10 ms 간격 3번
        @(posedge t100); t_prev = $time;
        if (t_prev < 10_000_000 || t_prev > 10_000_200) begin err = err + 1; $display("FAIL first t100 at %0d", t_prev); end
        for (i = 0; i < 3; i = i + 1) begin
            @(posedge t100);
            if ($time - t_prev !== 10_000_000) begin err = err + 1; $display("FAIL t100 period %0d", $time - t_prev); end
            t_prev = $time;
        end
        $display("100 Hz tick period ok (10,000,000 ns)");
        // run_stop = 0 이면 5 ms 동안 tick 없음, 다시 1 이면 멈춘 곳부터 이어서(남은 5 ms 뒤 tick)
        @(posedge t100); t_prev = $time;
        #4_995_000 run_stop = 0; n = 0;
        repeat (500_000) @(posedge clk) if (t100) n = n + 1;   // 5 ms
        if (n !== 0) begin err = err + 1; $display("FAIL tick while run_stop=0: %0d", n); end
        run_stop = 1;
        @(posedge t100);
        if ($time - t_prev < 14_990_000 || $time - t_prev > 15_010_000) begin err = err + 1; $display("FAIL resume phase: %0d ns since last tick (expect ~15 ms = 10 ms + 5 ms pause)", $time - t_prev); end
        else $display("run_stop pause/resume ok (counter holds phase)");
        // clear: 카운터 0 으로 -> 다음 tick 은 정확히 10 ms 뒤
        #3_000_000; clear = 1; #10; clear = 0; t_prev = $time;
        @(posedge t100);
        if ($time - t_prev < 9_990_000 || $time - t_prev > 10_010_000) begin err = err + 1; $display("FAIL after clear: %0d ns", $time - t_prev); end
        else $display("clear restarts phase ok");
        $display("TOTAL MISMATCH = %0d", err);
        $finish;
    end
endmodule
