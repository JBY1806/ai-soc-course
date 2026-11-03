`timescale 1ns / 1ps
// =====================================================================
// verif_2 Top TB (E14) : stopwatch_watch 실제 파라미터 그대로
//   100 MHz, tick_gen_100hz F_COUNT 1,000,000 (10 ms), 4 kHz 디바운서 8칸 (약 2 ms)
//   시나리오 길이 약 40 ms (1초 이하)
// 점수 대상은 watch_control_unit · watch_datapath 와 그 입출력 경로.
// U+D · L+R 동시 누름은 Top 의 w_btn_multi(정안성 담당, 10/18 팀 결정) 동작이라 INFO 로만 기록.
// 수업 문법만 : reg/wire, initial, always, if, #, @(negedge clk), $display
// =====================================================================
module tb_e14_top;
    reg clk, rst, btn_R, btn_L, btn_U, btn_D;
    reg mode_sw0, display_mode_sw1, set_sw2, hour24_sw3, timer_sw4;
    wire [3:0]  fnd_com;
    wire [7:0]  fnd_font;
    wire [15:0] led;

    integer err, e0, n_up, n_down, n_tick, n_multi, t_tick1, t_tick2, t_press, t_pulse;
    integer up0, down0, multi0;
    reg [5:0] min_s;
    reg [4:0] hour_s;
    reg [1:0] cur_s;

    stopwatch_watch dut (
        .clk             (clk),
        .rst             (rst),
        .btn_R           (btn_R),
        .btn_L           (btn_L),
        .btn_U           (btn_U),
        .btn_D           (btn_D),
        .mode_sw0        (mode_sw0),
        .display_mode_sw1(display_mode_sw1),
        .set_sw2         (set_sw2),
        .hour24_sw3      (hour24_sw3),
        .timer_sw4       (timer_sw4),
        .fnd_com         (fnd_com),
        .fnd_font        (fnd_font),
        .led             (led)
    );

    always #5 clk = ~clk;   // 100 MHz (줄이지 않음)

    always @(posedge clk) begin
        if (rst === 1'b0) begin
            if (dut.w_wt_up === 1'b1) begin
                n_up = n_up + 1;
                if (n_up == 1) t_pulse = $time;
            end
            if (dut.w_wt_down === 1'b1) n_down = n_down + 1;
            if (dut.w_btn_multi === 1'b1) n_multi = n_multi + 1;
            if (dut.w_tick_10ms === 1'b1) begin
                n_tick = n_tick + 1;
                if (n_tick == 1) t_tick1 = $time;
                if (n_tick == 2) t_tick2 = $time;
            end
        end
    end

    initial begin
        clk = 0; rst = 1;
        btn_R = 0; btn_L = 0; btn_U = 0; btn_D = 0;
        mode_sw0 = 0; display_mode_sw1 = 0; set_sw2 = 1; hour24_sw3 = 1; timer_sw4 = 0;   // 시계 화면, 설정 모드
        err = 0; n_up = 0; n_down = 0; n_tick = 0; n_multi = 0; t_tick1 = 0; t_tick2 = 0; t_pulse = 0;
        #100;

        // (a) 리셋 해제 직후 U (디바운스 실제 값) -> 펄스 1개, 12:01
        //     근거 02:22 진입 분 일, 02:25 U +1, 02:37 디바운서 8칸 = 2 ms
        e0 = err;
        @(negedge clk) rst = 0; btn_U = 1; t_press = $time;
        #3_000_000;
        @(negedge clk) btn_U = 0;
        #3_000_000;
        @(negedge clk);
        if (dut.U_WATCH_CONTROL_UNIT.c_state !== 2'b11 || dut.w_wt_cursor !== 2'd0) begin
            err = err + 1; $display("E14a FAIL state %b cursor %0d exp 11 0", dut.U_WATCH_CONTROL_UNIT.c_state, dut.w_wt_cursor);
        end
        if (n_up !== 1 || n_down !== 0 || dut.w_wt_min !== 6'd1 || dut.w_wt_hour !== 5'd12) begin
            err = err + 1; $display("E14a FAIL up %0d down %0d time %0d:%0d exp 1 0 12:01", n_up, n_down, dut.w_wt_hour, dut.w_wt_min);
        end
        if (t_pulse - t_press <= 1_750_000 || t_pulse - t_press > 2_250_000) begin
            err = err + 1; $display("E14a FAIL press->pulse %0d ns, exp 1.75~2.25 ms (8 samples x 250 us)", t_pulse - t_press);
        end
        $display("E14a INFO press %0d ns -> wt_up pulse %0d ns (delay %0d ns)", t_press, t_pulse, t_pulse - t_press);
        if (err == e0) $display("RESULT E14a PASS"); else $display("RESULT E14a FAIL");

        // (b) U + D 같은 순간 누름 (INFO, Top 경로)
        min_s = dut.w_wt_min; hour_s = dut.w_wt_hour; up0 = n_up; down0 = n_down; multi0 = n_multi;
        @(negedge clk) btn_U = 1; btn_D = 1;
        #3_000_000;
        @(negedge clk) btn_U = 0; btn_D = 0;
        #3_000_000;
        @(negedge clk);
        $display("E14b INFO Top U+D: w_btn_multi pulses %0d, wt_up %0d, wt_down %0d, time %0d:%0d -> %0d:%0d (02:27 says U -> +1; Top 10/18 ignores all)",
                 n_multi - multi0, n_up - up0, n_down - down0, hour_s, min_s, dut.w_wt_hour, dut.w_wt_min);

        // (c) L + R 같은 순간 누름 (INFO, Top 경로)
        cur_s = dut.w_wt_cursor; multi0 = n_multi;
        @(negedge clk) btn_L = 1; btn_R = 1;
        #3_000_000;
        @(negedge clk) btn_L = 0; btn_R = 0;
        #3_000_000;
        @(negedge clk);
        $display("E14c INFO Top L+R: w_btn_multi pulses %0d, cursor %0d -> %0d (02:27 says L -> 1; Top 10/18 ignores all)",
                 n_multi - multi0, cur_s, dut.w_wt_cursor);

        // (d) L 하나 -> cursor 1, U 하나 -> 분 +10 (실제 디바운스 경로)
        //     근거 02:24 L 왼쪽 자리, 02:25 분 십 +10
        e0 = err;
        min_s = dut.w_wt_min;
        @(negedge clk) btn_L = 1;
        #3_000_000;
        @(negedge clk) btn_L = 0;
        #3_000_000;
        @(negedge clk);
        if (dut.w_wt_cursor !== 2'd1 || dut.U_WATCH_CONTROL_UNIT.c_state !== 2'b10) begin
            err = err + 1; $display("E14d FAIL L: cursor %0d state %b exp 1 10", dut.w_wt_cursor, dut.U_WATCH_CONTROL_UNIT.c_state);
        end
        @(negedge clk) btn_U = 1;
        #3_000_000;
        @(negedge clk) btn_U = 0;
        #3_000_000;
        @(negedge clk);
        if (dut.w_wt_min !== min_s + 6'd10 || dut.w_wt_hour !== 5'd12) begin
            err = err + 1; $display("E14d FAIL U at SET_MIN_10: %0d:%0d exp 12:%0d", dut.w_wt_hour, dut.w_wt_min, min_s + 10);
        end
        if (err == e0) $display("RESULT E14d PASS"); else $display("RESULT E14d FAIL");

        // (e) sw2 내림 -> NORMAL, 그 뒤 U 는 무시
        //     근거 02:22 sw2 = 0 일반, 02:23 NORMAL cursor 3
        e0 = err;
        min_s = dut.w_wt_min; up0 = n_up;
        @(negedge clk) set_sw2 = 0;
        @(negedge clk) btn_U = 1;
        #3_000_000;
        @(negedge clk) btn_U = 0;
        #3_000_000;
        @(negedge clk);
        if (dut.U_WATCH_CONTROL_UNIT.c_state !== 2'b00 || dut.w_wt_cursor !== 2'd3 || dut.w_wt_min !== min_s || n_up !== up0) begin
            err = err + 1; $display("E14e FAIL NORMAL + U: state %b cursor %0d min %0d->%0d up pulses +%0d", dut.U_WATCH_CONTROL_UNIT.c_state, dut.w_wt_cursor, min_s, dut.w_wt_min, n_up - up0);
        end
        if (err == e0) $display("RESULT E14e PASS"); else $display("RESULT E14e FAIL");

        // (f) 시계 tick 주기 10 ms, 1/100초 · 초가 tick 수와 맞음
        //     근거 02:21 100 Hz tick 으로 항상 흐름, 01:23 기본 tick 100 Hz
        e0 = err;
        if (t_tick2 - t_tick1 !== 10_000_000) begin
            err = err + 1; $display("E14f FAIL tick period %0d ns exp 10,000,000", t_tick2 - t_tick1);
        end
        if (dut.w_wt_sec * 100 + dut.w_wt_msec !== n_tick) begin
            err = err + 1; $display("E14f FAIL sec.msec %0d.%0d vs ticks %0d", dut.w_wt_sec, dut.w_wt_msec, n_tick);
        end
        $display("E14f INFO first tick %0d ns, second %0d ns, period %0d ns, ticks %0d, watch sec.msec %0d.%0d at %0t",
                 t_tick1, t_tick2, t_tick2 - t_tick1, n_tick, dut.w_wt_sec, dut.w_wt_msec, $time);
        if (err == e0) $display("RESULT E14f PASS"); else $display("RESULT E14f FAIL");

        $display("TOTAL MISMATCH = %0d", err);
        $finish;
    end
endmodule
