`timescale 1ns / 1ps
// [검증 에이전트 세션 1] 엣지 케이스 TB — watch_control_unit + watch_datapath (Top 과 같은 연결)
// tick(i_tick_10ms) 은 TB 가 직접 넣는다. 설계 파라미터는 바꾸지 않는다.
// 입력은 클럭 하강 에지에서 바꾸고, 비교는 !==. 문법: reg/wire, initial, always, for, if, #, @(negedge clk), $display
module tb_e_unit ();
    reg clk, rst, tick, bL, bR, bU, bD, sw;
    wire       set_mode;
    wire [1:0] cursor;
    wire       o_up, o_down;
    wire [6:0] msec;
    wire [5:0] sec, min;
    wire [4:0] hour;

    integer err, i, k;
    integer ef [1:15];          // 시나리오별 FAIL 수
    reg [5:0] min_a, sec_a;
    reg [6:0] msec_a;
    reg [4:0] hour_a;
    reg [5:0] exp_new;
    reg [15:0] cov;             // 전이 커버리지: cov[{c_state, n_state}]
    integer cov_miss;

    watch_control_unit cu (
        .clk(clk), .rst(rst), .btn_left(bL), .btn_right(bR), .btn_up(bU), .btn_down(bD), .sw_set(sw),
        .set_mode(set_mode), .cursor(cursor), .o_up(o_up), .o_down(o_down));

    watch_datapath dp (
        .clk(clk), .rst(rst), .i_tick_10ms(tick), .cursor(cursor), .i_up(o_up), .i_down(o_down),
        .msec(msec), .sec(sec), .min(min), .hour(hour));

    always #5 clk = ~clk;

    // 상태 전이 기록 (리셋 중 제외). 상태 값: NORMAL 00, SET_HOUR 01, SET_MIN_10 10, SET_MIN_1 11
    always @(posedge clk) begin
        if (!rst) cov[{cu.c_state, cu.n_state}] <= 1'b1;
    end

    initial begin
        clk = 0; rst = 1; tick = 0; bL = 0; bR = 0; bU = 0; bD = 0; sw = 0;
        err = 0; cov = 16'd0; cov_miss = 0;
        for (k = 1; k <= 15; k = k + 1) ef[k] = 0;
        #22;

        // =====================================================================
        // E1 리셋값 + 리셋 해제 직후 버튼 (sw2 = 0) -> 12:00:00.00, NORMAL, 버튼 무시
        // =====================================================================
        $display("E1 start %0d ns", $time);
        sw = 0; rst = 1; @(negedge clk); @(negedge clk);
        if ({hour, min, sec, msec} !== {5'd12, 6'd0, 6'd0, 7'd0}) begin ef[1] = ef[1] + 1; $display("E1 FAIL reset value %0d:%0d:%0d.%0d", hour, min, sec, msec); end
        if (cu.c_state !== 2'b00 || cursor !== 2'd3 || set_mode !== 1'b0) begin ef[1] = ef[1] + 1; $display("E1 FAIL reset state %b cursor %0d set_mode %b", cu.c_state, cursor, set_mode); end
        rst = 0; bU = 1; @(negedge clk); bU = 0;          // 리셋 해제한 바로 그 클럭에 U
        bD = 1; @(negedge clk); bD = 0;
        bL = 1; @(negedge clk); bL = 0;
        bR = 1; @(negedge clk); bR = 0;
        if ({hour, min} !== {5'd12, 6'd0}) begin ef[1] = ef[1] + 1; $display("E1 FAIL buttons changed time in NORMAL %0d:%0d", hour, min); end
        if (cu.c_state !== 2'b00 || cursor !== 2'd3) begin ef[1] = ef[1] + 1; $display("E1 FAIL left NORMAL with sw2=0 (state %b)", cu.c_state); end

        // =====================================================================
        // E2 리셋 해제 직후 버튼 (sw2 = 1 인 채로 리셋 해제)
        //    첫 클럭 U : 사양에 규칙 없음 -> 관찰만. 두 번째 U : SET_MIN_1 에서 +1
        // =====================================================================
        $display("E2 start %0d ns", $time);
        sw = 1; rst = 1; @(negedge clk); @(negedge clk);
        rst = 0; bU = 1; @(negedge clk); bU = 0;          // 해제 직후 첫 클럭
        min_a = min;
        $display("E2 INFO first-clock U after reset release: min 0 -> %0d (%0s)", min, (min == 0) ? "ignored, state was NORMAL" : "applied");
        if (cu.c_state !== 2'b11 || cursor !== 2'd0 || set_mode !== 1'b1) begin ef[2] = ef[2] + 1; $display("E2 FAIL not SET_MIN_1 after release (state %b cursor %0d)", cu.c_state, cursor); end
        bU = 1; @(negedge clk); bU = 0;
        if (min !== min_a + 6'd1 || hour !== 5'd12) begin ef[2] = ef[2] + 1; $display("E2 FAIL second U: min %0d exp %0d", min, min_a + 1); end

        // =====================================================================
        // E3 분 일의 자리 경계: 0 - 1 -> 59, 59 + 1 -> 0, 시는 그대로
        // =====================================================================
        $display("E3 start %0d ns", $time);
        sw = 0; rst = 1; @(negedge clk); rst = 0; @(negedge clk);
        sw = 1; @(negedge clk);
        if (cursor !== 2'd0) begin ef[3] = ef[3] + 1; $display("E3 FAIL setup cursor %0d", cursor); end
        bD = 1; @(negedge clk); bD = 0;
        if (min !== 6'd59 || hour !== 5'd12) begin ef[3] = ef[3] + 1; $display("E3 FAIL 0-1: %0d:%0d exp 12:59", hour, min); end
        @(negedge clk);
        bU = 1; @(negedge clk); bU = 0;
        if (min !== 6'd0 || hour !== 5'd12) begin ef[3] = ef[3] + 1; $display("E3 FAIL 59+1: %0d:%0d exp 12:00", hour, min); end

        // =====================================================================
        // E4 분 일의 자리 09 + 1 -> 10 (사양 예시 '분 59 +1 -> 0' = 분 카운터 전체가 0~59 로 돈다)
        // =====================================================================
        $display("E4 start %0d ns", $time);
        sw = 0; rst = 1; @(negedge clk); rst = 0; @(negedge clk);
        sw = 1; @(negedge clk);
        for (i = 0; i < 9; i = i + 1) begin bU = 1; @(negedge clk); bU = 0; @(negedge clk); end
        if (min !== 6'd9) begin ef[4] = ef[4] + 1; $display("E4 FAIL setup min %0d exp 9", min); end
        bU = 1; @(negedge clk); bU = 0;
        if (min !== 6'd10 || hour !== 5'd12) begin ef[4] = ef[4] + 1; $display("E4 FAIL 09+1: %0d:%0d exp 12:10", hour, min); end
        @(negedge clk);
        bD = 1; @(negedge clk); bD = 0;
        if (min !== 6'd9) begin ef[4] = ef[4] + 1; $display("E4 FAIL 10-1: min %0d exp 9", min); end

        // =====================================================================
        // E5 분 십의 자리 경계: 0 - 10 -> 50, 55 + 10 -> 05, 05 - 10 -> 55, 시는 그대로
        // =====================================================================
        $display("E5 start %0d ns", $time);
        sw = 0; rst = 1; @(negedge clk); rst = 0; @(negedge clk);
        sw = 1; @(negedge clk);
        bL = 1; @(negedge clk); bL = 0;                    // SET_MIN_1 -> SET_MIN_10
        if (cursor !== 2'd1 || cu.c_state !== 2'b10) begin ef[5] = ef[5] + 1; $display("E5 FAIL setup cursor %0d", cursor); end
        bD = 1; @(negedge clk); bD = 0;
        if (min !== 6'd50 || hour !== 5'd12) begin ef[5] = ef[5] + 1; $display("E5 FAIL 0-10: %0d:%0d exp 12:50", hour, min); end
        bR = 1; @(negedge clk); bR = 0;                    // SET_MIN_10 -> SET_MIN_1
        for (i = 0; i < 5; i = i + 1) begin bU = 1; @(negedge clk); bU = 0; @(negedge clk); end
        if (min !== 6'd55) begin ef[5] = ef[5] + 1; $display("E5 FAIL setup min %0d exp 55", min); end
        bL = 1; @(negedge clk); bL = 0;
        bU = 1; @(negedge clk); bU = 0;
        if (min !== 6'd5 || hour !== 5'd12) begin ef[5] = ef[5] + 1; $display("E5 FAIL 55+10: %0d:%0d exp 12:05", hour, min); end
        @(negedge clk);
        bD = 1; @(negedge clk); bD = 0;
        if (min !== 6'd55 || hour !== 5'd12) begin ef[5] = ef[5] + 1; $display("E5 FAIL 05-10: %0d:%0d exp 12:55", hour, min); end

        // =====================================================================
        // E6 시 경계: 23 + 1 -> 0, 0 - 1 -> 23, 분은 그대로
        // =====================================================================
        $display("E6 start %0d ns", $time);
        sw = 0; rst = 1; @(negedge clk); rst = 0; @(negedge clk);
        sw = 1; @(negedge clk);
        bR = 1; @(negedge clk); bR = 0;                    // SET_MIN_1 -> SET_HOUR (오른쪽 끝에서 돌아감)
        if (cursor !== 2'd2 || cu.c_state !== 2'b01) begin ef[6] = ef[6] + 1; $display("E6 FAIL setup cursor %0d", cursor); end
        for (i = 0; i < 11; i = i + 1) begin bU = 1; @(negedge clk); bU = 0; @(negedge clk); end
        if (hour !== 5'd23) begin ef[6] = ef[6] + 1; $display("E6 FAIL setup hour %0d exp 23", hour); end
        bU = 1; @(negedge clk); bU = 0;
        if (hour !== 5'd0 || min !== 6'd0) begin ef[6] = ef[6] + 1; $display("E6 FAIL 23+1: %0d:%0d exp 00:00", hour, min); end
        @(negedge clk);
        bD = 1; @(negedge clk); bD = 0;
        if (hour !== 5'd23 || min !== 6'd0) begin ef[6] = ef[6] + 1; $display("E6 FAIL 0-1: %0d:%0d exp 23:00", hour, min); end

        // =====================================================================
        // E7 자정: 23:59:59.99 + tick -> 00:00:00.00
        // =====================================================================
        $display("E7 start %0d ns", $time);
        sw = 0; rst = 1; @(negedge clk); rst = 0; @(negedge clk);
        sw = 1; @(negedge clk);
        bR = 1; @(negedge clk); bR = 0;                    // SET_HOUR
        for (i = 0; i < 11; i = i + 1) begin bU = 1; @(negedge clk); bU = 0; @(negedge clk); end
        bL = 1; @(negedge clk); bL = 0;                    // SET_HOUR -> SET_MIN_1 (왼쪽 끝에서 돌아감)
        bD = 1; @(negedge clk); bD = 0;                    // 0 -> 59
        sw = 0; @(negedge clk);
        if ({hour, min, sec, msec} !== {5'd23, 6'd59, 6'd0, 7'd0}) begin ef[7] = ef[7] + 1; $display("E7 FAIL setup %0d:%0d:%0d.%0d", hour, min, sec, msec); end
        for (i = 0; i < 5999; i = i + 1) begin tick = 1; @(negedge clk); end
        tick = 0; @(negedge clk); @(negedge clk); @(negedge clk);
        if ({hour, min, sec, msec} !== {5'd23, 6'd59, 6'd59, 7'd99}) begin ef[7] = ef[7] + 1; $display("E7 FAIL setup %0d:%0d:%0d.%0d exp 23:59:59.99", hour, min, sec, msec); end
        tick = 1; @(negedge clk); tick = 0;
        @(negedge clk); @(negedge clk); @(negedge clk); @(negedge clk);
        if ({hour, min, sec, msec} !== {5'd0, 6'd0, 6'd0, 7'd0}) begin ef[7] = ef[7] + 1; $display("E7 FAIL midnight %0d:%0d:%0d.%0d exp 00:00:00.00", hour, min, sec, msec); end

        // =====================================================================
        // E8 U + D 같은 클럭 -> U (분 일 0 -> 1, 시 12 -> 13)
        // =====================================================================
        $display("E8 start %0d ns", $time);
        sw = 0; rst = 1; @(negedge clk); rst = 0; @(negedge clk);
        sw = 1; @(negedge clk);
        bU = 1; bD = 1; #1;
        if (o_up !== 1'b1 || o_down !== 1'b0) begin ef[8] = ef[8] + 1; $display("E8 FAIL pulse o_up %b o_down %b", o_up, o_down); end
        @(negedge clk); bU = 0; bD = 0;
        if (min !== 6'd1 || hour !== 5'd12) begin ef[8] = ef[8] + 1; $display("E8 FAIL MIN_1 U+D: %0d:%0d exp 12:01", hour, min); end
        bR = 1; @(negedge clk); bR = 0;                    // SET_HOUR
        bU = 1; bD = 1; @(negedge clk); bU = 0; bD = 0;
        if (hour !== 5'd13 || min !== 6'd1) begin ef[8] = ef[8] + 1; $display("E8 FAIL HOUR U+D: %0d:%0d exp 13:01", hour, min); end

        // =====================================================================
        // E9 자리 이동 순환(L 3번, R 3번) + L + R 같은 클럭 -> L
        // =====================================================================
        $display("E9 start %0d ns", $time);
        sw = 0; rst = 1; @(negedge clk); rst = 0; @(negedge clk);
        sw = 1; @(negedge clk);
        bL = 1; @(negedge clk); bL = 0; if (cursor !== 2'd1) begin ef[9] = ef[9] + 1; $display("E9 FAIL L1 cursor %0d exp 1", cursor); end
        bL = 1; @(negedge clk); bL = 0; if (cursor !== 2'd2) begin ef[9] = ef[9] + 1; $display("E9 FAIL L2 cursor %0d exp 2", cursor); end
        bL = 1; @(negedge clk); bL = 0; if (cursor !== 2'd0) begin ef[9] = ef[9] + 1; $display("E9 FAIL L3 cursor %0d exp 0", cursor); end
        bR = 1; @(negedge clk); bR = 0; if (cursor !== 2'd2) begin ef[9] = ef[9] + 1; $display("E9 FAIL R1 cursor %0d exp 2", cursor); end
        bR = 1; @(negedge clk); bR = 0; if (cursor !== 2'd1) begin ef[9] = ef[9] + 1; $display("E9 FAIL R2 cursor %0d exp 1", cursor); end
        bR = 1; @(negedge clk); bR = 0; if (cursor !== 2'd0) begin ef[9] = ef[9] + 1; $display("E9 FAIL R3 cursor %0d exp 0", cursor); end
        bL = 1; bR = 1; @(negedge clk); bL = 0; bR = 0; if (cursor !== 2'd1) begin ef[9] = ef[9] + 1; $display("E9 FAIL L+R at MIN_1 cursor %0d exp 1", cursor); end
        bL = 1; bR = 1; @(negedge clk); bL = 0; bR = 0; if (cursor !== 2'd2) begin ef[9] = ef[9] + 1; $display("E9 FAIL L+R at MIN_10 cursor %0d exp 2", cursor); end
        bL = 1; bR = 1; @(negedge clk); bL = 0; bR = 0; if (cursor !== 2'd0) begin ef[9] = ef[9] + 1; $display("E9 FAIL L+R at HOUR cursor %0d exp 0", cursor); end
        if ({hour, min} !== {5'd12, 6'd0}) begin ef[9] = ef[9] + 1; $display("E9 FAIL moving changed time %0d:%0d", hour, min); end

        // =====================================================================
        // E10 sw2 내림 + 버튼 같은 클럭 -> NORMAL, 버튼 무시 (세 설정 상태 모두), 다시 올리면 SET_MIN_1
        // =====================================================================
        $display("E10 start %0d ns", $time);
        sw = 0; rst = 1; @(negedge clk); rst = 0; @(negedge clk);
        sw = 1; @(negedge clk);                            // SET_MIN_1
        sw = 0; bU = 1; #1;
        if (o_up !== 1'b0 || o_down !== 1'b0) begin ef[10] = ef[10] + 1; $display("E10 FAIL MIN_1 pulse with sw2 down o_up %b", o_up); end
        @(negedge clk); bU = 0;
        if (cu.c_state !== 2'b00 || cursor !== 2'd3 || min !== 6'd0) begin ef[10] = ef[10] + 1; $display("E10 FAIL MIN_1: state %b min %0d", cu.c_state, min); end
        sw = 1; @(negedge clk);
        bL = 1; @(negedge clk); bL = 0;                    // SET_MIN_10
        sw = 0; bD = 1; bL = 1; @(negedge clk); bD = 0; bL = 0;
        if (cu.c_state !== 2'b00 || cursor !== 2'd3 || min !== 6'd0) begin ef[10] = ef[10] + 1; $display("E10 FAIL MIN_10: state %b min %0d", cu.c_state, min); end
        sw = 1; @(negedge clk);
        if (cursor !== 2'd0) begin ef[10] = ef[10] + 1; $display("E10 FAIL re-enter cursor %0d exp 0", cursor); end
        bR = 1; @(negedge clk); bR = 0;                    // SET_HOUR
        sw = 0; bU = 1; bR = 1; @(negedge clk); bU = 0; bR = 0;
        if (cu.c_state !== 2'b00 || cursor !== 2'd3 || hour !== 5'd12) begin ef[10] = ef[10] + 1; $display("E10 FAIL HOUR: state %b hour %0d", cu.c_state, hour); end
        sw = 1; @(negedge clk);
        if (cursor !== 2'd0 || cu.c_state !== 2'b11) begin ef[10] = ef[10] + 1; $display("E10 FAIL re-enter from HOUR cursor %0d exp 0", cursor); end

        // =====================================================================
        // E11 tick(자리 넘김) + 버튼이 같은 클럭에 같은 카운터 -> tick 만
        //   a) 분 일 D   : 12:05:59.99 -> 12:06 (D 무시)
        //   b) 분 십 U   : 12:06:59.99 -> 12:07 (+10 무시)
        //   c) 시 U      : 12:59:59.99 -> 13:00 (U 무시)
        // =====================================================================
        $display("E11 start %0d ns", $time);
        sw = 0; rst = 1; @(negedge clk); rst = 0; @(negedge clk);
        sw = 1; @(negedge clk);
        for (i = 0; i < 5; i = i + 1) begin bU = 1; @(negedge clk); bU = 0; @(negedge clk); end
        for (i = 0; i < 5999; i = i + 1) begin tick = 1; @(negedge clk); end
        tick = 0; @(negedge clk); @(negedge clk); @(negedge clk);
        if ({hour, min, sec, msec} !== {5'd12, 6'd5, 6'd59, 7'd99}) begin ef[11] = ef[11] + 1; $display("E11a FAIL setup %0d:%0d:%0d.%0d", hour, min, sec, msec); end
        tick = 1; @(negedge clk); tick = 0;                // msec 99 -> 0
        @(negedge clk);                                    // sec 59 -> 0, 분 카운터 i_tick = 1
        if (dp.w_tick_min !== 1'b1) begin ef[11] = ef[11] + 1; $display("E11a FAIL setup: minute tick not on this clock"); end
        bD = 1; @(negedge clk); bD = 0;
        if (min !== 6'd6 || hour !== 5'd12) begin ef[11] = ef[11] + 1; $display("E11a FAIL tick+D: %0d:%0d exp 12:06", hour, min); end
        bL = 1; @(negedge clk); bL = 0;                    // SET_MIN_10
        for (i = 0; i < 5999; i = i + 1) begin tick = 1; @(negedge clk); end
        tick = 0; @(negedge clk); @(negedge clk); @(negedge clk);
        if ({hour, min, sec, msec} !== {5'd12, 6'd6, 6'd59, 7'd99}) begin ef[11] = ef[11] + 1; $display("E11b FAIL setup %0d:%0d:%0d.%0d", hour, min, sec, msec); end
        tick = 1; @(negedge clk); tick = 0;
        @(negedge clk);
        if (dp.w_tick_min !== 1'b1) begin ef[11] = ef[11] + 1; $display("E11b FAIL setup: minute tick not on this clock"); end
        bU = 1; @(negedge clk); bU = 0;
        if (min !== 6'd7 || hour !== 5'd12) begin ef[11] = ef[11] + 1; $display("E11b FAIL tick+U(+10): %0d:%0d exp 12:07", hour, min); end
        sw = 0; rst = 1; @(negedge clk); rst = 0; @(negedge clk);
        sw = 1; @(negedge clk);
        bD = 1; @(negedge clk); bD = 0;                    // 분 59
        bR = 1; @(negedge clk); bR = 0;                    // SET_HOUR
        for (i = 0; i < 5999; i = i + 1) begin tick = 1; @(negedge clk); end
        tick = 0; @(negedge clk); @(negedge clk); @(negedge clk);
        if ({hour, min, sec, msec} !== {5'd12, 6'd59, 6'd59, 7'd99}) begin ef[11] = ef[11] + 1; $display("E11c FAIL setup %0d:%0d:%0d.%0d", hour, min, sec, msec); end
        tick = 1; @(negedge clk); tick = 0;
        @(negedge clk); @(negedge clk);                    // 시 카운터 i_tick = 1
        if (dp.w_tick_hour !== 1'b1) begin ef[11] = ef[11] + 1; $display("E11c FAIL setup: hour tick not on this clock"); end
        bU = 1; @(negedge clk); bU = 0;
        if (hour !== 5'd13 || min !== 6'd0) begin ef[11] = ef[11] + 1; $display("E11c FAIL tick+U: %0d:%0d exp 13:00", hour, min); end

        // =====================================================================
        // E12 tick 이 다른 카운터(1/100초)로 갈 때 같은 클럭 U -> 둘 다 반영
        //     설정 버튼은 초 · 1/100초를 안 바꿈, 설정 중에도 시계는 흐름
        // =====================================================================
        $display("E12 start %0d ns", $time);
        sw = 0; rst = 1; @(negedge clk); rst = 0; @(negedge clk);
        sw = 1; @(negedge clk);
        for (i = 0; i < 10; i = i + 1) begin tick = 1; @(negedge clk); end
        tick = 0; @(negedge clk);
        tick = 1; bU = 1; @(negedge clk); tick = 0; bU = 0;
        if (msec !== 7'd11 || min !== 6'd1) begin ef[12] = ef[12] + 1; $display("E12 FAIL msec-tick+U: msec %0d min %0d exp 11, 1", msec, min); end
        sec_a = sec; msec_a = msec;
        bU = 1; @(negedge clk); bU = 0; bD = 1; @(negedge clk); bD = 0;
        bL = 1; @(negedge clk); bL = 0; bU = 1; @(negedge clk); bU = 0;
        bL = 1; @(negedge clk); bL = 0; bD = 1; @(negedge clk); bD = 0;
        if (sec !== sec_a || msec !== msec_a) begin ef[12] = ef[12] + 1; $display("E12 FAIL set buttons changed sec/msec %0d.%0d", sec, msec); end
        if ({hour, min} !== {5'd11, 6'd11}) begin ef[12] = ef[12] + 1; $display("E12 FAIL set result %0d:%0d exp 11:11", hour, min); end
        for (i = 0; i < 100; i = i + 1) begin tick = 1; @(negedge clk); end
        tick = 0; @(negedge clk); @(negedge clk);
        if (sec !== 6'd1 || msec !== 7'd11 || cu.c_state === 2'b00) begin ef[12] = ef[12] + 1; $display("E12 FAIL time not flowing in SET: sec %0d msec %0d", sec, msec); end

        // =====================================================================
        // E13 설정 중 리셋 (비동기, 클럭 에지 사이) -> 즉시 NORMAL, 12:00:00.00
        //     sw2 = 1 인 채 리셋 해제 -> 다음 클럭 SET_MIN_1
        // =====================================================================
        $display("E13 start %0d ns", $time);
        sw = 0; rst = 1; @(negedge clk); rst = 0; @(negedge clk);
        sw = 1; @(negedge clk);
        bR = 1; @(negedge clk); bR = 0;
        for (i = 0; i < 3; i = i + 1) begin bU = 1; @(negedge clk); bU = 0; @(negedge clk); end
        bL = 1; @(negedge clk); bL = 0;
        for (i = 0; i < 7; i = i + 1) begin bU = 1; @(negedge clk); bU = 0; @(negedge clk); end
        bR = 1; @(negedge clk); bR = 0;                    // 다시 SET_HOUR
        for (i = 0; i < 50; i = i + 1) begin tick = 1; @(negedge clk); end
        tick = 0; @(negedge clk);
        if ({hour, min} !== {5'd15, 6'd7} || cu.c_state !== 2'b01) begin ef[13] = ef[13] + 1; $display("E13 FAIL setup %0d:%0d state %b", hour, min, cu.c_state); end
        #2 rst = 1; #1;                                     // 다음 posedge(+2 ns)보다 먼저 확인
        if (cu.c_state !== 2'b00 || cursor !== 2'd3 || set_mode !== 1'b0) begin ef[13] = ef[13] + 1; $display("E13 FAIL async reset state %b cursor %0d", cu.c_state, cursor); end
        if ({hour, min, sec, msec} !== {5'd12, 6'd0, 6'd0, 7'd0}) begin ef[13] = ef[13] + 1; $display("E13 FAIL async reset time %0d:%0d:%0d.%0d", hour, min, sec, msec); end
        @(negedge clk); @(negedge clk);
        if (cu.c_state !== 2'b00) begin ef[13] = ef[13] + 1; $display("E13 FAIL left NORMAL during reset"); end
        rst = 0; @(negedge clk);
        if (cu.c_state !== 2'b11 || cursor !== 2'd0 || {hour, min} !== {5'd12, 6'd0}) begin ef[13] = ef[13] + 1; $display("E13 FAIL after release state %b cursor %0d", cu.c_state, cursor); end

        // =====================================================================
        // E14 자리 이동(L/R) + U/D 같은 클럭 (사양에 규칙 없음 -> 관찰)
        //     사양으로 확인하는 것: 자리는 L/R 대로 움직임, 한 칸에만 한 번 반영, 다른 칸 올림 없음
        // =====================================================================
        $display("E14 start %0d ns", $time);
        sw = 0; rst = 1; @(negedge clk); rst = 0; @(negedge clk);
        sw = 1; @(negedge clk);
        for (i = 0; i < 5; i = i + 1) begin bU = 1; @(negedge clk); bU = 0; @(negedge clk); end   // 12:05, SET_MIN_1
        bL = 1; bU = 1; @(negedge clk); bL = 0; bU = 0;
        if (min == 6'd6) $display("E14 INFO L+U at SET_MIN_1 (12:05): min -> 06 = applied to OLD digit (min_1 +1), cursor -> %0d", cursor);
        else if (min == 6'd15) $display("E14 INFO L+U at SET_MIN_1 (12:05): min -> 15 = applied to NEW digit (min_10 +10), cursor -> %0d", cursor);
        else if (min == 6'd5) $display("E14 INFO L+U at SET_MIN_1 (12:05): min -> 05 = U ignored, cursor -> %0d", cursor);
        else begin ef[14] = ef[14] + 1; $display("E14 FAIL L+U min %0d not in {5, 6, 15}", min); end
        if (cursor !== 2'd1 || hour !== 5'd12) begin ef[14] = ef[14] + 1; $display("E14 FAIL L+U cursor %0d hour %0d", cursor, hour); end
        min_a = min;
        if (min_a < 6'd10) exp_new = min_a + 6'd50; else exp_new = min_a - 6'd10;   // 분 십 -10 (60 으로 돌기)
        bL = 1; @(negedge clk); bL = 0;                    // SET_HOUR
        bR = 1; bD = 1; @(negedge clk); bR = 0; bD = 0;
        if (hour == 5'd11 && min == min_a) $display("E14 INFO R+D at SET_HOUR (12:%0d): hour -> 11 = applied to OLD digit (hour -1), cursor -> %0d", min_a, cursor);
        else if (hour == 5'd12 && min == exp_new) $display("E14 INFO R+D at SET_HOUR: min -> %0d = applied to NEW digit (min_10 -10), cursor -> %0d", min, cursor);
        else if (hour == 5'd12 && min == min_a) $display("E14 INFO R+D at SET_HOUR: D ignored, cursor -> %0d", cursor);
        else begin ef[14] = ef[14] + 1; $display("E14 FAIL R+D %0d:%0d unexpected", hour, min); end
        if (cursor !== 2'd1) begin ef[14] = ef[14] + 1; $display("E14 FAIL R+D cursor %0d exp 1", cursor); end

        // =====================================================================
        // 커버리지 요약 (상태 · 전이)
        // =====================================================================
        sw = 0; @(negedge clk); @(negedge clk);
        $display("COV transitions (bit index = {c_state, n_state}) = %b", cov);
        if (cov[0]  !== 1'b1) begin cov_miss = cov_miss + 1; $display("COV MISS NORMAL->NORMAL"); end
        if (cov[3]  !== 1'b1) begin cov_miss = cov_miss + 1; $display("COV MISS NORMAL->SET_MIN_1"); end
        if (cov[15] !== 1'b1) begin cov_miss = cov_miss + 1; $display("COV MISS SET_MIN_1 hold"); end
        if (cov[14] !== 1'b1) begin cov_miss = cov_miss + 1; $display("COV MISS SET_MIN_1->SET_MIN_10 (L)"); end
        if (cov[13] !== 1'b1) begin cov_miss = cov_miss + 1; $display("COV MISS SET_MIN_1->SET_HOUR (R)"); end
        if (cov[12] !== 1'b1) begin cov_miss = cov_miss + 1; $display("COV MISS SET_MIN_1->NORMAL"); end
        if (cov[10] !== 1'b1) begin cov_miss = cov_miss + 1; $display("COV MISS SET_MIN_10 hold"); end
        if (cov[9]  !== 1'b1) begin cov_miss = cov_miss + 1; $display("COV MISS SET_MIN_10->SET_HOUR (L)"); end
        if (cov[11] !== 1'b1) begin cov_miss = cov_miss + 1; $display("COV MISS SET_MIN_10->SET_MIN_1 (R)"); end
        if (cov[8]  !== 1'b1) begin cov_miss = cov_miss + 1; $display("COV MISS SET_MIN_10->NORMAL"); end
        if (cov[5]  !== 1'b1) begin cov_miss = cov_miss + 1; $display("COV MISS SET_HOUR hold"); end
        if (cov[7]  !== 1'b1) begin cov_miss = cov_miss + 1; $display("COV MISS SET_HOUR->SET_MIN_1 (L)"); end
        if (cov[6]  !== 1'b1) begin cov_miss = cov_miss + 1; $display("COV MISS SET_HOUR->SET_MIN_10 (R)"); end
        if (cov[4]  !== 1'b1) begin cov_miss = cov_miss + 1; $display("COV MISS SET_HOUR->NORMAL"); end
        if (cov[1] === 1'b1 || cov[2] === 1'b1) begin err = err + 1; $display("COV FAIL illegal NORMAL->SET_HOUR/SET_MIN_10 seen"); end
        $display("COV missing transitions = %0d (of 14 listed)", cov_miss);

        // =====================================================================
        // 결과
        // =====================================================================
        for (k = 1; k <= 14; k = k + 1) begin
            if (ef[k] == 0) $display("RESULT E%0d PASS", k);
            else $display("RESULT E%0d FAIL (%0d)", k, ef[k]);
            err = err + ef[k];
        end
        $display("TOTAL MISMATCH = %0d", err);
        $finish;
    end
endmodule
