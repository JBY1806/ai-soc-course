`timescale 1ns / 1ps
// [검증 TB] watch_datapath (팀 통합판: 100 Hz tick 입력) — tick 을 TB 가 직접 줌
module tb_watch_dp_unit ();
    reg clk, rst, tick, i_up, i_down; reg [1:0] cursor;
    wire [6:0] msec; wire [5:0] sec, min; wire [4:0] hour;
    watch_datapath dut (.clk(clk), .rst(rst), .i_tick_10ms(tick), .cursor(cursor), .i_up(i_up), .i_down(i_down),
        .msec(msec), .sec(sec), .min(min), .hour(hour));
    always #5 clk = ~clk;
    integer err, i, n;
    // 모델: 10 ms 마다 1 씩 (초기 12:00:00.00), 자릿수 모델은 "tick 개수" 로 검산
    integer total_ticks, m_h, m_m, m_s, m_ms;

    initial begin
        clk = 0; rst = 1; tick = 0; i_up = 0; i_down = 0; cursor = 3; err = 0; total_ticks = 0;
        #22 rst = 0;
        if ({hour, min, sec, msec} !== {5'd12, 6'd0, 6'd0, 7'd0}) begin err = err + 1; $display("FAIL init"); end

        // 1 tick -> 12:00:00.01 (msec 는 tick 클럭에 바로)
        @(negedge clk); tick = 1; @(negedge clk); tick = 0; #1;
        if (msec !== 1) begin err = err + 1; $display("FAIL tick1 %0d", msec); end
        // 99 tick 더 -> msec 0, sec 는 msec 의 o_tick 로 1클럭 늦게 1
        for (i = 0; i < 99; i = i + 1) begin @(negedge clk); tick = 1; @(negedge clk); tick = 0; end
        #1 if (msec !== 0) begin err = err + 1; $display("FAIL msec wrap %0d", msec); end
        @(negedge clk);
        if (sec !== 1) begin err = err + 1; $display("FAIL sec carry %0d", sec); end
        // 리플 지연: msec 가 0 이 된 그 클럭에는 sec 아직 0 이어야 (1클럭 뒤 1) — 위에서 확인됨

        // 설정: cursor 0 -> 분 +1 / -1 (59 -> 0 돌기, 시 그대로)
        cursor = 0;
        @(negedge clk); i_down = 1; @(negedge clk); i_down = 0; #1;
        if (min !== 59 || hour !== 12) begin err = err + 1; $display("FAIL min -1 wrap %0d:%0d", hour, min); end
        @(negedge clk); i_up = 1; @(negedge clk); i_up = 0; #1;
        if (min !== 0 || hour !== 12) begin err = err + 1; $display("FAIL min +1 wrap %0d:%0d", hour, min); end
        // cursor 1 -> 분 +-10 (0 -10 -> 50, 50+10 -> 0, 55 +10 -> 5)
        cursor = 1;
        @(negedge clk); i_down = 1; @(negedge clk); i_down = 0; #1;
        if (min !== 50) begin err = err + 1; $display("FAIL -10 %0d", min); end
        @(negedge clk); i_up = 1; @(negedge clk); i_up = 0; #1;
        if (min !== 0) begin err = err + 1; $display("FAIL +10 wrap %0d", min); end
        cursor = 0; for (i = 0; i < 55; i = i + 1) begin @(negedge clk); i_up = 1; @(negedge clk); i_up = 0; end
        cursor = 1; @(negedge clk); i_up = 1; @(negedge clk); i_up = 0; #1;
        if (min !== 5 || hour !== 12) begin err = err + 1; $display("FAIL 55+10 -> %0d:%0d", hour, min); end
        // cursor 2 -> 시 +-1, 0 -> 23, 23 -> 0
        cursor = 2; for (i = 0; i < 12; i = i + 1) begin @(negedge clk); i_down = 1; @(negedge clk); i_down = 0; end
        #1 if (hour !== 0) begin err = err + 1; $display("FAIL hour 0 %0d", hour); end
        @(negedge clk); i_down = 1; @(negedge clk); i_down = 0; #1;
        if (hour !== 23) begin err = err + 1; $display("FAIL hour -1 wrap %0d", hour); end
        @(negedge clk); i_up = 1; @(negedge clk); i_up = 0; #1;
        if (hour !== 0) begin err = err + 1; $display("FAIL hour +1 wrap %0d", hour); end
        // cursor 3 -> 아무것도 안 바뀜 ; 초 · msec 는 어느 cursor 에서도 버튼으로 안 바뀜
        cursor = 3; @(negedge clk); i_up = 1; i_down = 1; @(negedge clk); i_up = 0; i_down = 0; #1;
        if ({hour, min, sec} !== {5'd0, 6'd5, 6'd1}) begin err = err + 1; $display("FAIL cursor 3 changed"); end
        for (i = 0; i < 3; i = i + 1) begin
            cursor = i; @(negedge clk); i_up = 1; @(negedge clk); i_up = 0; @(negedge clk); i_down = 1; @(negedge clk); i_down = 0; #1;
            if (sec !== 1 || msec !== 0) begin err = err + 1; $display("FAIL sec/msec changed by button at cursor %0d", i); end
        end
        // 같은 클럭: 분 카운터에 tick(초 넘김) 과 up 동시 -> tick 만 (분 +1, 버튼 무시)
        // 초를 59 로: cursor 로는 못 하니 tick 으로 58 초 더 (5800 tick) -> 00:05:59.00
        cursor = 3; for (i = 0; i < 5800; i = i + 1) begin @(negedge clk); tick = 1; @(negedge clk); tick = 0; end
        repeat (3) @(negedge clk);
        if (sec !== 59 || min !== 5) begin err = err + 1; $display("FAIL build 05:59 -> %0d:%0d", min, sec); end
        // 100 tick 더 주되, msec 가 99->0 되는 tick 다음 클럭(초 o_tick 이 분에 도달하는 클럭)에 up 을 같이 준다
        cursor = 0;
        for (i = 0; i < 99; i = i + 1) begin @(negedge clk); tick = 1; @(negedge clk); tick = 0; end
        @(negedge clk); tick = 1; @(negedge clk); tick = 0;            // msec 99->0, sec o_tick 다음 클럭
        // 지금 클럭: sec 59->0 (sec 의 i_tick=1). 분 카운터의 i_tick 은 그 다음 클럭
        @(negedge clk); i_down = 1; @(negedge clk); i_down = 0; #1;  // 분: i_tick(초 넘김 +1) 과 i_down(-1) 같은 클럭 -> tick 만 (+1 과 +1 을 겹치면 구분이 안 돼서 D 로)
        if (min !== 6 || sec !== 0) begin err = err + 1; $display("FAIL tick priority at min: %0d:%0d (exp 06:00; button-first would give 04:00)", min, sec); end
        // 자정: 시 23, 분 59, 초 59 만들고 100 tick -> 00:00:00.00
        cursor = 2; for (i = 0; i < 23; i = i + 1) begin @(negedge clk); i_up = 1; @(negedge clk); i_up = 0; end
        cursor = 1; for (i = 0; i < 5; i = i + 1) begin @(negedge clk); i_up = 1; @(negedge clk); i_up = 0; end
        cursor = 0; for (i = 0; i < 3; i = i + 1) begin @(negedge clk); i_up = 1; @(negedge clk); i_up = 0; end
        #1 if (hour !== 23 || min !== 59) begin err = err + 1; $display("FAIL build 23:59 -> %0d:%0d", hour, min); end
        cursor = 3; for (i = 0; i < 5900; i = i + 1) begin @(negedge clk); tick = 1; @(negedge clk); tick = 0; end
        repeat (3) @(negedge clk);
        if (sec !== 59) begin err = err + 1; $display("FAIL 23:59:59 sec %0d", sec); end
        for (i = 0; i < 100; i = i + 1) begin @(negedge clk); tick = 1; @(negedge clk); tick = 0; end
        repeat (4) @(negedge clk);
        if ({hour, min, sec, msec} !== 0) begin err = err + 1; $display("FAIL midnight %0d:%0d:%0d.%0d", hour, min, sec, msec); end
        // reset 중간 -> 12:00
        rst = 1; #3; rst = 0; #1;
        if ({hour, min, sec, msec} !== {5'd12, 6'd0, 6'd0, 7'd0}) begin err = err + 1; $display("FAIL reset mid"); end
        $display("TOTAL MISMATCH = %0d", err);
        $finish;
    end
endmodule
