`timescale 1ns / 1ps
// [작성] 시계 데이터패스 시나리오 TB — watch_datapath 단독, tick 은 TB 가 직접 넣음
// Top 실제 시간으로는 1분 넘김 · 자정이 몇 시간 걸려서, 시간이 오래 걸리는 경우만 여기서 본다.
// 설계 파라미터는 건드리지 않음 (i_tick_10ms 입력을 TB 가 매 클럭 줄 뿐)
module tb_watch_dp_scenario ();
    reg clk, rst, tick, i_up, i_down;
    reg [1:0] cursor;
    wire [6:0] msec;
    wire [5:0] sec, min;
    wire [4:0] hour;

    reg [8*16:1] scenario;
    integer err, i, t_start, t_carry;

    watch_datapath dut (.clk(clk), .rst(rst), .i_tick_10ms(tick), .cursor(cursor), .i_up(i_up), .i_down(i_down),
        .msec(msec), .sec(sec), .min(min), .hour(hour));

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst = 1; tick = 0; i_up = 0; i_down = 0; cursor = 3; err = 0;
        scenario = "D0 RESET";
        #22 rst = 0;

        // ---------- D1: 리셋값 12:00:00.00 ----------
        scenario = "D1 RESET VALUE"; $display("D1 start %0d ns", $time);
        @(negedge clk);
        if ({hour, min, sec, msec} !== {5'd12, 6'd0, 6'd0, 7'd0}) begin err = err + 1; $display("D1 FAIL"); end

        // ---------- D2: 1/100초 99 -> 0 이 되는 클럭, 초는 그 다음 클럭에 +1 (리플 1클럭) ----------
        scenario = "D2 MSEC CARRY"; $display("D2 start %0d ns", $time);
        for (i = 0; i < 99; i = i + 1) begin tick = 1; @(negedge clk); end
        tick = 0; @(negedge clk);
        if (msec !== 99 || sec !== 0) begin err = err + 1; $display("D2 FAIL setup %0d.%0d", sec, msec); end
        t_carry = $time; tick = 1; @(negedge clk); tick = 0;      // 이 클럭에 msec 99 -> 0
        if (msec !== 0 || sec !== 0) begin err = err + 1; $display("D2 FAIL msec wrap: sec %0d msec %0d (sec must still be 0)", sec, msec); end
        @(negedge clk);                                            // 한 클럭 뒤 sec 1
        if (sec !== 1) begin err = err + 1; $display("D2 FAIL sec not 1 one clock later"); end
        $display("D2 info: msec 99->0 at about %0d ns, sec 0->1 one clock (10 ns) later", t_carry + 5);

        // ---------- D3: 초 59 -> 0 이면 분 +1 (12:00:59 -> 12:01:00) ----------
        scenario = "D3 SEC CARRY"; $display("D3 start %0d ns", $time);
        for (i = 0; i < 5800; i = i + 1) begin tick = 1; @(negedge clk); end   // 1초 + 58초 = 59초
        tick = 0; repeat (3) @(negedge clk);
        if (sec !== 59 || min !== 0) begin err = err + 1; $display("D3 FAIL setup %0d:%0d", min, sec); end
        $display("D3 info: 12:00:59.00 reached at %0d ns", $time);
        for (i = 0; i < 100; i = i + 1) begin tick = 1; @(negedge clk); end
        tick = 0; repeat (3) @(negedge clk);
        if (min !== 1 || sec !== 0) begin err = err + 1; $display("D3 FAIL %0d:%0d", min, sec); end

        // ---------- D4: 분 카운터에 "초 넘김 tick" 과 "D(-1)" 가 같은 클럭 -> tick 만 반영 ----------
        scenario = "D4 TICK vs D"; $display("D4 start %0d ns", $time);
        cursor = 0;
        for (i = 0; i < 5900; i = i + 1) begin tick = 1; @(negedge clk); end   // 12:01:59.00
        tick = 0; repeat (3) @(negedge clk);
        for (i = 0; i < 99; i = i + 1) begin tick = 1; @(negedge clk); end     // 12:01:59.99
        tick = 1; @(negedge clk); tick = 0;                                     // msec 99 -> 0
        @(negedge clk);                                                         // sec 59 -> 0, 초 o_tick(= 분 i_tick) 이 지금 1
        if (dut.w_tick_min !== 1) begin err = err + 1; $display("D4 FAIL setup: min-counter tick not 1"); end
        $display("D4 info: tick and D on the same clock at about %0d ns", $time + 5);
        i_down = 1; @(negedge clk); i_down = 0;                                 // 같은 클럭에 D
        if (min !== 2) begin err = err + 1; $display("D4 FAIL min %0d (exp 2: tick wins; button-first would give 0)", min); end
        cursor = 3;

        // ---------- D5: 23:59:59.99 -> 00:00:00.00 (자정) ----------
        scenario = "D5 MIDNIGHT"; $display("D5 start %0d ns", $time);
        cursor = 2; for (i = 0; i < 11; i = i + 1) begin i_up = 1; @(negedge clk); i_up = 0; @(negedge clk); end   // 12 -> 23
        cursor = 0; for (i = 0; i < 3; i = i + 1)  begin i_down = 1; @(negedge clk); i_down = 0; @(negedge clk); end // 02 -> 59
        cursor = 3;
        if (hour !== 23 || min !== 59) begin err = err + 1; $display("D5 FAIL setup %0d:%0d", hour, min); end
        for (i = 0; i < 5999; i = i + 1) begin tick = 1; @(negedge clk); end   // 23:59:59.99
        tick = 0; repeat (3) @(negedge clk);
        if ({hour, min, sec, msec} !== {5'd23, 6'd59, 6'd59, 7'd99}) begin err = err + 1; $display("D5 FAIL setup %0d:%0d:%0d.%0d", hour, min, sec, msec); end
        $display("D5 info: 23:59:59.99 at %0d ns", $time);
        tick = 1; @(negedge clk); tick = 0;
        repeat (4) @(negedge clk);
        if ({hour, min, sec, msec} !== 24'd0) begin err = err + 1; $display("D5 FAIL midnight %0d:%0d:%0d.%0d", hour, min, sec, msec); end

        // ---------- D6: 분 일의 자리(cursor 0) 설정 경계: 0 - 1 -> 59, 59 + 1 -> 0, 시는 그대로 ----------
        scenario = "D6 MIN SET WRAP"; $display("D6 start %0d ns", $time);
        cursor = 0;
        i_down = 1; @(negedge clk); i_down = 0; @(negedge clk);
        if (min !== 59 || hour !== 0) begin err = err + 1; $display("D6 FAIL 0-1 -> %0d:%0d (exp 0:59)", hour, min); end
        i_up = 1; @(negedge clk); i_up = 0; @(negedge clk);
        if (min !== 0 || hour !== 0) begin err = err + 1; $display("D6 FAIL 59+1 -> %0d:%0d (exp 0:0, no carry)", hour, min); end

        // ---------- D7: 분 십의 자리(cursor 1) ±10: 0 - 10 -> 50, 50 + 10 -> 0, 55 + 10 -> 05 ----------
        scenario = "D7 MIN10 +-10"; $display("D7 start %0d ns", $time);
        cursor = 1;
        i_down = 1; @(negedge clk); i_down = 0; @(negedge clk);
        if (min !== 50) begin err = err + 1; $display("D7 FAIL 0-10 -> %0d (exp 50)", min); end
        i_up = 1; @(negedge clk); i_up = 0; @(negedge clk);
        if (min !== 0) begin err = err + 1; $display("D7 FAIL 50+10 -> %0d (exp 0)", min); end
        cursor = 0; for (i = 0; i < 5; i = i + 1) begin i_down = 1; @(negedge clk); i_down = 0; @(negedge clk); end   // 0 -> 55
        cursor = 1; i_up = 1; @(negedge clk); i_up = 0; @(negedge clk);
        if (min !== 5 || hour !== 0) begin err = err + 1; $display("D7 FAIL 55+10 -> %0d:%0d (exp 0:05)", hour, min); end

        // ---------- D8: 시(cursor 2) 설정 경계: 0 - 1 -> 23, 23 + 1 -> 0 ----------
        scenario = "D8 HOUR WRAP"; $display("D8 start %0d ns", $time);
        cursor = 2;
        i_down = 1; @(negedge clk); i_down = 0; @(negedge clk);
        if (hour !== 23) begin err = err + 1; $display("D8 FAIL 0-1 -> %0d (exp 23)", hour); end
        i_up = 1; @(negedge clk); i_up = 0; @(negedge clk);
        if (hour !== 0) begin err = err + 1; $display("D8 FAIL 23+1 -> %0d (exp 0)", hour); end

        // ---------- D9: cursor 3(설정 아님) 에서 U · D -> 아무것도 안 바뀜 ----------
        scenario = "D9 CURSOR3 NONE"; $display("D9 start %0d ns", $time);
        cursor = 3;
        i_up = 1; @(negedge clk); i_up = 0; i_down = 1; @(negedge clk); i_down = 0; @(negedge clk);
        if (hour !== 0 || min !== 5) begin err = err + 1; $display("D9 FAIL changed to %0d:%0d", hour, min); end

        scenario = "END";
        $display("end %0d ns", $time);
        $display("TOTAL MISMATCH = %0d", err);
        $finish;
    end
endmodule
