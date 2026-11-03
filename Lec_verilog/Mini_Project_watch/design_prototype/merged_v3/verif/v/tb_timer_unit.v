`timescale 1ns / 1ps
// [검증 TB] 타이머 CU + DP (10/16 판: U +10초 · R +1분 · D +10분, 최대 59:59, 분.초)
// 10 ms tick 은 입력이라 TB 가 10클럭마다 직접 준다 (실제 간격과 무관하게 논리만 검사)
module tb_timer_unit ();
    reg clk, rst, bL, bR, bU, bD, tick;
    wire run, alarm, o_clear, o_add; wire [1:0] amount;
    wire [6:0] msec; wire [5:0] sec, min; wire [4:0] hour; wire zero;
    timer_control_unit U_CU (.clk(clk), .rst(rst), .btn_left(bL), .btn_right(bR), .btn_up(bU), .btn_down(bD),
        .i_zero(zero), .run(run), .alarm(alarm), .o_clear(o_clear), .o_add(o_add), .amount(amount));
    timer_datapath U_DP (.clk(clk), .rst(rst), .i_tick_10ms(tick), .run(run), .clear(o_clear), .add(o_add), .amount(amount),
        .msec(msec), .sec(sec), .min(min), .hour(hour), .zero(zero));
    always #5 clk = ~clk;
    integer err, i, n;
    reg tick_en;
    // tick: 10 클럭마다 1클럭 (tick_en 일 때)
    integer tc;
    always @(posedge clk) begin
        if (rst) begin tc <= 0; tick <= 0; end
        else begin tc <= (tc == 9) ? 0 : tc + 1; tick <= tick_en && (tc == 9); end
    end

    initial begin
        clk = 0; rst = 1; bL = 0; bR = 0; bU = 0; bD = 0; tick_en = 0; err = 0;
        #22 rst = 0;
        if (zero !== 1 || run !== 0 || alarm !== 0 || hour !== 0) begin err = err + 1; $display("FAIL reset"); end

        // 0 에서 L -> 시작 안 함
        @(negedge clk); bL = 1; @(negedge clk); bL = 0; #1;
        if (run !== 0) begin err = err + 1; $display("FAIL start at zero"); end

        // U +10초: 00:00 -> 00:10, msec 그대로 0, hour 0
        @(negedge clk); bU = 1; @(negedge clk); bU = 0; #1;
        if (min !== 0 || sec !== 10 || msec !== 0 || hour !== 0) begin err = err + 1; $display("FAIL +10s %0d:%0d", min, sec); end
        // 초 넘김: 00:50 + 10s -> 01:00
        for (i = 0; i < 4; i = i + 1) begin @(negedge clk); bU = 1; @(negedge clk); bU = 0; end
        #1 if (sec !== 50) begin err = err + 1; $display("FAIL 50s %0d", sec); end
        @(negedge clk); bU = 1; @(negedge clk); bU = 0; #1;
        if (min !== 1 || sec !== 0) begin err = err + 1; $display("FAIL sec carry %0d:%0d", min, sec); end
        // R +1분 -> 02:00, D +10분 -> 12:00
        @(negedge clk); bR = 1; @(negedge clk); bR = 0; #1;
        if (min !== 2) begin err = err + 1; $display("FAIL +1m %0d", min); end
        @(negedge clk); bD = 1; @(negedge clk); bD = 0; #1;
        if (min !== 12 || sec !== 0) begin err = err + 1; $display("FAIL +10m %0d", min); end
        // 상한: 12:00 + D x4 -> 52:00, + D -> 62 넘침 -> 59:59
        for (i = 0; i < 4; i = i + 1) begin @(negedge clk); bD = 1; @(negedge clk); bD = 0; end
        #1 if (min !== 52) begin err = err + 1; $display("FAIL 52 %0d", min); end
        @(negedge clk); bD = 1; @(negedge clk); bD = 0; #1;
        if (min !== 59 || sec !== 59 || msec !== 0) begin err = err + 1; $display("FAIL cap D %0d:%0d", min, sec); end
        // 상한에서 U, R, D 모두 59:59 유지
        @(negedge clk); bU = 1; @(negedge clk); bU = 0; #1;
        if (min !== 59 || sec !== 59) begin err = err + 1; $display("FAIL cap U"); end
        @(negedge clk); bR = 1; @(negedge clk); bR = 0; #1;
        if (min !== 59 || sec !== 59) begin err = err + 1; $display("FAIL cap R"); end
        // 경계: 59:50 에서 +10s -> 60:00 넘침 -> 59:59 ; 58:59 + 1m -> 59:59 (정상) ; 49:59 + 10m -> 59:59 (정상)
        // 먼저 취소로 0 만들고 다시 쌓기: 시작 후 취소
        @(negedge clk); bL = 1; @(negedge clk); bL = 0; #1;   // RUN
        if (run !== 1) begin err = err + 1; $display("FAIL start"); end
        @(negedge clk); bL = 1; @(negedge clk); bL = 0; #1;   // 취소 -> 0
        if (run !== 0 || zero !== 1) begin err = err + 1; $display("FAIL cancel -> zero"); end
        for (i = 0; i < 5; i = i + 1) begin @(negedge clk); bD = 1; @(negedge clk); bD = 0; end   // 50:00
        for (i = 0; i < 9; i = i + 1) begin @(negedge clk); bR = 1; @(negedge clk); bR = 0; end   // 59:00
        for (i = 0; i < 5; i = i + 1) begin @(negedge clk); bU = 1; @(negedge clk); bU = 0; end   // 59:50
        #1 if (min !== 59 || sec !== 50) begin err = err + 1; $display("FAIL build 59:50 %0d:%0d", min, sec); end
        @(negedge clk); bU = 1; @(negedge clk); bU = 0; #1;
        if (min !== 59 || sec !== 59) begin err = err + 1; $display("FAIL 59:50+10s -> %0d:%0d (expect 59:59)", min, sec); end
        // 49:59 + 10m = 59:59 (정확히 상한, 넘침 아님)
        @(negedge clk); bL = 1; @(negedge clk); bL = 0; @(negedge clk); bL = 1; @(negedge clk); bL = 0; // start, cancel
        for (i = 0; i < 4; i = i + 1) begin @(negedge clk); bD = 1; @(negedge clk); bD = 0; end   // 40:00
        for (i = 0; i < 9; i = i + 1) begin @(negedge clk); bR = 1; @(negedge clk); bR = 0; end   // 49:00
        for (i = 0; i < 5; i = i + 1) begin @(negedge clk); bU = 1; @(negedge clk); bU = 0; end   // 49:50
        // 49:50 + 10s -> 50:00
        @(negedge clk); bU = 1; @(negedge clk); bU = 0; #1;
        if (min !== 50 || sec !== 0) begin err = err + 1; $display("FAIL 49:50+10s %0d:%0d", min, sec); end
        // 50:00 -> 아래로 만들기 어려우니 59:59 정확 도달: 50:00 + R x9 = 59:00, + U x5 = 59:50 (앞과 같음) 생략

        // 줄어들기: 취소 후 00:10 설정, 시작, tick 공급 -> 1 "초"(100 tick) 뒤 00:09, 10 "초" 뒤 0 -> ALARM
        @(negedge clk); bL = 1; @(negedge clk); bL = 0; @(negedge clk); bL = 1; @(negedge clk); bL = 0;
        @(negedge clk); bU = 1; @(negedge clk); bU = 0; #1;
        if (sec !== 10) begin err = err + 1; $display("FAIL set 10s"); end
        tick_en = 1;
        @(negedge clk); bL = 1; @(negedge clk); bL = 0; #1;
        if (run !== 1) begin err = err + 1; $display("FAIL run"); end
        // 첫 tick 에서 00:10.00 -> 00:09.99 (빌림 사슬 한 번에)
        @(posedge tick); @(negedge clk); @(negedge clk);
        if (sec !== 9 || msec !== 99) begin err = err + 1; $display("FAIL first borrow %0d.%0d", sec, msec); end
        // 99 tick 더 -> 00:09.00
        repeat (99) @(posedge tick); @(negedge clk); @(negedge clk);
        if (sec !== 9 || msec !== 0) begin err = err + 1; $display("FAIL after 100 ticks %0d.%0d", sec, msec); end
        // 시작부터 총 1000 tick 째에 0 -> alarm
        n = 100;
        while (zero == 0 && n < 2000) begin @(posedge tick); n = n + 1; @(negedge clk); @(negedge clk); end
        if (n !== 1000) begin err = err + 1; $display("FAIL zero after %0d ticks (expect 1000)", n); end
        @(negedge clk);   // FSM 이 zero 를 보고 ALARM 으로 가는 데 1클럭
        if (alarm !== 1 || run !== 0) begin err = err + 1; $display("FAIL alarm state"); end
        // ALARM 에서 tick 이 와도 0 유지 (23:59 로 안 넘어감)
        repeat (5) @(posedge tick); @(negedge clk);
        if (zero !== 1 || min !== 0 || sec !== 0 || msec !== 0) begin err = err + 1; $display("FAIL underflow in alarm"); end
        // ALARM 에서 D -> SET, 더해지지 않음
        @(negedge clk); bD = 1; @(negedge clk); bD = 0; #1;
        if (alarm !== 0 || zero !== 1) begin err = err + 1; $display("FAIL alarm off by D adds time"); end
        // RUN 중 U/R/D 무시 (tick 을 멈춰 두고 값이 그대로인지 본다)
        tick_en = 0; repeat (12) @(negedge clk);
        @(negedge clk); bR = 1; @(negedge clk); bR = 0;   // 01:00
        @(negedge clk); bL = 1; @(negedge clk); bL = 0; #1; // RUN
        @(negedge clk); bU = 1; bR = 1; bD = 1; @(negedge clk); bU = 0; bR = 0; bD = 0; #1;
        if (min !== 1 || sec !== 0 || msec !== 0) begin err = err + 1; $display("FAIL add in RUN changed time %0d:%0d.%0d (expect 01:00.00)", min, sec, msec); end
        if (run !== 1) begin err = err + 1; $display("FAIL buttons in RUN changed state"); end
        tick_en = 1;
        // RUN 중 L 과 tick 같은 클럭 -> clear 우선, 0
        @(posedge clk); while (tc != 8) @(posedge clk); // 다음 클럭에 tick=1
        bL = 1; @(posedge clk); #1; bL = 0; #1;
        if (zero !== 1 || run !== 0) begin err = err + 1; $display("FAIL cancel with tick same clock"); end
        // 분 경계 빌림: 01:00.00 에서 시작 -> 첫 tick 에 00:59.99 (sec <= 59, min <= 0) — 변이 M12 가 놓친 자리
        tick_en = 0; repeat (12) @(negedge clk);
        if (zero !== 1) begin @(negedge clk); bL = 1; @(negedge clk); bL = 0; @(negedge clk); bL = 1; @(negedge clk); bL = 0; end
        @(negedge clk); bR = 1; @(negedge clk); bR = 0; #1;
        if (min !== 1 || sec !== 0) begin err = err + 1; $display("FAIL build 01:00 %0d:%0d", min, sec); end
        @(negedge clk); bL = 1; @(negedge clk); bL = 0;                  // RUN
        tick_en = 1; @(posedge tick); @(negedge clk); @(negedge clk);
        if (min !== 0 || sec !== 59 || msec !== 99) begin err = err + 1; $display("FAIL minute borrow %0d:%0d.%0d (expect 00:59.99)", min, sec, msec); end
        @(negedge clk); bL = 1; @(negedge clk); bL = 0;                  // 취소
        // reset in RUN
        @(negedge clk); bR = 1; @(negedge clk); bR = 0; @(negedge clk); bL = 1; @(negedge clk); bL = 0; #1;
        if (run !== 1) begin err = err + 1; $display("FAIL run2"); end
        rst = 1; #3; rst = 0; #1;
        if (run !== 0 || zero !== 1 || alarm !== 0) begin err = err + 1; $display("FAIL reset in RUN"); end

        $display("TOTAL MISMATCH = %0d", err);
        $finish;
    end
endmodule
