`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// tb_top_3_btn_simultaneous — 버튼 두 개를 같은 순간에 누름 (10/18)
//   사양 (10/18 팀 결정): 같은 클럭에 디바운서 펄스가 두 개 이상이면 그 클럭의 버튼은 모두 무시
//                         → 시계 · 스톱워치 · 타이머 모두 같은 규칙 (Top 의 w_btn_multi)
//   Before 소스(1a65fa8, 기능마다 우선순위)로 돌리면 아래 [FAIL] 이 나온다 = 트러블슈팅 Before 파형
//     A 스톱워치 STOP 에서 R+L  : Before = RUN 시작 + 0 으로 지움   / After = 그대로 STOP · 값 유지
//     B 시계 설정 중 L+R        : Before = L 우선 (커서 왼쪽으로)    / After = 커서 그대로
//       시계 설정 중 U+D        : Before · After 모두 무시 (1a65fa8 에서 이미 고침)
//     C 타이머 SET 에서 U+R     : Before = U 우선 (+10초)            / After = 00:00 그대로
//       타이머 SET 에서 L+D     : Before = L 우선 (시작)             / After = 시작 안 함 · 값 그대로
//   각 단계 뒤 버튼 하나만 눌러 보통 동작이 되는지도 확인 (동시 입력만 막히는지)
// [Vivado] Design Sources = source_file/*.v, *.sv · Simulation Sources = 이 파일 (fnd_monitor.sv 는 없어도 됨) → Set as Top → Run All
//   콘솔 마지막 줄 TOTAL MISMATCH = 0 이면 통과. 시뮬 시간 약 0.45 s
// -----------------------------------------------------------------------------
module tb_top_3_btn_simultaneous;
    reg clk = 1'b0, rst = 1'b1;
    reg btn_R = 1'b0, btn_L = 1'b0, btn_U = 1'b0, btn_D = 1'b0;
    reg mode_sw0 = 1'b0, display_mode_sw1 = 1'b0, set_sw2 = 1'b0, hour24_sw3 = 1'b1, timer_sw4 = 1'b0;
    wire [3:0]  fnd_com;
    wire [7:0]  fnd_font;
    wire [15:0] led;

    always #5 clk = ~clk;   // 100 MHz

    stopwatch_watch dut (
        .clk(clk), .rst(rst),
        .btn_R(btn_R), .btn_L(btn_L), .btn_U(btn_U), .btn_D(btn_D),
        .mode_sw0(mode_sw0), .display_mode_sw1(display_mode_sw1), .set_sw2(set_sw2),
        .hour24_sw3(hour24_sw3), .timer_sw4(timer_sw4),
        .fnd_com(fnd_com), .fnd_font(fnd_font), .led(led)
    );

    // 디바운서 펄스가 같은 클럭에 두 개 이상 나온 횟수 (TB 가 정말 "같은 클럭" 을 만들었는지)
    integer n_same = 0;
    always @(posedge clk) begin
        if (dut.w_btn_R + dut.w_btn_L + dut.w_btn_U + dut.w_btn_D >= 2) begin
            n_same = n_same + 1;
            $display("[%0.6f ms] [same-clock] debounced pulses {D,U,L,R} = %b%b%b%b in the same clock  (Go To Time here)",
                     $realtime / 1000000.0, dut.w_btn_D, dut.w_btn_U, dut.w_btn_L, dut.w_btn_R);
        end
    end

    integer err = 0, total = 0, v0, ns0;

    initial begin
        // ---------------------------------------------------------------- 리셋
        #1000 rst = 1'b0;
        #1000;

        // ================================================================ A 스톱워치
        $display("[%0.3f ms] ===== A stopwatch : STOP, R+L same instant", $realtime / 1000000.0);
        mode_sw0 = 1'b1;
        btn_R = 1'b1; #5_000_000; btn_R = 1'b0; #5_000_000;          // R : 시작
        #200_000_000;                                                 // 200 ms 동작
        btn_R = 1'b1; #5_000_000; btn_R = 1'b0; #5_000_000;          // R : 정지
        v0 = dut.w_sw_sec * 100 + dut.w_sw_msec;
        total = total + 1;
        if (dut.w_sw_run_stop !== 1'b0 || v0 == 0) begin err = err + 1; $display("  FAIL A0 setup: run=%b value=%0d", dut.w_sw_run_stop, v0); end
        else $display("  OK   A0 STOP, value %0d (x10 ms)", v0);
        ns0 = n_same;
        btn_R = 1'b1; btn_L = 1'b1; #5_000_000; btn_R = 1'b0; btn_L = 1'b0; #5_000_000;   // R + L 같은 순간
        total = total + 1;
        if (n_same == ns0) begin err = err + 1; $display("  FAIL A1 R, L debounced pulses were not in the same clock"); end
        else $display("  OK   A1 R, L pulses in the same clock");
        total = total + 1;
        if (dut.w_sw_run_stop !== 1'b0 || (dut.w_sw_sec * 100 + dut.w_sw_msec) != v0) begin
            err = err + 1;
            $display("  FAIL A2 R+L : exp STOP value %0d, got run=%b value %0d", v0, dut.w_sw_run_stop, dut.w_sw_sec * 100 + dut.w_sw_msec);
        end else $display("  OK   A2 R+L ignored : STOP, value %0d kept", v0);
        btn_L = 1'b1; #5_000_000; btn_L = 1'b0; #5_000_000;          // L 하나만 : 지우기
        total = total + 1;
        if ((dut.w_sw_sec * 100 + dut.w_sw_msec) != 0) begin err = err + 1; $display("  FAIL A3 L alone : exp 0"); end
        else $display("  OK   A3 L alone still clears (0)");

        // ================================================================ B 시계
        $display("[%0.3f ms] ===== B watch set : L+R, U+D same instant", $realtime / 1000000.0);
        mode_sw0 = 1'b0; display_mode_sw1 = 1'b1; set_sw2 = 1'b1;   // 시계 화면 · 시.분 · 설정 → 커서 0 (분 일)
        #1_000_000;
        total = total + 1;
        if (dut.w_wt_cursor !== 2'd0) begin err = err + 1; $display("  FAIL B0 setup cursor %0d", dut.w_wt_cursor); end
        else $display("  OK   B0 set mode, cursor 0 (min ones), %0d:%02d", dut.w_wt_hour, dut.w_wt_min);
        btn_L = 1'b1; btn_R = 1'b1; #5_000_000; btn_L = 1'b0; btn_R = 1'b0; #5_000_000;   // L + R 같은 순간
        total = total + 1;
        if (dut.w_wt_cursor !== 2'd0) begin err = err + 1; $display("  FAIL B1 L+R : exp cursor 0, got %0d", dut.w_wt_cursor); end
        else $display("  OK   B1 L+R ignored : cursor 0 kept");
        btn_U = 1'b1; btn_D = 1'b1; #5_000_000; btn_U = 1'b0; btn_D = 1'b0; #5_000_000;   // U + D 같은 순간
        total = total + 1;
        if (dut.w_wt_hour != 12 || dut.w_wt_min != 0) begin err = err + 1; $display("  FAIL B2 U+D : exp 12:00, got %0d:%02d", dut.w_wt_hour, dut.w_wt_min); end
        else $display("  OK   B2 U+D ignored : 12:00 kept");
        btn_L = 1'b1; #5_000_000; btn_L = 1'b0; #5_000_000;          // L 하나만 : 커서 왼쪽
        total = total + 1;
        if (dut.w_wt_cursor !== 2'd1) begin err = err + 1; $display("  FAIL B3 L alone : exp cursor 1, got %0d", dut.w_wt_cursor); end
        else $display("  OK   B3 L alone still moves cursor (1)");
        set_sw2 = 1'b0;

        // ================================================================ C 타이머
        $display("[%0.3f ms] ===== C timer SET : U+R, L+D same instant", $realtime / 1000000.0);
        timer_sw4 = 1'b1;
        #1_000_000;
        btn_U = 1'b1; btn_R = 1'b1; #5_000_000; btn_U = 1'b0; btn_R = 1'b0; #5_000_000;   // U + R 같은 순간
        total = total + 1;
        if (dut.w_tm_min != 0 || dut.w_tm_sec != 0) begin err = err + 1; $display("  FAIL C1 U+R : exp 00:00, got %02d:%02d", dut.w_tm_min, dut.w_tm_sec); end
        else $display("  OK   C1 U+R ignored : 00:00 kept");
        btn_U = 1'b1; #5_000_000; btn_U = 1'b0; #5_000_000;          // U 하나만 : +10초
        total = total + 1;
        if (dut.w_tm_min != 0 || dut.w_tm_sec != 10) begin err = err + 1; $display("  FAIL C2 U alone : exp 00:10, got %02d:%02d", dut.w_tm_min, dut.w_tm_sec); end
        else $display("  OK   C2 U alone still adds 10 s (00:10)");
        btn_L = 1'b1; btn_D = 1'b1; #5_000_000; btn_L = 1'b0; btn_D = 1'b0; #5_000_000;   // L + D 같은 순간
        total = total + 1;
        if (dut.w_tm_run !== 1'b0 || dut.w_tm_min != 0 || dut.w_tm_sec != 10) begin
            err = err + 1;
            $display("  FAIL C3 L+D : exp SET 00:10, got run=%b %02d:%02d", dut.w_tm_run, dut.w_tm_min, dut.w_tm_sec);
        end else $display("  OK   C3 L+D ignored : not started, 00:10 kept");

        $display("[%0.3f ms] same-clock pulse pairs seen = %0d (expected 5)", $realtime / 1000000.0, n_same);
        $display("TOTAL %0d checks, TOTAL MISMATCH = %0d", total, err);
        $finish;
    end
endmodule
