`timescale 1ns / 1ps
// [작성] 시계 파트 최종 시뮬레이션 — DUT = 최상위 stopwatch_watch, 실제 파라미터 그대로 (tick 안 올림)
// 상태도 화살표 A1~A11, 출력 O1~O4, 우선순위 P1~P3, 설정 경계 D6~D8, 점멸 B1, 12/24 H1, 자리 넘김 · 자정 D5, 설정 중 리셋 R1
// 입력은 전부 Top 핀(btnR/L/U/D, sw)으로 넣는다. 버튼 한 번 = 5 ms 누름 + 5 ms 뗌 (디바운스 2 ms 보다 충분히 김)
// 예외 1곳: D5 에서 초 · 1/100초를 "초기값 조정" (59초를 실제로 기다리면 xsim 약 2시간) — 설계 파일 · tick 은 그대로
// 파형: scenario 신호 Radix 를 ASCII 로 바꾸면 지금 몇 번 화살표인지 글자로 보인다
module tb_watch_scenario_top ();
    reg clk, rst, btnR, btnL, btnU, btnD;
    reg sw_mode, sw_display_mode, sw_set, sw_24h, sw_timer;
    wire [3:0]  fnd_com;
    wire [7:0]  fnd_font;
    wire [15:0] led;

    reg [8*20:1] scenario;
    integer err, i, n_up, n_down, n_collide, n_blank_on, n_blank_bad;

    parameter PUSH = 5_000_000;   // 5 ms

    stopwatch_watch dut (
        .clk(clk), .rst(rst), .btnR(btnR), .btnL(btnL), .btnU(btnU), .btnD(btnD),
        .sw_mode(sw_mode), .sw_display_mode(sw_display_mode), .sw_set(sw_set), .sw_24h(sw_24h), .sw_timer(sw_timer),
        .fnd_com(fnd_com), .fnd_font(fnd_font), .led(led));

    always #5 clk = ~clk;

    // 상시 감시: 시계 데이터패스로 들어간 +1/-1 펄스 수, 분 카운터에 tick 과 버튼이 같은 클럭에 온 횟수, 점멸
    always @(posedge clk) begin
        if (dut.w_up)   n_up   = n_up + 1;
        if (dut.w_down) n_down = n_down + 1;
        if (dut.U_WATCH_DATAPATH.w_tick_min && (dut.w_up || dut.w_down)) n_collide = n_collide + 1;
        if (scenario == "B1 BLINK HOUR 1s") begin
            if (dut.FND_CON.w_decode_ds1_hour == 4'hd) begin
                if (dut.w_wt_msec >= 50) n_blank_on = n_blank_on + 1;
                else n_blank_bad = n_blank_bad + 1;
            end
        end
    end

    initial begin
        clk = 0; rst = 1; err = 0; n_up = 0; n_down = 0; n_collide = 0; n_blank_on = 0; n_blank_bad = 0;
        btnR = 0; btnL = 0; btnU = 0; btnD = 0;
        sw_mode = 0; sw_display_mode = 1; sw_set = 0; sw_24h = 0; sw_timer = 0;   // 시계 화면, 시.분 표시
        scenario = "RESET";
        #1000 rst = 0;

        // ===== A1 리셋 -> NORMAL, 12:00, LED0(시계) · LED2(시.분) · LED15(오후) =====
        scenario = "A1 RST->NORMAL"; $display("A1 %0d ms", $time / 1_000_000);
        #PUSH;
        if (dut.w_cursor !== 3 || dut.w_set_mode !== 0) begin err = err + 1; $display("A1 FAIL cursor %0d set_mode %b", dut.w_cursor, dut.w_set_mode); end
        if (dut.w_wt_hour !== 12 || dut.w_wt_min !== 0) begin err = err + 1; $display("A1 FAIL time %0d:%0d", dut.w_wt_hour, dut.w_wt_min); end
        if (led[0] !== 1 || led[2] !== 1 || led[15] !== 1) begin err = err + 1; $display("A1 FAIL led %b", led); end

        // ===== O4 NORMAL 에서 L · U -> 무시 =====
        scenario = "O4 NORMAL L,U X"; $display("O4 %0d ms", $time / 1_000_000);
        btnL = 1; #PUSH; btnL = 0; #PUSH;
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        if (dut.w_cursor !== 3 || dut.w_wt_min !== 0 || n_up !== 0) begin err = err + 1; $display("O4 FAIL cursor %0d min %0d up %0d", dut.w_cursor, dut.w_wt_min, n_up); end

        // ===== A2 sw2 = 1 -> SET_MIN_1 (cursor 0) =====
        scenario = "A2 sw2=1->MIN_1"; $display("A2 %0d ms", $time / 1_000_000);
        sw_set = 1; #PUSH;
        if (dut.w_cursor !== 0 || dut.w_set_mode !== 1) begin err = err + 1; $display("A2 FAIL cursor %0d", dut.w_cursor); end

        // ===== O1 U -> 분 +1, O2 D -> 분 -1 =====
        scenario = "O1 U -> MIN+1"; $display("O1 %0d ms", $time / 1_000_000);
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        if (dut.w_wt_min !== 1) begin err = err + 1; $display("O1 FAIL min %0d", dut.w_wt_min); end
        scenario = "O2 D -> MIN-1"; $display("O2 %0d ms", $time / 1_000_000);
        btnD = 1; #PUSH; btnD = 0; #PUSH;
        if (dut.w_wt_min !== 0) begin err = err + 1; $display("O2 FAIL min %0d", dut.w_wt_min); end

        // ===== O3 U + D 동시에 누름 -> U 만 (분 +1) =====
        scenario = "O3 U+D -> U"; $display("O3 %0d ms", $time / 1_000_000);
        btnU = 1; btnD = 1; #PUSH; btnU = 0; btnD = 0; #PUSH;
        if (dut.w_wt_min !== 1) begin err = err + 1; $display("O3 FAIL min %0d (exp 1)", dut.w_wt_min); end

        // ===== D6 분 일의 자리 경계: 1 -> 0 -> 59 (시 그대로), 59 + 1 -> 0 =====
        scenario = "D6 MIN 0-1, 59+1"; $display("D6 %0d ms", $time / 1_000_000);
        btnD = 1; #PUSH; btnD = 0; #PUSH;
        btnD = 1; #PUSH; btnD = 0; #PUSH;
        if (dut.w_wt_min !== 59 || dut.w_wt_hour !== 12) begin err = err + 1; $display("D6 FAIL 0-1 -> %0d:%0d", dut.w_wt_hour, dut.w_wt_min); end
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        if (dut.w_wt_min !== 0 || dut.w_wt_hour !== 12) begin err = err + 1; $display("D6 FAIL 59+1 -> %0d:%0d", dut.w_wt_hour, dut.w_wt_min); end

        // ===== A3 L: MIN_1 -> MIN_10, D7 분 십 ±10: 0 - 10 -> 50, 50 + 10 -> 0 =====
        scenario = "A3 L MIN_1->MIN_10"; $display("A3 %0d ms", $time / 1_000_000);
        btnL = 1; #PUSH; btnL = 0; #PUSH;
        if (dut.w_cursor !== 1) begin err = err + 1; $display("A3 FAIL cursor %0d", dut.w_cursor); end
        scenario = "D7 MIN10 0-10,+10"; $display("D7 %0d ms", $time / 1_000_000);
        btnD = 1; #PUSH; btnD = 0; #PUSH;
        if (dut.w_wt_min !== 50) begin err = err + 1; $display("D7 FAIL 0-10 -> %0d", dut.w_wt_min); end
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        if (dut.w_wt_min !== 0) begin err = err + 1; $display("D7 FAIL 50+10 -> %0d", dut.w_wt_min); end

        // ===== A8 R: MIN_10 -> MIN_1, 분 55 만들기, A3 L 다시 -> 55 + 10 -> 05 =====
        scenario = "A8 R MIN_10->MIN_1"; $display("A8 %0d ms", $time / 1_000_000);
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        if (dut.w_cursor !== 0) begin err = err + 1; $display("A8 FAIL cursor %0d", dut.w_cursor); end
        for (i = 0; i < 5; i = i + 1) begin btnD = 1; #PUSH; btnD = 0; #PUSH; end
        if (dut.w_wt_min !== 55) begin err = err + 1; $display("A8 FAIL min %0d (exp 55)", dut.w_wt_min); end
        scenario = "D7 55+10 -> 05"; $display("D7b %0d ms", $time / 1_000_000);
        btnL = 1; #PUSH; btnL = 0; #PUSH;
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        if (dut.w_wt_min !== 5 || dut.w_wt_hour !== 12) begin err = err + 1; $display("D7 FAIL 55+10 -> %0d:%0d", dut.w_wt_hour, dut.w_wt_min); end

        // ===== A4 L: MIN_10 -> HOUR, D8 시 경계: 12 -> 23 (U 11번), 23 + 1 -> 0, 0 - 1 -> 23 =====
        scenario = "A4 L MIN_10->HOUR"; $display("A4 %0d ms", $time / 1_000_000);
        btnL = 1; #PUSH; btnL = 0; #PUSH;
        if (dut.w_cursor !== 2) begin err = err + 1; $display("A4 FAIL cursor %0d", dut.w_cursor); end
        scenario = "D8 HOUR 23+1, 0-1"; $display("D8 %0d ms", $time / 1_000_000);
        for (i = 0; i < 11; i = i + 1) begin btnU = 1; #PUSH; btnU = 0; #PUSH; end
        if (dut.w_wt_hour !== 23) begin err = err + 1; $display("D8 FAIL hour %0d (exp 23)", dut.w_wt_hour); end
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        if (dut.w_wt_hour !== 0) begin err = err + 1; $display("D8 FAIL 23+1 -> %0d", dut.w_wt_hour); end
        btnD = 1; #PUSH; btnD = 0; #PUSH;
        if (dut.w_wt_hour !== 23 || dut.w_wt_min !== 5) begin err = err + 1; $display("D8 FAIL 0-1 -> %0d:%0d", dut.w_wt_hour, dut.w_wt_min); end

        // ===== A5 L: HOUR -> MIN_1 (왼쪽 끝에서 돌아감) =====
        scenario = "A5 L HOUR->MIN_1"; $display("A5 %0d ms", $time / 1_000_000);
        btnL = 1; #PUSH; btnL = 0; #PUSH;
        if (dut.w_cursor !== 0) begin err = err + 1; $display("A5 FAIL cursor %0d", dut.w_cursor); end

        // ===== A6 · A7 · A8 R: MIN_1 -> HOUR -> MIN_10 -> MIN_1 =====
        scenario = "A6 R MIN_1->HOUR"; $display("A6 %0d ms", $time / 1_000_000);
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        if (dut.w_cursor !== 2) begin err = err + 1; $display("A6 FAIL cursor %0d", dut.w_cursor); end
        scenario = "A7 R HOUR->MIN_10"; $display("A7 %0d ms", $time / 1_000_000);
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        if (dut.w_cursor !== 1) begin err = err + 1; $display("A7 FAIL cursor %0d", dut.w_cursor); end
        scenario = "A8 R MIN_10->MIN_1"; $display("A8b %0d ms", $time / 1_000_000);
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        if (dut.w_cursor !== 0) begin err = err + 1; $display("A8 FAIL cursor %0d", dut.w_cursor); end

        // ===== P3 L + R 동시에 누름 -> L 만 (MIN_1 -> MIN_10) =====
        scenario = "P3 L+R -> L"; $display("P3 %0d ms", $time / 1_000_000);
        btnL = 1; btnR = 1; #PUSH; btnL = 0; btnR = 0; #PUSH;
        if (dut.w_cursor !== 1) begin err = err + 1; $display("P3 FAIL cursor %0d (exp 1)", dut.w_cursor); end

        // ===== A10 SET_MIN_10 --sw2=0--> NORMAL =====
        scenario = "A10 MIN_10 sw2=0"; $display("A10 %0d ms", $time / 1_000_000);
        sw_set = 0; #PUSH;
        if (dut.w_cursor !== 3 || dut.w_set_mode !== 0) begin err = err + 1; $display("A10 FAIL"); end

        // ===== A9 SET_MIN_1 --sw2=0--> NORMAL =====
        scenario = "A9 MIN_1 sw2=0"; $display("A9 %0d ms", $time / 1_000_000);
        sw_set = 1; #PUSH;
        sw_set = 0; #PUSH;
        if (dut.w_cursor !== 3) begin err = err + 1; $display("A9 FAIL"); end

        // ===== A11 SET_HOUR --sw2=0--> NORMAL =====
        scenario = "A11 HOUR sw2=0"; $display("A11 %0d ms", $time / 1_000_000);
        sw_set = 1; #PUSH;
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        if (dut.w_cursor !== 2) begin err = err + 1; $display("A11 FAIL setup cursor %0d", dut.w_cursor); end
        sw_set = 0; #PUSH;
        if (dut.w_cursor !== 3) begin err = err + 1; $display("A11 FAIL"); end

        // ===== P1 sw2 를 내리는 그 클럭에 L 펄스 -> NORMAL (자리 이동 안 함) =====
        scenario = "P1 sw2=0 + L"; $display("P1 %0d ms", $time / 1_000_000);
        sw_set = 1; #PUSH;
        btnL = 1; @(posedge dut.w_btnL); sw_set = 0;            // 디바운스 펄스가 나온 바로 그 클럭에 스위치 내림
        @(posedge clk); #1;                                     // 바로 다음 클럭: 자리 이동 없이 곧장 NORMAL 이어야 함
        if (dut.w_cursor !== 3) begin err = err + 1; $display("P1 FAIL cursor %0d right after the pulse (exp 3, L must lose to sw2=0)", dut.w_cursor); end
        #PUSH; btnL = 0; #PUSH;
        if (dut.w_cursor !== 3) begin err = err + 1; $display("P1 FAIL cursor %0d", dut.w_cursor); end

        // ===== P2 sw2 를 내리는 그 클럭에 U 펄스 -> 시각 그대로 =====
        scenario = "P2 sw2=0 + U"; $display("P2 %0d ms", $time / 1_000_000);
        sw_set = 1; #PUSH;
        i = n_up;
        btnU = 1; @(posedge dut.w_btnU); sw_set = 0;
        #PUSH; btnU = 0; #PUSH;
        if (n_up !== i || dut.w_wt_min !== 5 || dut.w_wt_hour !== 23) begin err = err + 1; $display("P2 FAIL up %0d->%0d time %0d:%0d", i, n_up, dut.w_wt_hour, dut.w_wt_min); end

        // ===== B1 설정 중 시 자리 점멸 1초 (1/100초 50~99 동안만 빈칸) =====
        scenario = "B1 BLINK HOUR 1s"; $display("B1 %0d ms", $time / 1_000_000);
        sw_set = 1; #PUSH;
        btnR = 1; #PUSH; btnR = 0; #PUSH;                       // MIN_1 -> HOUR
        #1_000_000_000;
        if (n_blank_on == 0 || n_blank_bad != 0) begin err = err + 1; $display("B1 FAIL blank on %0d bad %0d", n_blank_on, n_blank_bad); end

        // ===== H1 12/24: 23시 -> 12시간 표시 11 + LED15, sw3 = 1 -> 23 + LED15 꺼짐 =====
        scenario = "H1 12H 24H"; $display("H1 %0d ms", $time / 1_000_000);
        if (dut.w_wt_hour_disp !== 11 || led[15] !== 1) begin err = err + 1; $display("H1 FAIL 12h disp %0d pm %b", dut.w_wt_hour_disp, led[15]); end
        sw_24h = 1; #PUSH;
        if (dut.w_wt_hour_disp !== 23 || led[15] !== 0) begin err = err + 1; $display("H1 FAIL 24h disp %0d pm %b", dut.w_wt_hour_disp, led[15]); end
        sw_24h = 0;

        // ===== D5 자정: 분 59 로 설정(버튼) -> 초 · 1/100초 초기값 조정 -> 23:59:59.9x -> 00:00:00.0x =====
        scenario = "D5 MIDNIGHT"; $display("D5 %0d ms", $time / 1_000_000);
        btnL = 1; #PUSH; btnL = 0; #PUSH;                       // HOUR -> MIN_1
        for (i = 0; i < 6; i = i + 1) begin btnD = 1; #PUSH; btnD = 0; #PUSH; end   // 05 -> 59
        sw_set = 0; #PUSH;
        if (dut.w_wt_hour !== 23 || dut.w_wt_min !== 59) begin err = err + 1; $display("D5 FAIL setup %0d:%0d", dut.w_wt_hour, dut.w_wt_min); end
        @(negedge clk);
        dut.U_WATCH_DATAPATH.U_SEC_COUNTER.counter_reg  = 59;  // 초기값 조정 (설계 · tick 은 그대로)
        dut.U_WATCH_DATAPATH.U_MSEC_COUNTER.counter_reg = 90;
        $display("D5 info: 23:59:59.90 set at %0d ns", $time);
        #110_000_000;                                           // 0.11 초 실제 시간
        if (dut.w_wt_hour !== 0 || dut.w_wt_min !== 0 || dut.w_wt_sec !== 0) begin err = err + 1; $display("D5 FAIL %0d:%0d:%0d.%0d", dut.w_wt_hour, dut.w_wt_min, dut.w_wt_sec, dut.w_wt_msec); end
        if (dut.w_wt_hour_disp !== 12 || led[15] !== 0) begin err = err + 1; $display("D5 FAIL 0h -> 12h disp %0d pm %b (exp 12 AM)", dut.w_wt_hour_disp, led[15]); end

        // ===== R1 설정 중 리셋 -> NORMAL, 12:00 =====
        scenario = "R1 RST in SET"; $display("R1 %0d ms", $time / 1_000_000);
        sw_set = 1; #PUSH;
        btnL = 1; #PUSH; btnL = 0; #PUSH;                       // MIN_10
        rst = 1; #1000; rst = 0; sw_set = 0; #PUSH;
        if (dut.w_cursor !== 3 || dut.w_wt_hour !== 12 || dut.w_wt_min !== 0) begin err = err + 1; $display("R1 FAIL cursor %0d time %0d:%0d", dut.w_cursor, dut.w_wt_hour, dut.w_wt_min); end

        scenario = "END";
        $display("info: +1 pulses %0d, -1 pulses %0d, min-counter tick & button same clock = %0d", n_up, n_down, n_collide);
        $display("end %0d ms", $time / 1_000_000);
        $display("TOTAL MISMATCH = %0d", err);
        $finish;
    end
endmodule
