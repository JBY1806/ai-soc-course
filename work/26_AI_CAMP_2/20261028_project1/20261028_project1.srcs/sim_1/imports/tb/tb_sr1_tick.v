`timescale 1ns / 1ps
// 1 단계 : 1 us tick 생성기 — tick 이 100 클럭마다 1 클럭씩 나오는지
//  (1) 첫 tick 시각 · (2) tick 사이 간격 100 클럭 (1,000 ns) · (3) tick 폭 1 클럭 · (4) 10 us 동안 tick 10 개
module tb_sr1_tick ();
    reg clk, rst;
    wire w_tick;
    integer err, n_tick;
    time t_prev, t_now;

    tick_gen_1us #(.F_COUNT(100)) dut (
        .clk   (clk),
        .rst   (rst),
        .o_tick(w_tick)
    );

    always #5 clk = ~clk;

    // tick 이 1 인 클럭을 상승 엣지에서 셈 + 간격 검사
    always @(posedge clk) begin
        if (w_tick === 1'b1) begin
            n_tick = n_tick + 1;
            t_now  = $time;
            if (n_tick > 1 && (t_now - t_prev) !== 1000) begin
                err = err + 1;
                $display("%t (2) MISMATCH tick 간격 %0d ns (expect 1000)", $time, t_now - t_prev);
            end
            t_prev = t_now;
        end
    end

    initial begin
        clk = 0; rst = 1; err = 0; n_tick = 0; t_prev = 0;
        #10 rst = 0;
        @(posedge w_tick);
        $display("%t (1) 첫 tick", $time);
        @(negedge clk);
        if (w_tick !== 1'b1) begin err = err + 1; $display("%t (3) MISMATCH tick 폭이 1 클럭보다 짧음", $time); end
        @(negedge clk);
        if (w_tick !== 1'b0) begin err = err + 1; $display("%t (3) MISMATCH tick 폭이 1 클럭보다 김", $time); end
        n_tick = 0;
        #10_000;
        if (n_tick !== 10) begin err = err + 1; $display("%t (4) MISMATCH 10 us 동안 tick %0d 개 (expect 10)", $time, n_tick); end
        else $display("%t (4) 10 us 동안 tick %0d 개", $time, n_tick);
        $display("TOTAL MISMATCH = %0d", err);
        $stop;
    end
endmodule
