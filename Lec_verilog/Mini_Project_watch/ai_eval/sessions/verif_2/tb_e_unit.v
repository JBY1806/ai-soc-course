`timescale 1ns / 1ps
// =====================================================================
// verif_2 단위 TB : watch_control_unit + watch_datapath (Top 과 같은 연결)
// 대상 : submit_1019 제출판 (세션 폴더 src_copy 에 원본 그대로 복사, md5 21개 일치)
// 규칙 : 입력은 negedge 에서 바꾼다, 비교는 !==, 실패는 "Ex FAIL", 끝에 TOTAL MISMATCH
//        tick 은 TB 가 직접 넣는다 (설계 파라미터는 바꾸지 않음)
// 상태 인코딩 (watch_control_unit.sv:24) : NORMAL 00, SET_HOUR 01, SET_MIN_10 10, SET_MIN_1 11
// cursor : 0 분 일, 1 분 십, 2 시, 3 없음(NORMAL)
// 수업 문법만 : reg/wire, initial, always, for, if, #, @(negedge clk), $display (task/function 없음)
// =====================================================================
module tb_e_unit;
    reg clk, rst, sw2, bR, bL, bU, bD, tick;
    wire [1:0] cursor;
    wire       up, down;
    wire [6:0] msec;
    wire [5:0] sec, min;
    wire [4:0] hour;

    integer err, e0, i, j, k, n_up, n_down, n_both, cov_miss;
    reg [15:0] cov;            // 전이 커버리지 : cov[{c_state, n_state}]
    reg [6:0] msec_s;
    reg [5:0] sec_s, min_s, exp_min;
    reg [4:0] hour_s, exp_hour;
    reg [1:0] exp_cur, exp_st;
    reg       up_s, down_s;

    watch_control_unit cu (
        .i_clk      (clk),
        .i_rst      (rst),
        .i_wt_btn_R (bR),
        .i_wt_btn_L (bL),
        .i_wt_btn_U (bU),
        .i_wt_btn_D (bD),
        .i_set_sw2  (sw2),
        .o_wt_cursor(cursor),
        .o_wt_up    (up),
        .o_wt_down  (down)
    );

    watch_datapath dp (
        .i_clk      (clk),
        .i_rst      (rst),
        .i_tick_10ms(tick),
        .i_wt_cursor(cursor),
        .i_wt_up    (up),
        .i_wt_down  (down),
        .o_wt_msec  (msec),
        .o_wt_sec   (sec),
        .o_wt_min   (min),
        .o_wt_hour  (hour)
    );

    always #5 clk = ~clk;   // 100 MHz

    // posedge 마다 : 지나간 전이 기록, up/down 펄스 세기
    always @(posedge clk) begin
        if (rst === 1'b0) begin
            cov[{cu.c_state, cu.n_state}] <= 1'b1;
            if (up === 1'b1) n_up = n_up + 1;
            if (down === 1'b1) n_down = n_down + 1;
            if (up === 1'b1 && down === 1'b1) n_both = n_both + 1;
        end
    end

    initial begin
        clk = 0; rst = 1; sw2 = 0; bR = 0; bL = 0; bU = 0; bD = 0; tick = 0;
        err = 0; n_up = 0; n_down = 0; n_both = 0; cov = 16'd0; cov_miss = 0;
        repeat (3) @(negedge clk);

        // =============================================================
        // E1 리셋값 + 리셋 해제 직후 버튼 (sw2 = 0)
        //    근거 02:21 리셋 12:00:00.00 / 02:22-23 sw2=0 이면 NORMAL, cursor 3
        // =============================================================
        e0 = err;
        if ({hour, min, sec, msec} !== {5'd12, 6'd0, 6'd0, 7'd0} || cu.c_state !== 2'b00 || cursor !== 2'd3) begin
            err = err + 1; $display("E1 FAIL reset value %0d:%0d:%0d.%0d state %b cursor %0d exp 12:0:0.0 00 3", hour, min, sec, msec, cu.c_state, cursor);
        end
        rst = 0; bU = 1;                       // 해제와 같은 순간 U
        @(negedge clk) bU = 0; bD = 1;
        @(negedge clk) bD = 0; bL = 1;
        @(negedge clk) bL = 0; bR = 1;
        @(negedge clk) bR = 0; bU = 1; bD = 1; bL = 1; bR = 1;
        @(negedge clk) bU = 0; bD = 0; bL = 0; bR = 0;
        @(negedge clk);
        if (cu.c_state !== 2'b00 || cursor !== 2'd3) begin
            err = err + 1; $display("E1 FAIL state %b cursor %0d exp 00 3", cu.c_state, cursor);
        end
        if ({hour, min, sec, msec} !== {5'd12, 6'd0, 6'd0, 7'd0}) begin
            err = err + 1; $display("E1 FAIL time %0d:%0d:%0d.%0d exp 12:0:0.0", hour, min, sec, msec);
        end
        if (n_up !== 0 || n_down !== 0) begin
            err = err + 1; $display("E1 FAIL up/down pulses %0d %0d exp 0 0", n_up, n_down);
        end
        if (err == e0) $display("RESULT E1 PASS"); else $display("RESULT E1 FAIL");

        // =============================================================
        // E2 sw2 = 1 인 채 리셋 해제, 해제 직후 첫 클럭 U
        //    근거 02:22 설정 모드는 항상 분 일(cursor 0)부터
        //    첫 클럭 U 의 반영 여부는 02 에 규칙 없음 -> INFO, 다음 U 는 +1
        // =============================================================
        e0 = err;
        @(negedge clk) rst = 1; sw2 = 1;
        @(negedge clk) rst = 0; bU = 1;
        @(negedge clk) bU = 0;
        if (cu.c_state !== 2'b11 || cursor !== 2'd0) begin
            err = err + 1; $display("E2 FAIL after release state %b cursor %0d exp 11 0", cu.c_state, cursor);
        end
        $display("E2 INFO first-clock U after release: min = %0d (0 = ignored, c_state was NORMAL on that edge)", min);
        min_s = min;
        @(negedge clk) bU = 1;
        @(negedge clk) bU = 0;
        if (min !== min_s + 6'd1 || hour !== 5'd12) begin
            err = err + 1; $display("E2 FAIL second U: %0d:%0d exp 12:%0d", hour, min, min_s + 1);
        end
        if (err == e0) $display("RESULT E2 PASS"); else $display("RESULT E2 FAIL");

        // =============================================================
        // E3 설정 중(SET_HOUR, 15:mm, msec 5) 클럭 에지 사이 비동기 리셋, sw2 = 1 인 채 해제
        //    근거 01:9 비동기 positive 리셋 / 02:21 12:00:00.00 / 02:22 재진입 분 일
        // =============================================================
        e0 = err;
        @(negedge clk) bR = 1; @(negedge clk) bR = 0;                 // SET_MIN_1 -> SET_HOUR
        for (i = 0; i < 3; i = i + 1) begin @(negedge clk) bU = 1; @(negedge clk) bU = 0; end
        @(negedge clk) bL = 1; @(negedge clk) bL = 0;                 // SET_HOUR -> SET_MIN_1
        for (i = 0; i < 6; i = i + 1) begin @(negedge clk) bU = 1; @(negedge clk) bU = 0; end
        @(negedge clk) bR = 1; @(negedge clk) bR = 0;                 // -> SET_HOUR
        for (i = 0; i < 5; i = i + 1) begin @(negedge clk) tick = 1; @(negedge clk) tick = 0; end
        @(negedge clk);
        if (cu.c_state !== 2'b01 || hour !== 5'd15 || msec !== 7'd5) begin
            err = err + 1; $display("E3 FAIL setup state %b time %0d:%0d .%0d exp 01 15:xx .5", cu.c_state, hour, min, msec);
        end
        $display("E3 INFO before reset: state %b %0d:%0d:%0d.%0d", cu.c_state, hour, min, sec, msec);
        #2 rst = 1;                                                    // negedge + 2 ns (에지 사이)
        #1;
        if (cu.c_state !== 2'b00 || cursor !== 2'd3 || {hour, min, sec, msec} !== {5'd12, 6'd0, 6'd0, 7'd0}) begin
            err = err + 1; $display("E3 FAIL async reset (before next posedge): state %b cursor %0d %0d:%0d:%0d.%0d", cu.c_state, cursor, hour, min, sec, msec);
        end
        @(negedge clk) rst = 0;                                        // sw2 = 1 그대로
        @(negedge clk);
        if (cu.c_state !== 2'b11 || cursor !== 2'd0) begin
            err = err + 1; $display("E3 FAIL re-entry state %b cursor %0d exp 11 0", cu.c_state, cursor);
        end
        if (err == e0) $display("RESULT E3 PASS"); else $display("RESULT E3 FAIL");

        // =============================================================
        // E4 분 일 경계 (SET_MIN_1, 12:00) : 0-1, 59+1, 09+1, 10-1
        //    근거 02:25 U +1, D -1, 그 칸만 돌고 올림/내림 없음 (분 59 +1 -> 0, 시 그대로)
        // =============================================================
        e0 = err;
        @(negedge clk) bD = 1; @(negedge clk) bD = 0;
        if (min !== 6'd59 || hour !== 5'd12) begin err = err + 1; $display("E4 FAIL 00-1 -> %0d:%0d exp 12:59", hour, min); end
        @(negedge clk) bU = 1; @(negedge clk) bU = 0;
        if (min !== 6'd0 || hour !== 5'd12) begin err = err + 1; $display("E4 FAIL 59+1 -> %0d:%0d exp 12:00", hour, min); end
        for (i = 0; i < 9; i = i + 1) begin @(negedge clk) bU = 1; @(negedge clk) bU = 0; end
        @(negedge clk) bU = 1; @(negedge clk) bU = 0;
        if (min !== 6'd10 || hour !== 5'd12) begin err = err + 1; $display("E4 FAIL 09+1 -> %0d:%0d exp 12:10", hour, min); end
        @(negedge clk) bD = 1; @(negedge clk) bD = 0;
        if (min !== 6'd9 || hour !== 5'd12) begin err = err + 1; $display("E4 FAIL 10-1 -> %0d:%0d exp 12:09", hour, min); end
        for (i = 0; i < 9; i = i + 1) begin @(negedge clk) bD = 1; @(negedge clk) bD = 0; end
        if ({hour, min, sec, msec} !== {5'd12, 6'd0, 6'd0, 7'd0}) begin err = err + 1; $display("E4 FAIL back to 12:00 -> %0d:%0d:%0d.%0d", hour, min, sec, msec); end
        if (err == e0) $display("RESULT E4 PASS"); else $display("RESULT E4 FAIL");

        // =============================================================
        // E5 분 십 경계 (SET_MIN_10) : 00-10, 50+10, 55+10, 05-10
        //    근거 02:25 분 십의 자리는 +-10, 그 칸만 돈다 (십 자리 0~5 순환, 일 자리 그대로)
        // =============================================================
        e0 = err;
        @(negedge clk) bL = 1; @(negedge clk) bL = 0;
        if (cu.c_state !== 2'b10 || cursor !== 2'd1) begin err = err + 1; $display("E5 FAIL L -> state %b cursor %0d exp 10 1", cu.c_state, cursor); end
        @(negedge clk) bD = 1; @(negedge clk) bD = 0;
        if (min !== 6'd50 || hour !== 5'd12) begin err = err + 1; $display("E5 FAIL 00-10 -> %0d:%0d exp 12:50", hour, min); end
        @(negedge clk) bU = 1; @(negedge clk) bU = 0;
        if (min !== 6'd0 || hour !== 5'd12) begin err = err + 1; $display("E5 FAIL 50+10 -> %0d:%0d exp 12:00", hour, min); end
        @(negedge clk) bD = 1; @(negedge clk) bD = 0;                 // 50
        @(negedge clk) bR = 1; @(negedge clk) bR = 0;                 // -> SET_MIN_1
        for (i = 0; i < 5; i = i + 1) begin @(negedge clk) bU = 1; @(negedge clk) bU = 0; end   // 55
        @(negedge clk) bL = 1; @(negedge clk) bL = 0;                 // -> SET_MIN_10
        if (min !== 6'd55 || cursor !== 2'd1) begin err = err + 1; $display("E5 FAIL setup min %0d cursor %0d exp 55 1", min, cursor); end
        @(negedge clk) bU = 1; @(negedge clk) bU = 0;
        if (min !== 6'd5 || hour !== 5'd12) begin err = err + 1; $display("E5 FAIL 55+10 -> %0d:%0d exp 12:05", hour, min); end
        @(negedge clk) bD = 1; @(negedge clk) bD = 0;
        if (min !== 6'd55 || hour !== 5'd12) begin err = err + 1; $display("E5 FAIL 05-10 -> %0d:%0d exp 12:55", hour, min); end
        if (err == e0) $display("RESULT E5 PASS"); else $display("RESULT E5 FAIL");

        // =============================================================
        // E6 시 경계 (SET_HOUR) : 12 -> 23 (+11), 23+1, 0-1
        //    근거 02:21 내부 0~23 / 02:25 그 칸만 돈다 (분 그대로)
        // =============================================================
        e0 = err;
        @(negedge clk) bL = 1; @(negedge clk) bL = 0;
        if (cu.c_state !== 2'b01 || cursor !== 2'd2) begin err = err + 1; $display("E6 FAIL L -> state %b cursor %0d exp 01 2", cu.c_state, cursor); end
        for (i = 0; i < 11; i = i + 1) begin @(negedge clk) bU = 1; @(negedge clk) bU = 0; end
        if (hour !== 5'd23 || min !== 6'd55) begin err = err + 1; $display("E6 FAIL 12+11 -> %0d:%0d exp 23:55", hour, min); end
        @(negedge clk) bU = 1; @(negedge clk) bU = 0;
        if (hour !== 5'd0 || min !== 6'd55) begin err = err + 1; $display("E6 FAIL 23+1 -> %0d:%0d exp 0:55", hour, min); end
        @(negedge clk) bD = 1; @(negedge clk) bD = 0;
        if (hour !== 5'd23 || min !== 6'd55) begin err = err + 1; $display("E6 FAIL 0-1 -> %0d:%0d exp 23:55", hour, min); end
        if (err == e0) $display("RESULT E6 PASS"); else $display("RESULT E6 FAIL");

        // =============================================================
        // E7 자정 : 23:59:59.99 + tick -> 00:00:00.00 (sw2 = 0, NORMAL)
        //    근거 02:21 내부 24시간, 100 Hz tick 으로 항상 흐른다
        // =============================================================
        e0 = err;
        @(negedge clk) bR = 1; @(negedge clk) bR = 0;                 // SET_HOUR -> SET_MIN_10
        @(negedge clk) bR = 1; @(negedge clk) bR = 0;                 // -> SET_MIN_1
        for (i = 0; i < 4; i = i + 1) begin @(negedge clk) bU = 1; @(negedge clk) bU = 0; end   // 59
        @(negedge clk) sw2 = 0;
        @(negedge clk);
        if (cu.c_state !== 2'b00 || {hour, min, sec, msec} !== {5'd23, 6'd59, 6'd0, 7'd0}) begin
            err = err + 1; $display("E7 FAIL setup state %b %0d:%0d:%0d.%0d exp 00 23:59:0.0", cu.c_state, hour, min, sec, msec);
        end
        for (i = 0; i < 5999; i = i + 1) begin @(negedge clk) tick = 1; @(negedge clk) tick = 0; end
        @(negedge clk);
        if ({hour, min, sec, msec} !== {5'd23, 6'd59, 6'd59, 7'd99}) begin
            err = err + 1; $display("E7 FAIL after 5999 ticks %0d:%0d:%0d.%0d exp 23:59:59.99", hour, min, sec, msec);
        end
        @(negedge clk) tick = 1;
        @(negedge clk) tick = 0;
        $display("E7 INFO ripple +1clk %0d:%0d:%0d.%0d", hour, min, sec, msec);
        @(negedge clk) $display("E7 INFO ripple +2clk %0d:%0d:%0d.%0d", hour, min, sec, msec);
        @(negedge clk) $display("E7 INFO ripple +3clk %0d:%0d:%0d.%0d", hour, min, sec, msec);
        @(negedge clk) $display("E7 INFO ripple +4clk %0d:%0d:%0d.%0d", hour, min, sec, msec);
        repeat (3) @(negedge clk);
        if ({hour, min, sec, msec} !== {5'd0, 6'd0, 6'd0, 7'd0}) begin
            err = err + 1; $display("E7 FAIL midnight %0d:%0d:%0d.%0d exp 0:0:0.0", hour, min, sec, msec);
        end
        if (err == e0) $display("RESULT E7 PASS"); else $display("RESULT E7 FAIL");

        // =============================================================
        // E8 U + D 같은 클럭 (모듈 단독) : SET_MIN_1, SET_MIN_10, SET_HOUR
        //    근거 02:27 "U 와 D 같은 클럭 -> U"  => 기대 up=1 down=0, 지금 자리 +1(+10)
        //    (코드 9줄 · 88-91줄은 '무효' = 10/18 팀 결정. 기대값은 02 그대로 두고 실제 동작을 OBS 로 기록)
        // =============================================================
        e0 = err;
        @(negedge clk) sw2 = 1;
        @(negedge clk);
        // (a) SET_MIN_1
        min_s = min; hour_s = hour;
        exp_min = (min_s + 1 >= 60) ? min_s + 1 - 60 : min_s + 1;
        @(negedge clk) bU = 1; bD = 1;
        #1 up_s = up; down_s = down;
        @(negedge clk) bU = 0; bD = 0;
        if (up_s !== 1'b1 || down_s !== 1'b0 || min !== exp_min || hour !== hour_s) begin
            err = err + 1; $display("E8 FAIL SET_MIN_1 U+D: up=%b down=%b min %0d->%0d (02 spec: up=1 down=0 min %0d)", up_s, down_s, min_s, min, exp_min);
        end
        if (up_s === 1'b0 && down_s === 1'b0 && min === min_s && hour === hour_s) $display("E8 OBS SET_MIN_1 U+D = INVALID (up=0 down=0, no change)");
        else $display("E8 OBS SET_MIN_1 U+D = NOT invalid (up=%b down=%b %0d:%0d)", up_s, down_s, hour, min);
        // (b) SET_MIN_10
        @(negedge clk) bL = 1; @(negedge clk) bL = 0;
        min_s = min; hour_s = hour;
        exp_min = (min_s + 10 >= 60) ? min_s + 10 - 60 : min_s + 10;
        @(negedge clk) bU = 1; bD = 1;
        #1 up_s = up; down_s = down;
        @(negedge clk) bU = 0; bD = 0;
        if (up_s !== 1'b1 || down_s !== 1'b0 || min !== exp_min || hour !== hour_s) begin
            err = err + 1; $display("E8 FAIL SET_MIN_10 U+D: up=%b down=%b min %0d->%0d (02 spec: up=1 down=0 min %0d)", up_s, down_s, min_s, min, exp_min);
        end
        if (up_s === 1'b0 && down_s === 1'b0 && min === min_s && hour === hour_s) $display("E8 OBS SET_MIN_10 U+D = INVALID (up=0 down=0, no change)");
        else $display("E8 OBS SET_MIN_10 U+D = NOT invalid (up=%b down=%b %0d:%0d)", up_s, down_s, hour, min);
        // (c) SET_HOUR
        @(negedge clk) bL = 1; @(negedge clk) bL = 0;
        min_s = min; hour_s = hour;
        exp_hour = (hour_s == 5'd23) ? 5'd0 : hour_s + 5'd1;
        @(negedge clk) bU = 1; bD = 1;
        #1 up_s = up; down_s = down;
        @(negedge clk) bU = 0; bD = 0;
        if (up_s !== 1'b1 || down_s !== 1'b0 || hour !== exp_hour || min !== min_s) begin
            err = err + 1; $display("E8 FAIL SET_HOUR U+D: up=%b down=%b hour %0d->%0d (02 spec: up=1 down=0 hour %0d)", up_s, down_s, hour_s, hour, exp_hour);
        end
        if (up_s === 1'b0 && down_s === 1'b0 && min === min_s && hour === hour_s) $display("E8 OBS SET_HOUR U+D = INVALID (up=0 down=0, no change)");
        else $display("E8 OBS SET_HOUR U+D = NOT invalid (up=%b down=%b %0d:%0d)", up_s, down_s, hour, min);
        if (err == e0) $display("RESULT E8 PASS"); else $display("RESULT E8 FAIL");

        // =============================================================
        // E9 L 3번 · R 3번 순환 + L+R 같은 클럭 3번 (세 상태 모두)
        //    근거 02:24 L 왼쪽, R 오른쪽, 양 끝에서 돌아감 / 02:27 L 과 R 같은 클럭 -> L
        // =============================================================
        e0 = err;
        @(negedge clk) bL = 1; @(negedge clk) bL = 0;                 // SET_HOUR -> SET_MIN_1
        min_s = min; hour_s = hour;
        if (cursor !== 2'd0) begin err = err + 1; $display("E9 FAIL setup cursor %0d exp 0", cursor); end
        for (j = 0; j < 9; j = j + 1) begin
            @(negedge clk);
            if (j < 3) bL = 1;
            else if (j < 6) bR = 1;
            else begin bL = 1; bR = 1; end
            @(negedge clk) bL = 0; bR = 0;
            if (j < 3)      exp_cur = (j == 0) ? 2'd1 : ((j == 1) ? 2'd2 : 2'd0);
            else if (j < 6) exp_cur = (j == 3) ? 2'd2 : ((j == 4) ? 2'd1 : 2'd0);
            else            exp_cur = (j == 6) ? 2'd1 : ((j == 7) ? 2'd2 : 2'd0);
            exp_st = (exp_cur == 2'd0) ? 2'b11 : ((exp_cur == 2'd1) ? 2'b10 : 2'b01);
            if (cursor !== exp_cur || cu.c_state !== exp_st) begin
                err = err + 1; $display("E9 FAIL step %0d cursor %0d state %b exp %0d %b", j, cursor, cu.c_state, exp_cur, exp_st);
            end
        end
        if (min !== min_s || hour !== hour_s) begin err = err + 1; $display("E9 FAIL time changed %0d:%0d", hour, min); end
        if (err == e0) $display("RESULT E9 PASS"); else $display("RESULT E9 FAIL");

        // =============================================================
        // E10 sw2 내림 + 버튼 같은 클럭 (세 상태 x U/D, 세 상태 x L/R) + 재진입
        //    근거 02:27 sw2 를 내리는 클럭의 버튼 -> 무시 (NORMAL 로) / 02:22 재진입 분 일
        //    k : 0 SET_MIN_1+U, 1 SET_MIN_10+D, 2 SET_HOUR+U, 3 SET_MIN_1+L, 4 SET_MIN_10+R, 5 SET_HOUR+R
        // =============================================================
        e0 = err;
        for (k = 0; k < 6; k = k + 1) begin
            for (j = 0; j < (k % 3); j = j + 1) begin @(negedge clk) bL = 1; @(negedge clk) bL = 0; end
            min_s = min; hour_s = hour;
            @(negedge clk) sw2 = 0;
            if (k == 1) bD = 1;
            else if (k == 3) bL = 1;
            else if (k == 4 || k == 5) bR = 1;
            else bU = 1;
            #1 up_s = up; down_s = down;
            @(negedge clk) bU = 0; bD = 0; bL = 0; bR = 0;
            if (cu.c_state !== 2'b00 || cursor !== 2'd3 || up_s !== 1'b0 || down_s !== 1'b0 || min !== min_s || hour !== hour_s) begin
                err = err + 1; $display("E10 FAIL case %0d: state %b cursor %0d up %b down %b %0d:%0d (was %0d:%0d) exp 00 3 0 0 same", k, cu.c_state, cursor, up_s, down_s, hour, min, hour_s, min_s);
            end
            @(negedge clk) sw2 = 1;
            @(negedge clk);
            if (cu.c_state !== 2'b11 || cursor !== 2'd0) begin
                err = err + 1; $display("E10 FAIL case %0d re-entry state %b cursor %0d exp 11 0", k, cu.c_state, cursor);
            end
        end
        if (err == e0) $display("RESULT E10 PASS"); else $display("RESULT E10 FAIL");

        // =============================================================
        // E11 tick(자리 넘김) + 버튼 같은 클럭 · 같은 카운터 -> tick 만 (버튼은 버려지고 미뤄지지 않음)
        //    근거 02:28 tick 과 설정 버튼이 같은 클럭에 같은 카운터로 오면 tick 만 반영
        //    (a) 분 카운터 cursor 0 U  (b) 분 카운터 cursor 1 D  (c) 시 카운터 cursor 2 U
        //    w_tick_min 은 10 ms tick 2클럭 뒤, w_tick_hour 는 3클럭 뒤 (o_tick 레지스터 리플)
        // =============================================================
        e0 = err;
        // (a) SET_MIN_1 (재진입 직후), 설정 중에도 시계는 흐름
        min_s = min; hour_s = hour;
        for (i = 0; i < 5999; i = i + 1) begin @(negedge clk) tick = 1; @(negedge clk) tick = 0; end
        @(negedge clk);
        if (sec !== 6'd59 || msec !== 7'd99) begin err = err + 1; $display("E11 FAIL (a) setup sec.msec %0d.%0d exp 59.99", sec, msec); end
        @(negedge clk) tick = 1;
        @(negedge clk) tick = 0;
        @(negedge clk) bU = 1;
        #1;
        if (dp.w_tick_min !== 1'b1 || up !== 1'b1) begin err = err + 1; $display("E11 FAIL (a) align: w_tick_min %b up %b exp 1 1 (same clock)", dp.w_tick_min, up); end
        @(negedge clk) bU = 0;
        repeat (10) @(negedge clk);
        exp_min = (min_s == 6'd59) ? 6'd0 : min_s + 6'd1;
        if (min !== exp_min || hour !== hour_s || sec !== 6'd0 || msec !== 7'd0) begin
            err = err + 1; $display("E11 FAIL (a) min-counter tick+U: %0d:%0d:%0d.%0d exp %0d:%0d:0.0 (tick only)", hour, min, sec, msec, hour_s, exp_min);
        end
        $display("E11 INFO (a) min %0d -> %0d after tick+U same clock (button dropped if +1 only)", min_s, min);
        // (b) SET_MIN_10, D
        @(negedge clk) bL = 1; @(negedge clk) bL = 0;
        min_s = min; hour_s = hour;
        for (i = 0; i < 5999; i = i + 1) begin @(negedge clk) tick = 1; @(negedge clk) tick = 0; end
        @(negedge clk);
        @(negedge clk) tick = 1;
        @(negedge clk) tick = 0;
        @(negedge clk) bD = 1;
        #1;
        if (dp.w_tick_min !== 1'b1 || down !== 1'b1 || cursor !== 2'd1) begin err = err + 1; $display("E11 FAIL (b) align: w_tick_min %b down %b cursor %0d exp 1 1 1", dp.w_tick_min, down, cursor); end
        @(negedge clk) bD = 0;
        repeat (10) @(negedge clk);
        exp_min = (min_s == 6'd59) ? 6'd0 : min_s + 6'd1;
        if (min !== exp_min || hour !== hour_s || sec !== 6'd0) begin
            err = err + 1; $display("E11 FAIL (b) min-counter tick+D(-10): %0d:%0d:%0d exp %0d:%0d:0 (tick only)", hour, min, sec, hour_s, exp_min);
        end
        $display("E11 INFO (b) min %0d -> %0d after tick+D(-10) same clock", min_s, min);
        // (c) 시 카운터 : 분을 59 로 맞추고 SET_HOUR 에서 U
        @(negedge clk) bR = 1; @(negedge clk) bR = 0;                 // SET_MIN_10 -> SET_MIN_1
        for (i = 0; i < 60; i = i + 1) begin
            if (min !== 6'd59) begin @(negedge clk) bD = 1; @(negedge clk) bD = 0; end
        end
        @(negedge clk) bR = 1; @(negedge clk) bR = 0;                 // SET_MIN_1 -> SET_HOUR
        min_s = min; hour_s = hour;
        if (min !== 6'd59 || cursor !== 2'd2) begin err = err + 1; $display("E11 FAIL (c) setup min %0d cursor %0d exp 59 2", min, cursor); end
        for (i = 0; i < 5999; i = i + 1) begin @(negedge clk) tick = 1; @(negedge clk) tick = 0; end
        @(negedge clk);
        @(negedge clk) tick = 1;
        @(negedge clk) tick = 0;
        @(negedge clk);
        @(negedge clk) bU = 1;
        #1;
        if (dp.w_tick_hour !== 1'b1 || up !== 1'b1) begin err = err + 1; $display("E11 FAIL (c) align: w_tick_hour %b up %b exp 1 1", dp.w_tick_hour, up); end
        @(negedge clk) bU = 0;
        repeat (10) @(negedge clk);
        exp_hour = (hour_s == 5'd23) ? 5'd0 : hour_s + 5'd1;
        if (hour !== exp_hour || min !== 6'd0 || sec !== 6'd0) begin
            err = err + 1; $display("E11 FAIL (c) hour-counter tick+U: %0d:%0d:%0d exp %0d:0:0 (tick only)", hour, min, sec, exp_hour);
        end
        $display("E11 INFO (c) hour %0d -> %0d after tick+U same clock", hour_s, hour);
        if (err == e0) $display("RESULT E11 PASS"); else $display("RESULT E11 FAIL");

        // =============================================================
        // E12 다른 카운터 tick + 버튼 같은 클럭(둘 다 반영), 설정 버튼은 초 · 1/100초를 안 건드림,
        //     설정 중에도 100 tick 이면 초 +1
        //    근거 02:28 (같은 카운터일 때만 tick 우선) / 02:26 초 · 1/100초는 설정 안 함 / 02:21 항상 흐름
        // =============================================================
        e0 = err;
        @(negedge clk) bL = 1; @(negedge clk) bL = 0;                 // SET_HOUR -> SET_MIN_1
        min_s = min; msec_s = msec; sec_s = sec;
        @(negedge clk) tick = 1; bU = 1;
        @(negedge clk) tick = 0; bU = 0;
        repeat (3) @(negedge clk);
        exp_min = (min_s == 6'd59) ? 6'd0 : min_s + 6'd1;
        if (msec !== msec_s + 7'd1 || min !== exp_min) begin
            err = err + 1; $display("E12 FAIL 10ms tick + U: msec %0d->%0d min %0d->%0d exp msec+1 min+1", msec_s, msec, min_s, min);
        end
        msec_s = msec; sec_s = sec;
        for (j = 0; j < 3; j = j + 1) begin
            @(negedge clk) bU = 1; @(negedge clk) bU = 0;
            @(negedge clk) bD = 1; @(negedge clk) bD = 0;
            @(negedge clk) bL = 1; @(negedge clk) bL = 0;
        end
        if (sec !== sec_s || msec !== msec_s || cursor !== 2'd0) begin
            err = err + 1; $display("E12 FAIL U/D in 3 cursors changed sec.msec %0d.%0d -> %0d.%0d (cursor %0d)", sec_s, msec_s, sec, msec, cursor);
        end
        for (i = 0; i < 100; i = i + 1) begin @(negedge clk) tick = 1; @(negedge clk) tick = 0; end
        repeat (3) @(negedge clk);
        if (sec !== sec_s + 6'd1 || msec !== msec_s || cu.c_state !== 2'b11) begin
            err = err + 1; $display("E12 FAIL 100 ticks in SET: sec.msec %0d.%0d exp %0d.%0d", sec, msec, sec_s + 1, msec_s);
        end
        if (err == e0) $display("RESULT E12 PASS"); else $display("RESULT E12 FAIL");

        // =============================================================
        // E13 자리 이동(L/R) + U/D 같은 클럭 (모듈 단독)
        //    02 에 이 조합 규칙은 없음. 해석 : 02:23-25 "U/D 는 cursor 자리" -> 누른 순간의 자리(이동 전)에 한 번,
        //    자리는 L/R 대로 이동 (02:24). 한 칸만 한 번 바뀌고 올림 없음.
        //    (a) SET_MIN_1 L+U  (b) SET_MIN_10 R+U  (c) SET_HOUR R+D
        // =============================================================
        e0 = err;
        // (a)
        min_s = min; hour_s = hour;
        exp_min = (min_s + 1 >= 60) ? min_s + 1 - 60 : min_s + 1;
        @(negedge clk) bL = 1; bU = 1;
        @(negedge clk) bL = 0; bU = 0;
        if (cursor !== 2'd1 || min !== exp_min || hour !== hour_s) begin
            err = err + 1; $display("E13 FAIL (a) SET_MIN_1 L+U: cursor %0d %0d:%0d (was %0d:%0d) exp cursor 1 min %0d", cursor, hour, min, hour_s, min_s, exp_min);
        end
        $display("E13 OBS (a) SET_MIN_1 L+U -> cursor %0d, %0d:%0d -> %0d:%0d", cursor, hour_s, min_s, hour, min);
        // (b)
        min_s = min; hour_s = hour;
        exp_min = (min_s + 10 >= 60) ? min_s + 10 - 60 : min_s + 10;
        @(negedge clk) bR = 1; bU = 1;
        @(negedge clk) bR = 0; bU = 0;
        if (cursor !== 2'd0 || min !== exp_min || hour !== hour_s) begin
            err = err + 1; $display("E13 FAIL (b) SET_MIN_10 R+U: cursor %0d %0d:%0d (was %0d:%0d) exp cursor 0 min %0d", cursor, hour, min, hour_s, min_s, exp_min);
        end
        $display("E13 OBS (b) SET_MIN_10 R+U -> cursor %0d, %0d:%0d -> %0d:%0d", cursor, hour_s, min_s, hour, min);
        // (c)
        @(negedge clk) bR = 1; @(negedge clk) bR = 0;                 // SET_MIN_1 -> SET_HOUR
        min_s = min; hour_s = hour;
        exp_hour = (hour_s == 5'd0) ? 5'd23 : hour_s - 5'd1;
        @(negedge clk) bR = 1; bD = 1;
        @(negedge clk) bR = 0; bD = 0;
        if (cursor !== 2'd1 || hour !== exp_hour || min !== min_s) begin
            err = err + 1; $display("E13 FAIL (c) SET_HOUR R+D: cursor %0d %0d:%0d (was %0d:%0d) exp cursor 1 hour %0d", cursor, hour, min, hour_s, min_s, exp_hour);
        end
        $display("E13 OBS (c) SET_HOUR R+D -> cursor %0d, %0d:%0d -> %0d:%0d", cursor, hour_s, min_s, hour, min);
        if (err == e0) $display("RESULT E13 PASS"); else $display("RESULT E13 FAIL");

        // =============================================================
        // 공통 : up/down 이 같은 클럭에 둘 다 1 인 적이 있나 (INFO)
        // =============================================================
        $display("INFO up&down both 1 count = %0d, total up pulses %0d, down pulses %0d", n_both, n_up, n_down);

        // =============================================================
        // V1 커버리지 : 상태 4개 · 전이 (bit = {c_state, n_state})
        // =============================================================
        $display("COV transitions (bit index = {c_state, n_state}) = %b", cov);
        if (cov[0]  !== 1'b1) begin cov_miss = cov_miss + 1; $display("COV MISS NORMAL hold"); end
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

        $display("TOTAL MISMATCH = %0d", err);
        $finish;
    end
endmodule
