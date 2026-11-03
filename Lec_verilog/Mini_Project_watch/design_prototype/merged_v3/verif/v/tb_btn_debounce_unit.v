`timescale 1ns / 1ps
// [검증 TB] 팀 디바운서(btn_debounce + clock_tick_generator 4 kHz) — 실제 시간 그대로
// 요구: 누름 한 번 = o_btn 1클럭 펄스 한 번. 튐(bounce)은 걸러야 한다.
// 판정: 요구와 다르면 MISMATCH, "지금 구조상 그렇게 될 수밖에 없는 것"은 DEVIATION 으로 따로 센다.
module tb_btn_debounce_unit ();
    reg clk, rst, i_btn;
    wire w_tick_4k, o_btn;

    clock_tick_generator #(.CLK_FRQ(4000)) U_GEN (.i_clk(clk), .i_reset(rst), .o_clk(w_tick_4k));
    btn_debounce U_DUT (.clk_remake(w_tick_4k), .clk(clk), .reset(rst), .i_btn(i_btn), .o_btn(o_btn));

    always #5 clk = ~clk;

    integer err, dev, n_pulse, k, seed, t_hi;
    reg o_btn_d;
    // 펄스 개수 세기 + 폭 검사 (2클럭 연속 1 이면 bug)
    always @(posedge clk) begin
        o_btn_d <= o_btn;
        if (o_btn) n_pulse = n_pulse + 1;
        if (o_btn && o_btn_d) begin err = err + 1; $display("FAIL o_btn wider than 1 clk at %0t", $time); end
    end

    // 튐: 50~400 us 조각을 n 번 토글 (모두 2 ms 창보다 짧음)
    // (task 안 쓰고 반복문으로)
    initial begin
        clk = 0; rst = 1; i_btn = 0; err = 0; dev = 0; n_pulse = 0; o_btn_d = 0; seed = 3;
        #100 rst = 0;
        #20_000_000;   // 20 ms 안정

        // S1 깨끗한 20 ms 누름 -> 1
        n_pulse = 0; i_btn = 1; #20_000_000; i_btn = 0; #20_000_000;
        if (n_pulse !== 1) begin err = err + 1; $display("S1 FAIL clean press: %0d pulses", n_pulse); end
        else $display("S1 ok clean 20 ms press -> 1 pulse");

        // S2 누를 때 튐 3 ms(조각 50~400 us) 뒤 20 ms 유지 -> 1
        n_pulse = 0;
        for (k = 0; k < 12; k = k + 1) begin
            i_btn = ~i_btn; #(50_000 + ($unsigned($random(seed)) % 350_000));
        end
        i_btn = 1; #20_000_000; i_btn = 0; #20_000_000;
        if (n_pulse !== 1) begin err = err + 1; $display("S2 FAIL press bounce: %0d pulses", n_pulse); end
        else $display("S2 ok press-bounce -> 1 pulse");

        // S3 20 ms 유지 뒤 뗄 때 튐 3 ms -> 1 (뗄 때 1 조각이 2 ms 미만이면 재인식 없어야)
        n_pulse = 0; i_btn = 1; #20_000_000;
        for (k = 0; k < 12; k = k + 1) begin
            i_btn = ~i_btn; #(50_000 + ($unsigned($random(seed)) % 350_000));
        end
        i_btn = 0; #20_000_000;
        if (n_pulse !== 1) begin err = err + 1; $display("S3 FAIL release bounce: %0d pulses", n_pulse); end
        else $display("S3 ok release-bounce -> 1 pulse");

        // S4 1 ms 짧은 누름(4 샘플) -> 0
        n_pulse = 0; i_btn = 1; #1_000_000; i_btn = 0; #20_000_000;
        if (n_pulse !== 0) begin err = err + 1; $display("S4 FAIL 1 ms press: %0d pulses", n_pulse); end
        else $display("S4 ok 1 ms press -> 0 (window 2 ms)");

        // S5 2.5 ms 누름(10 샘플) -> 1
        n_pulse = 0; i_btn = 1; #2_500_000; i_btn = 0; #20_000_000;
        if (n_pulse !== 1) begin err = err + 1; $display("S5 FAIL 2.5 ms press: %0d pulses", n_pulse); end
        else $display("S5 ok 2.5 ms press -> 1");

        // S6 누른 채 0.3 ms 끊김 한 번 (요구: 1번) — 지금 구조(8칸 AND, 히스테리시스 없음)는 2번
        n_pulse = 0; i_btn = 1; #20_000_000; i_btn = 0; #300_000; i_btn = 1; #20_000_000; i_btn = 0; #20_000_000;
        if (n_pulse !== 1) begin dev = dev + 1; $display("S6 DEVIATION held press with 0.3 ms dropout: %0d pulses (requirement 1) -> TS-40 hysteresis", n_pulse); end
        else $display("S6 ok dropout -> 1");

        // S7 20 ms 누름, 5 ms 간격, 20 ms 누름 -> 2
        n_pulse = 0; i_btn = 1; #20_000_000; i_btn = 0; #5_000_000; i_btn = 1; #20_000_000; i_btn = 0; #20_000_000;
        if (n_pulse !== 2) begin err = err + 1; $display("S7 FAIL two presses: %0d pulses", n_pulse); end
        else $display("S7 ok two presses 5 ms apart -> 2");

        // S8 안 누른 상태의 100 us 잡음 -> 0
        n_pulse = 0; i_btn = 1; #100_000; i_btn = 0; #20_000_000;
        if (n_pulse !== 0) begin err = err + 1; $display("S8 FAIL glitch: %0d pulses", n_pulse); end
        else $display("S8 ok 100 us glitch -> 0");

        // S9 누름 중 reset -> 펄스 없음, 떼고 다시 누르면 1
        n_pulse = 0; i_btn = 1; #5_000_000; rst = 1; #1000; rst = 0; #20_000_000;
        // reset 뒤에도 누른 채라 8 샘플 뒤 다시 1 펄스 (시프트가 0 으로 비워졌다가 다시 참) -> 구조상 1번 더
        $display("S9 info: reset while held -> %0d pulse(s) after reset (structure: shift cleared then refilled)", n_pulse);
        i_btn = 0; #20_000_000;

        // S10 o_btn 지연: 누른 순간부터 펄스까지 = 8 샘플 (약 2 ms, 샘플 위상에 따라 +0.25 ms)
        n_pulse = 0; t_hi = $time; i_btn = 1;
        @(posedge o_btn);
        if (($time - t_hi) < 1_750_000 || ($time - t_hi) > 2_260_000) begin err = err + 1; $display("S10 FAIL latency %0d ns", $time - t_hi); end
        else $display("S10 ok latency %0d ns (8 samples x 250 us, +phase)", $time - t_hi);
        #20_000_000; i_btn = 0; #20_000_000;

        $display("TOTAL MISMATCH = %0d, DEVIATION = %0d", err, dev);
        $finish;
    end
endmodule
