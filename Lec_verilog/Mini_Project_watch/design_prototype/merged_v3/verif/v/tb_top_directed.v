`timescale 1ns / 1ps

// 시제품 설계 자동 검사 TB (Icarus / xsim)
// 시뮬 시간을 줄이려고 100Hz tick_gen 두 개만 F_COUNT = 100 으로 줄임 (1 "초" = 10_000 클럭 = 100 us).
// 디바운서는 실제 값 그대로 (1 MHz 샘플 8칸).
module tb_top_directed ();
    reg clk, rst;
    reg btnR, btnL, btnU, btnD;
    reg sw_mode, sw_display_mode, sw_set, sw_24h, sw_timer;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;
    wire [15:0] led;

    integer err;
    time t_run, t_alarm;
    integer i;
    integer m0;

    parameter PUSH = 20_000;  // 버튼 누름/뗌 각각 20 us


    // (팀 통합판) 100 Hz tick 은 Top 에 하나, 버튼 · FND 는 4 kHz tick
    defparam dut.U_TICK_GEN_100HZ.F_COUNT = 100;          // 10 ms -> 1 us (1 "초" = 100 us)
    defparam dut.U_CLK_GEN_4KHz.CLK_FRQ = 10_000_000;     // 4 kHz -> 10 MHz (디바운서 8칸 = 0.8 us < PUSH)
    stopwatch_watch dut (
        .clk(clk),
        .rst(rst),
        .btnR(btnR),
        .btnL(btnL),
        .btnU(btnU),
        .btnD(btnD),
        .sw_mode(sw_mode),
        .sw_display_mode(sw_display_mode),
        .sw_set(sw_set),
        .sw_24h(sw_24h),
        .sw_timer(sw_timer),
        .fnd_com(fnd_com),
        .fnd_font(fnd_font),
        .led(led)
    );

    // 보기 쉽게 내부 신호 이름 붙이기
    wire [6:0] wt_msec = dut.w_wt_msec;
    wire [5:0] wt_sec = dut.w_wt_sec;
    wire [5:0] wt_min = dut.w_wt_min;
    wire [4:0] wt_hour = dut.w_wt_hour;
    wire [1:0] cursor = dut.w_cursor;
    wire set_mode = dut.w_set_mode;
    wire sw_run = dut.w_run_stop;

    always #5 clk = ~clk;

    // 시간 제한: 정상이면 약 7.5 ms 에 끝남. 20 ms 넘으면 bug 로 보고 멈춤 (wait 가 안 끝나는 경우 대비)
    initial begin
        #120_000_000;
        $display("TIMEOUT (120 ms) - TOTAL MISMATCH = %0d + timeout", err);
        $finish;
    end

    // (10/16) 초 · 1/100초는 설정 대상이 아님: 시뮬 내내 버튼 입력이 들어가면 FAIL
    always @(posedge clk) begin
        if (dut.U_WATCH_DATAPATH.U_SEC_COUNTER.i_up | dut.U_WATCH_DATAPATH.U_SEC_COUNTER.i_down |
            dut.U_WATCH_DATAPATH.U_MSEC_COUNTER.i_up | dut.U_WATCH_DATAPATH.U_MSEC_COUNTER.i_down) begin
            err = err + 1; $display("FAIL sec/msec got set pulse at %0t", $time);
        end
    end


    // ======== [상시 감시] LED · FND 핀 (원천 카운터 + 스위치로 기대값 계산, Top MUX · 12/24 · 랩 · 타이머 매핑 검증) ========
    integer mon_err_led, mon_err_fnd, mon_n;
    reg [7:0] seg [0:15];
    reg [6:0] x_ms; reg [5:0] x_s, x_m, x_h; reg x_disp, x_dot, x_blank, x_pm, x_alarm, x_blink, x_sel_wt, x_sel_sw, x_sel_tm;
    reg [3:0] g0, g1, g2, g3, x_code, x_com; reg [7:0] x_font; reg [15:0] x_led; reg [4:0] wt_h12;
    initial begin
        seg[0]=8'hC0; seg[1]=8'hF9; seg[2]=8'hA4; seg[3]=8'hB0; seg[4]=8'h99; seg[5]=8'h92; seg[6]=8'h82; seg[7]=8'hF8; seg[8]=8'h80; seg[9]=8'h90;
        seg[10]=8'hC0; seg[11]=8'hC0; seg[12]=8'hC0; seg[13]=8'hFF; seg[14]=8'h7F; seg[15]=8'hFF;
        mon_err_led = 0; mon_err_fnd = 0; mon_n = 0;
    end
    always @(negedge clk) begin #2.5; if (!rst) begin   // +2.5 ns: TB 자극(정수 ns 시각)과 절대 겹치지 않는 시각에 읽기
        mon_n = mon_n + 1;
        x_sel_tm = sw_timer; x_sel_sw = ~sw_timer & sw_mode; x_sel_wt = ~sw_timer & ~sw_mode;
        x_alarm = dut.w_tm_alarm; x_blink = (dut.w_wt_msec >= 50); x_pm = (dut.w_wt_hour >= 12);
        wt_h12 = sw_24h ? dut.w_wt_hour : (dut.w_wt_hour == 0) ? 5'd12 : (dut.w_wt_hour > 12) ? dut.w_wt_hour - 5'd12 : dut.w_wt_hour;
        // 원천: 스톱워치는 랩이면 저장값
        if (sw_timer) begin x_ms = dut.w_tm_msec; x_s = dut.w_tm_sec; x_m = dut.w_tm_sec; x_h = dut.w_tm_min; end
        else if (sw_mode) begin
            x_ms = dut.w_lap_active ? dut.U_STOPWATCH_DATAPATH.U_LAP_CONTROLLER.save_msec : dut.U_STOPWATCH_DATAPATH.w_msec;
            x_s  = dut.w_lap_active ? dut.U_STOPWATCH_DATAPATH.U_LAP_CONTROLLER.save_sec  : dut.U_STOPWATCH_DATAPATH.w_sec;
            x_m  = dut.w_lap_active ? dut.U_STOPWATCH_DATAPATH.U_LAP_CONTROLLER.save_min  : dut.U_STOPWATCH_DATAPATH.w_min;
            x_h  = dut.w_lap_active ? dut.U_STOPWATCH_DATAPATH.U_LAP_CONTROLLER.save_hour : dut.U_STOPWATCH_DATAPATH.w_hour;
        end else begin x_ms = dut.w_wt_msec; x_s = dut.w_wt_sec; x_m = dut.w_wt_min; x_h = wt_h12; end
        x_disp = sw_timer | sw_display_mode;
        x_dot = (x_ms >= 50);
        if (!x_disp) begin g0 = x_ms % 10; g1 = x_ms / 10; g2 = x_s % 10; g3 = x_s / 10; end
        else begin g0 = x_m % 10; g1 = x_m / 10; g2 = x_h % 10; g3 = x_h / 10; end
        x_blank = sw_set & x_disp & ~(sw_mode | sw_timer) & x_dot;
        if (x_blank) begin
            if (dut.w_cursor == 0) g0 = 4'hd; else if (dut.w_cursor == 1) g1 = 4'hd; else if (dut.w_cursor == 2) g2 = 4'hd;
        end
        case (dut.FND_CON.w_sel)
            0: x_code = g0; 1: x_code = g1; 2: x_code = g2; 3: x_code = g3;
            6: x_code = x_dot ? 4'hf : 4'he;
            default: x_code = 4'hf;
        endcase
        x_font = seg[x_code];
        case (dut.FND_CON.w_sel[1:0]) 0: x_com = 4'b1110; 1: x_com = 4'b1101; 2: x_com = 4'b1011; default: x_com = 4'b0111; endcase
        if (fnd_com !== x_com || fnd_font !== x_font) begin
            mon_err_fnd = mon_err_fnd + 1;
            if (mon_err_fnd <= 5) $display("MON FND FAIL at %0t: com %b font %h (exp %b %h) sel %0d", $time, fnd_com, fnd_font, x_com, x_font, dut.FND_CON.w_sel);
        end
        x_led[0] = x_alarm ? x_blink : x_sel_wt;  x_led[1] = x_alarm ? x_blink : x_sel_sw;
        x_led[2] = x_alarm ? x_blink : (~sw_timer & sw_display_mode); x_led[3] = x_alarm ? x_blink : (~sw_timer & ~sw_display_mode);
        x_led[4] = x_alarm ? x_blink : 1'b0; x_led[5] = x_alarm ? x_blink : x_sel_tm; x_led[6] = x_alarm ? x_blink : dut.w_tm_run;
        x_led[7] = x_alarm ? x_blink : (x_sel_sw & dut.w_lap_active);
        x_led[14:8] = (x_alarm & x_blink) ? 7'h7f : 7'h00;
        x_led[15] = x_alarm ? x_blink : (x_sel_wt & ~sw_24h & x_pm);
        if (led !== x_led) begin
            mon_err_led = mon_err_led + 1;
            if (mon_err_led <= 5) $display("MON LED FAIL at %0t: %h exp %h", $time, led, x_led);
        end
    end end

    initial begin
        clk = 0; rst = 1; err = 0;
        btnR = 0; btnL = 0; btnU = 0; btnD = 0;
        sw_mode = 0; sw_display_mode = 0; sw_set = 0; sw_24h = 0; sw_timer = 0;
        #100 rst = 0;
        #100;

        // T1 리셋 직후: 시계 12:00:00:00, LED = 시계 + 초.1/100초
        if ({wt_hour, wt_min, wt_sec} !== {5'd12, 6'd0, 6'd0}) begin err = err + 1; $display("T1 FAIL time %0d:%0d:%0d", wt_hour, wt_min, wt_sec); end
        // (10/16) 스위치 전부 0 = 12시간 표시 → 12시 = 오후 12시, led15(PM) 켜짐
        if (led !== 16'h8009) begin err = err + 1; $display("T1 FAIL led %b", led); end
        if (dut.w_hour !== 5'd12) begin err = err + 1; $display("T1 FAIL 12h display %0d", dut.w_hour); end
        if (cursor !== 2'd3 || set_mode !== 1'b0) begin err = err + 1; $display("T1 FAIL cursor %0d set %b", cursor, set_mode); end

        // T2 normal(sw_set = 0) 에서 U 는 무시
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        if (wt_hour !== 5'd12) begin err = err + 1; $display("T2 FAIL hour %0d", wt_hour); end

        // T3 (10/16 자리 단위) 설정 들어가면 분 일의 자리(cursor 0)부터, U 분 +1, D 분 -1
        sw_set = 1; #100;
        if (cursor !== 2'd0 || set_mode !== 1'b1) begin err = err + 1; $display("T3 FAIL cursor %0d set %b", cursor, set_mode); end
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        if (wt_min !== 6'd1 || wt_hour !== 5'd12) begin err = err + 1; $display("T3 FAIL U min %0d:%0d", wt_hour, wt_min); end
        btnD = 1; #PUSH; btnD = 0; #PUSH;
        btnD = 1; #PUSH; btnD = 0; #PUSH;
        if (wt_min !== 6'd59 || wt_hour !== 5'd12) begin err = err + 1; $display("T3 FAIL D wrap min %0d:%0d (expect 12:59, 시 그대로)", wt_hour, wt_min); end

        // T4 커서 이동: L 분일->분십->시->분일(돌아감), R 분일->시(돌아감)->분십->분일
        btnL = 1; #PUSH; btnL = 0; #PUSH;
        if (cursor !== 2'd1) begin err = err + 1; $display("T4 FAIL L1 cursor %0d", cursor); end
        btnL = 1; #PUSH; btnL = 0; #PUSH;
        if (cursor !== 2'd2) begin err = err + 1; $display("T4 FAIL L2 cursor %0d", cursor); end
        btnL = 1; #PUSH; btnL = 0; #PUSH;
        if (cursor !== 2'd0) begin err = err + 1; $display("T4 FAIL L3 wrap cursor %0d", cursor); end
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        if (cursor !== 2'd2) begin err = err + 1; $display("T4 FAIL R1 wrap cursor %0d", cursor); end
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        if (cursor !== 2'd1) begin err = err + 1; $display("T4 FAIL R2 cursor %0d", cursor); end

        // T5 분 십의 자리: 59 -> U(+10) -> 09 (60 으로 돌기, 시 그대로) -> D(-10) -> 59 -> D -> 49
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        if (wt_min !== 6'd9 || wt_hour !== 5'd12) begin err = err + 1; $display("T5 FAIL +10 wrap %0d:%0d", wt_hour, wt_min); end
        btnD = 1; #PUSH; btnD = 0; #PUSH;
        if (wt_min !== 6'd59) begin err = err + 1; $display("T5 FAIL -10 wrap %0d", wt_min); end
        btnD = 1; #PUSH; btnD = 0; #PUSH;
        if (wt_min !== 6'd49) begin err = err + 1; $display("T5 FAIL -10 %0d", wt_min); end
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        btnU = 1; #PUSH; btnU = 0; #PUSH;    // 49 -> 59 -> 09
        if (wt_min !== 6'd9) begin err = err + 1; $display("T5 FAIL +10 x2 %0d", wt_min); end
        //    시 자리: 12 -> D 0 까지 내리고 한 번 더 -> 23 (분 그대로)
        btnL = 1; #PUSH; btnL = 0; #PUSH;    // 분십 -> 시
        if (cursor !== 2'd2) begin err = err + 1; $display("T5 FAIL hour cursor %0d", cursor); end
        for (i = 0; i < 13; i = i + 1) begin
            btnD = 1; #PUSH; btnD = 0; #PUSH;   // 12 -> 0 -> 23
        end
        if (wt_hour !== 5'd23 || wt_min !== 6'd9) begin err = err + 1; $display("T5 FAIL hour 0->23 %0d:%0d", wt_hour, wt_min); end
        btnU = 1; #PUSH; btnU = 0; #PUSH;    // 23 -> 0
        if (wt_hour !== 5'd0) begin err = err + 1; $display("T5 FAIL hour 23->0 %0d", wt_hour); end
        //    초는 설정 안 됨: 어떤 커서에서도 sec 는 버튼으로 안 바뀜 (흐름만)
        //    U, D 동시 -> U 우선 (+1)
        btnU = 1; btnD = 1; #PUSH; btnU = 0; btnD = 0; #PUSH;
        if (wt_hour !== 5'd1) begin err = err + 1; $display("T5 FAIL U+D same time -> %0d (expect 1, U 우선)", wt_hour); end

        // T6 sw_set = 0 -> NORMAL, 버튼 무시, 다시 들어가면 분 일의 자리부터
        sw_set = 0; #100;
        if (cursor !== 2'd3 || set_mode !== 1'b0) begin err = err + 1; $display("T6 FAIL cursor %0d set %b", cursor, set_mode); end
        btnD = 1; #PUSH; btnD = 0; #PUSH;
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        if (wt_hour !== 5'd1 || wt_min !== 6'd9 || cursor !== 2'd3) begin err = err + 1; $display("T6 FAIL %0d:%0d cursor %0d", wt_hour, wt_min, cursor); end
        sw_set = 1; #100;
        if (cursor !== 2'd0) begin err = err + 1; $display("T6 FAIL re-enter cursor %0d", cursor); end

        // T7 게이팅: 시계 모드에서 R 은 스톱워치를 안 돌림
        btnR = 1; #PUSH; btnR = 0; #PUSH;    // 분일 -> 시 (돌아감)
        if (sw_run !== 1'b0) begin err = err + 1; $display("T7 FAIL stopwatch ran in watch mode"); end
        if (cursor !== 2'd2) begin err = err + 1; $display("T7 FAIL watch R cursor %0d", cursor); end
        btnR = 1; #PUSH; btnR = 0; #PUSH;    // 시 -> 분십
        //    스톱워치 모드: R 은 스톱워치 RUN, 시계 커서는 안 움직임, LED 바뀜
        sw_mode = 1; sw_display_mode = 1; #100;
        if (led !== 16'h0006) begin err = err + 1; $display("T7 FAIL led %b", led); end
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        if (sw_run !== 1'b1) begin err = err + 1; $display("T7 FAIL stopwatch not running"); end
        if (cursor !== 2'd1) begin err = err + 1; $display("T7 FAIL watch cursor moved %0d", cursor); end
        btnU = 1; #PUSH; btnU = 0; #PUSH;    // 스톱워치 RUN 중 U 는 무시, 시계 분도 안 바뀜
        if (wt_min !== 6'd9) begin err = err + 1; $display("T7 FAIL watch min changed %0d", wt_min); end
        //    (팀 통합판) FND 점멸 검사는 이 TB 에서 뺌 — 정안성 FND 모듈 몫
        btnR = 1; #PUSH; btnR = 0; #PUSH;    // 스톱워치 STOP
        sw_mode = 0; #100;

        // T8 (팀 통합판) 점멸 검사는 뺌 — 정안성 FND 모듈 몫

        // T9 23:59 로 맞추고 자정 넘어감 확인: 23:59:59.99 -> 00:00:00.00
        btnL = 1; #PUSH; btnL = 0; #PUSH;    // 분십 -> 시
        for (i = 0; i < 22; i = i + 1) begin
            btnU = 1; #PUSH; btnU = 0; #PUSH;   // 1 -> 23
        end
        btnR = 1; #PUSH; btnR = 0; #PUSH;    // 분 십
        for (i = 0; i < 5; i = i + 1) begin
            btnU = 1; #PUSH; btnU = 0; #PUSH;   // 09 -> 59
        end
        if (wt_hour !== 5'd23 || wt_min !== 6'd59) begin err = err + 1; $display("T9 FAIL set %0d:%0d", wt_hour, wt_min); end
        sw_set = 0;
        wait (wt_hour == 5'd0);
        if ({wt_min, wt_sec, wt_msec} !== {6'd0, 6'd0, 7'd0}) begin err = err + 1; $display("T9 FAIL midnight %0d:%0d:%0d.%0d", wt_hour, wt_min, wt_sec, wt_msec); end
        else $display("T9 midnight 00:00:00.00 at %0t ps (1 \"초\" = 100 us 로 줄인 시뮬)", $time);

        // T10 12/24 시간 표시 (sw3 = 0 이 12시간): 내부는 24시간 그대로, 화면 값(w_hour)과 PM LED 만 바뀜
        //     지금 시계 00시 -> 24h 화면 0, 12h 화면 12(오전)
        sw_24h = 1;   // (10/16) sw3 = 1 이 24시간
        #100;   // wait 직후 같은 시각에는 조합회로(w_hour)가 아직 안 바뀌어 있으므로 잠깐 기다림
        if (dut.w_hour !== 5'd0) begin err = err + 1; $display("T10 FAIL 24h 0 -> %0d", dut.w_hour); end
        sw_24h = 0; #100;
        if (dut.w_hour !== 5'd12 || led[15] !== 1'b0) begin err = err + 1; $display("T10 FAIL 12h 0 -> %0d pm %b", dut.w_hour, led[15]); end
        //     시 칸을 U 로 12시(정오) -> 화면 12, PM
        sw_set = 1; #100;
        btnR = 1; #PUSH; btnR = 0; #PUSH;    // 분 일(시작) -> 시 (오른쪽 끝에서 돌아감)
        for (i = 0; i < 12; i = i + 1) begin
            btnU = 1; #PUSH; btnU = 0; #PUSH;
        end
        if (wt_hour !== 5'd12 || dut.w_hour !== 5'd12 || led[15] !== 1'b1) begin err = err + 1; $display("T10 FAIL 12h 12 -> %0d pm %b", dut.w_hour, led[15]); end
        //     13시 -> 화면 1, PM / 23시 -> 화면 11, PM
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        if (wt_hour !== 5'd13 || dut.w_hour !== 5'd1 || led[15] !== 1'b1) begin err = err + 1; $display("T10 FAIL 12h 13 -> %0d pm %b", dut.w_hour, led[15]); end
        for (i = 0; i < 10; i = i + 1) begin
            btnU = 1; #PUSH; btnU = 0; #PUSH;
        end
        if (wt_hour !== 5'd23 || dut.w_hour !== 5'd11 || led[15] !== 1'b1) begin err = err + 1; $display("T10 FAIL 12h 23 -> %0d pm %b", dut.w_hour, led[15]); end
        //     11시 -> 화면 11, 오전
        for (i = 0; i < 12; i = i + 1) begin
            btnD = 1; #PUSH; btnD = 0; #PUSH;
        end
        if (wt_hour !== 5'd11 || dut.w_hour !== 5'd11 || led[15] !== 1'b0) begin err = err + 1; $display("T10 FAIL 12h 11 -> %0d pm %b", dut.w_hour, led[15]); end
        //     24h 로 되돌리면 23시 그대로 23
        btnU = 1; #PUSH; btnU = 0; #PUSH;    // 12
        btnU = 1; #PUSH; btnU = 0; #PUSH;    // 13
        sw_24h = 1; #100;
        if (dut.w_hour !== 5'd13 || led[15] !== 1'b0) begin err = err + 1; $display("T10 FAIL 24h 13 -> %0d pm %b", dut.w_hour, led[15]); end
        //     스톱워치 화면은 12h 영향 없음, PM LED 꺼짐
        sw_24h = 0; sw_mode = 1; #100;
        if (dut.w_hour !== dut.w_sw_hour || led[15] !== 1'b0) begin err = err + 1; $display("T10 FAIL stopwatch hour %0d pm %b", dut.w_hour, led[15]); end
        sw_mode = 0; sw_set = 0;

        // T11 타이머 (10/16 판): U +10초 · R +1분 · D +10분, 최대 59:59, 화면은 분.초 고정
        sw_24h = 1; sw_display_mode = 0; sw_timer = 1; #100;
        if (led !== 16'h0020) begin err = err + 1; $display("T11 FAIL led %h", led); end
        if (dut.w_disp_mode !== 1'b1 || dut.w_hour !== 6'd0 || dut.w_min !== 6'd0) begin err = err + 1; $display("T11 FAIL display not timer"); end
        //     0 에서 L → 시작 안 함
        btnL = 1; #PUSH; btnL = 0; #PUSH;
        if (dut.w_tm_run !== 1'b0) begin err = err + 1; $display("T11 FAIL started at zero"); end
        //     U +10초 → 00:10, 화면 왼쪽 2칸 = 분, 오른쪽 2칸 = 초
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        if (dut.w_tm_min !== 6'd0 || dut.w_tm_sec !== 6'd10) begin err = err + 1; $display("T11 FAIL +10s %0d:%0d", dut.w_tm_min, dut.w_tm_sec); end
        if (dut.w_hour !== 6'd0 || dut.w_min !== 6'd10) begin err = err + 1; $display("T11 FAIL display %0d.%0d", dut.w_hour, dut.w_min); end
        //     U 5번 더 → 00:60 → 01:00 (초 넘김)
        for (i = 0; i < 5; i = i + 1) begin
            btnU = 1; #PUSH; btnU = 0; #PUSH;
        end
        if (dut.w_tm_min !== 6'd1 || dut.w_tm_sec !== 6'd0) begin err = err + 1; $display("T11 FAIL sec carry %0d:%0d", dut.w_tm_min, dut.w_tm_sec); end
        //     R +1분 → 02:00, D +10분 → 12:00
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        if (dut.w_tm_min !== 6'd2) begin err = err + 1; $display("T11 FAIL +1m %0d", dut.w_tm_min); end
        btnD = 1; #PUSH; btnD = 0; #PUSH;
        if (dut.w_tm_min !== 6'd12 || dut.w_tm_sec !== 6'd0) begin err = err + 1; $display("T11 FAIL +10m %0d:%0d", dut.w_tm_min, dut.w_tm_sec); end
        //     U 한 번(12:10) 뒤 D 4번 → 52:10, D 한 번 더 → 62:10 은 넘으므로 59:59
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        for (i = 0; i < 4; i = i + 1) begin
            btnD = 1; #PUSH; btnD = 0; #PUSH;
        end
        if (dut.w_tm_min !== 6'd52 || dut.w_tm_sec !== 6'd10) begin err = err + 1; $display("T11 FAIL 52:10 %0d:%0d", dut.w_tm_min, dut.w_tm_sec); end
        btnD = 1; #PUSH; btnD = 0; #PUSH;
        if ({dut.w_tm_hour, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec} !== {5'd0, 6'd59, 6'd59, 7'd0}) begin err = err + 1; $display("T11 FAIL cap %0d:%0d:%0d", dut.w_tm_hour, dut.w_tm_min, dut.w_tm_sec); end
        //     59:59 에서 U(+10초) → 넘으므로 59:59 그대로
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        if (dut.w_tm_min !== 6'd59 || dut.w_tm_sec !== 6'd59) begin err = err + 1; $display("T11 FAIL cap U %0d:%0d", dut.w_tm_min, dut.w_tm_sec); end
        //     시작 → 조금 뒤 59:58.xx → 취소 → 0
        btnL = 1; #PUSH; btnL = 0; #PUSH; #PUSH;
        if (dut.w_tm_run !== 1'b1 || dut.w_tm_min !== 6'd59 || dut.w_tm_sec !== 6'd58) begin err = err + 1; $display("T11 FAIL run %b %0d:%0d", dut.w_tm_run, dut.w_tm_min, dut.w_tm_sec); end
        if (led[6] !== 1'b1) begin err = err + 1; $display("T11 FAIL led6 run"); end
        btnL = 1; #PUSH; btnL = 0; #PUSH;
        if (dut.w_tm_run !== 1'b0 || dut.w_tm_zero !== 1'b1) begin err = err + 1; $display("T11 FAIL cancel"); end
        //     R(+1분) → 시작 → 시계 화면으로 가도 계속 줄어듦 → 정확히 60 "초" 뒤 알람
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        btnL = 1;
        @(posedge dut.w_tm_run); t_run = $time;
        #PUSH; btnL = 0; #PUSH;
        sw_timer = 0; #100;
        btnU = 1; #PUSH; btnU = 0; #PUSH;   // 시계 normal 이라 무시, 타이머에도 안 감
        if (dut.w_tm_run !== 1'b1) begin err = err + 1; $display("T11 FAIL timer stopped in watch view"); end
        @(posedge dut.w_tm_alarm); t_alarm = $time;
        // (팀 통합판) 100 Hz tick 공유 → 첫 tick 이 최대 1 tick(축소 1 us = 실제 10 ms) 빠를 수 있음
        if ((t_alarm - t_run) < 64'd5_999_000 || (t_alarm - t_run) > 64'd6_000_100) begin err = err + 1; $display("T11 FAIL 1 min = %0d ns (expect 6,000,000 + a few clk)", t_alarm - t_run); end
        else $display("T11 timer 1 min (scaled) = %0d ns", t_alarm - t_run);
        //     알람: 시계 화면에 있어도 16개 LED 가 0.5 "초" 마다 같이 점멸
        for (i = 0; i < 300; i = i + 1) begin
            #337;
            if (led !== ((dut.w_blink) ? 16'hffff : 16'h0000)) begin err = err + 1; $display("T11 FAIL alarm led %h", led); end
        end
        //     시계 화면 버튼으로는 안 꺼짐
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        if (dut.w_tm_alarm !== 1'b1) begin err = err + 1; $display("T11 FAIL alarm off by watch button"); end
        //     타이머 화면에서 아무 버튼(D) → 끄기, 시간은 그대로 0 (D 로 10분이 더해지지 않음)
        sw_timer = 1; #100;
        btnD = 1; #PUSH; btnD = 0; #PUSH;
        if (dut.w_tm_alarm !== 1'b0 || dut.w_tm_zero !== 1'b1 || led !== 16'h0020) begin err = err + 1; $display("T11 FAIL alarm off %b %b %h", dut.w_tm_alarm, dut.w_tm_zero, led); end
        sw_timer = 0;


        // ================= T12 각 모드 동작 중 비동기 리셋 =================
        sw_timer = 0; sw_mode = 1; sw_set = 0; #100;
        btnR = 1; #PUSH; btnR = 0; #PUSH;      // 스톱워치 RUN
        btnD = 1; #PUSH; btnD = 0; #PUSH;      // 랩
        sw_mode = 0; sw_set = 1; #100;         // 시계 설정 (분 일)
        m0 = wt_min;
        btnU = 1; #PUSH; btnU = 0; #PUSH;      // 분 +1
        if (wt_min !== ((m0 + 1) % 60)) begin err = err + 1; $display("T12 FAIL watch +1 setup %0d -> %0d", m0, wt_min); end
        sw_timer = 1; #100;
        btnR = 1; #PUSH; btnR = 0; #PUSH;      // 타이머 +1분
        btnL = 1; #PUSH; btnL = 0; #PUSH;      // 타이머 RUN
        if (dut.w_run_stop !== 1 || dut.w_lap_active !== 1 || dut.w_tm_run !== 1) begin err = err + 1; $display("T12 FAIL setup run %b lap %b tm_run %b", dut.w_run_stop, dut.w_lap_active, dut.w_tm_run); end
        #333; rst = 1; #37;
        if (dut.FND_CON.w_sel !== 0) begin err = err + 1; $display("T12 FAIL fnd scan counter not reset"); end
        rst = 0; #100;     // 클럭과 무관한 시각에 리셋
        if (dut.w_run_stop !== 0 || dut.w_lap_active !== 0 || dut.w_mode !== 0 || dut.U_STOPWATCH_DATAPATH.w_msec !== 0) begin err = err + 1; $display("T12 FAIL stopwatch after reset"); end
        if ({wt_hour, wt_min, wt_sec, wt_msec} !== {5'd12, 6'd0, 6'd0, 7'd0}) begin err = err + 1; $display("T12 FAIL watch after reset %0d:%0d:%0d", wt_hour, wt_min, wt_sec); end
        if (dut.w_tm_run !== 0 || dut.w_tm_alarm !== 0 || dut.w_tm_zero !== 1) begin err = err + 1; $display("T12 FAIL timer after reset"); end
        // 리셋 중 버튼 눌림 -> 해제 후 무시되는지 (스위치는 그대로: 타이머 화면)
        btnR = 1; rst = 1; #PUSH; rst = 0; #PUSH; btnR = 0; #PUSH;
        $display("T12 info: button held across reset -> timer min %0d (debouncer refills after reset: 1 press event expected)", dut.w_tm_min);
        if (dut.w_tm_min > 1) begin err = err + 1; $display("T12 FAIL more than one press from one hold across reset"); end
        rst = 1; #100; rst = 0; #100;

        // ================= T13 동시 버튼 =================
        // 시계 설정에서 L+R 같은 때 -> L 우선 (분 일 -> 분 십)
        sw_timer = 0; sw_mode = 0; sw_set = 1; #100;
        if (cursor !== 0) begin err = err + 1; $display("T13 FAIL start cursor %0d", cursor); end
        btnL = 1; btnR = 1; #PUSH; btnL = 0; btnR = 0; #PUSH;
        if (cursor !== 1) begin err = err + 1; $display("T13 FAIL L+R -> cursor %0d (exp 1, L first)", cursor); end
        // U+D 같은 때 -> U 우선 (분 십 +10)
        btnU = 1; btnD = 1; #PUSH; btnU = 0; btnD = 0; #PUSH;
        if (wt_min !== 6'd10) begin err = err + 1; $display("T13 FAIL U+D -> min %0d (exp 10)", wt_min); end
        // 네 개 동시: L 로 이동 + U 는 '누른 클럭의 자리(분 십)' 에 +10 -> 분 20, cursor 2
        btnL = 1; btnR = 1; btnU = 1; btnD = 1; #PUSH; btnL = 0; btnR = 0; btnU = 0; btnD = 0; #PUSH;
        if (cursor !== 2 || wt_min !== 6'd20) begin err = err + 1; $display("T13 FAIL 4 buttons -> cursor %0d min %0d (exp 2, 20)", cursor, wt_min); end
        sw_set = 0; #100;
        // 타이머 SET: U+R+D 동시 -> U 만 (+10초)
        sw_timer = 1; #100;
        btnU = 1; btnR = 1; btnD = 1; #PUSH; btnU = 0; btnR = 0; btnD = 0; #PUSH;
        if (dut.w_tm_min !== 0 || dut.w_tm_sec !== 10) begin err = err + 1; $display("T13 FAIL timer U+R+D -> %0d:%0d (exp 00:10)", dut.w_tm_min, dut.w_tm_sec); end
        // 타이머 SET: L+U 동시 (0 아님) -> L 시작, U 무시
        btnL = 1; btnU = 1; #PUSH; btnL = 0; btnU = 0; #PUSH;
        if (dut.w_tm_run !== 1 || dut.w_tm_sec > 10) begin err = err + 1; $display("T13 FAIL timer L+U -> run %b sec %0d", dut.w_tm_run, dut.w_tm_sec); end
        btnL = 1; #PUSH; btnL = 0; #PUSH;       // 취소
        sw_timer = 0;
        // 스톱워치 STOP: R+L 동시 -> 팀 CU: RUN + clear (수업 FSM 은 R 만). 기록만
        sw_mode = 1; #100;
        btnR = 1; btnL = 1; #PUSH; btnR = 0; btnL = 0; #PUSH;
        $display("T13 info: stopwatch R+L same clock -> run %b (team CU also clears: DEVIATION from class FSM, see unit TB)", dut.w_run_stop);
        btnR = 1; #PUSH; btnR = 0; #PUSH; btnL = 1; #PUSH; btnL = 0; #PUSH; sw_mode = 0; #100;

        // ================= T14 버튼 펄스가 나오는 바로 그 클럭에 화면 스위치 전환 (게이팅 경쟁) =================
        // 디바운서 시프트가 7칸 찼을 때 sw_mode 를 바꾼다 -> 펄스는 바뀐 쪽 하나에만 들어가야 (둘 다 X, 아무도 X)
        sw_mode = 0; sw_set = 1; #100;
        m0 = wt_min; i = 0;
        btnR = 1;
        wait (dut.U_BD_R.q_reg == 8'hfe);     // MSB 부터 채워짐: 7칸 = 1111_1110
        @(negedge clk); sw_mode = 1;             // 다음 샘플에서 8칸 완성 -> 펄스는 스톱워치 쪽
        #PUSH; btnR = 0; #PUSH;
        i = (dut.w_run_stop == 1) + (cursor != 0);
        if (i !== 1) begin err = err + 1; $display("T14 FAIL race: run %b cursor %0d (exactly one target expected)", dut.w_run_stop, cursor); end
        else $display("T14 ok: pulse went to %s only", dut.w_run_stop ? "stopwatch" : "watch");
        if (dut.w_run_stop) begin btnR = 1; #PUSH; btnR = 0; #PUSH; end
        sw_mode = 0; sw_set = 0; #100;

        // ================= T15 타이머 경계 (Top 에서) =================
        sw_timer = 1; sw_display_mode = 0; #100;
        if (dut.w_tm_zero !== 1) begin btnL = 1; #PUSH; btnL = 0; #PUSH; btnL = 1; #PUSH; btnL = 0; #PUSH; end
        for (i = 0; i < 5; i = i + 1) begin btnD = 1; #PUSH; btnD = 0; #PUSH; end   // 50:00
        for (i = 0; i < 9; i = i + 1) begin btnR = 1; #PUSH; btnR = 0; #PUSH; end   // 59:00
        for (i = 0; i < 5; i = i + 1) begin btnU = 1; #PUSH; btnU = 0; #PUSH; end   // 59:50
        if (dut.w_tm_min !== 59 || dut.w_tm_sec !== 50) begin err = err + 1; $display("T15 FAIL build 59:50 -> %0d:%0d", dut.w_tm_min, dut.w_tm_sec); end
        btnU = 1; #PUSH; btnU = 0; #PUSH;                                            // 60:00 -> 59:59
        if (dut.w_tm_min !== 59 || dut.w_tm_sec !== 59) begin err = err + 1; $display("T15 FAIL 59:50+10s -> %0d:%0d", dut.w_tm_min, dut.w_tm_sec); end
        // 화면: 왼쪽 2칸 59, 오른쪽 2칸 59 (상시 감시가 핀을 확인) · LD2/LD3 꺼짐
        if (led[3:2] !== 2'b00) begin err = err + 1; $display("T15 FAIL LD2/LD3 in timer view"); end
        btnL = 1; #PUSH; btnL = 0; #PUSH; btnL = 1; #PUSH; btnL = 0; #PUSH;           // 시작, 취소 -> 0
        if (dut.w_tm_zero !== 1) begin err = err + 1; $display("T15 FAIL cancel"); end
        // 00:10 설정 -> 시작 -> 10 "초" 뒤 알람 (10 x 100 us)
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        btnL = 1; @(posedge dut.w_tm_run); t_run = $time; #PUSH; btnL = 0;
        @(posedge dut.w_tm_alarm); t_alarm = $time;
        if ((t_alarm - t_run) < 64'd999_000 || (t_alarm - t_run) > 64'd1_000_100) begin err = err + 1; $display("T15 FAIL 10 s = %0d ns", t_alarm - t_run); end
        else $display("T15 timer 10 s (scaled) = %0d ns", t_alarm - t_run);
        // 알람 끄기: 타이머 화면 R -> SET, 1분 더해지지 않음
        btnR = 1; #PUSH; btnR = 0; #PUSH;
        if (dut.w_tm_alarm !== 0 || dut.w_tm_zero !== 1) begin err = err + 1; $display("T15 FAIL alarm off by R added time"); end
        sw_timer = 0; #100;

        // ================= T17 스톱워치: 시작 위상 오차 · 랩 · RUN 중 L/U (팀 CU) · 다운 돌기 =================
        sw_mode = 1; #100;
        // 시작 위상: 공용 tick 이라 R 뒤 첫 증가까지 0~1 tick (축소 1 us). 5번 재서 최대값 기록
        m0 = 0;
        for (i = 0; i < 5; i = i + 1) begin
            #(1_000 + i * 170);
            btnR = 1; @(posedge dut.w_btnR); t_run = $time;
            @(dut.U_STOPWATCH_DATAPATH.w_msec); t_alarm = $time;   // 첫 증가까지 (버튼 떼기 전에 측정)
            #PUSH; btnR = 0;
            if ((t_alarm - t_run) > m0) m0 = t_alarm - t_run;
            #PUSH; btnR = 1; #PUSH; btnR = 0; #PUSH;   // 정지
            btnL = 1; #PUSH; btnL = 0; #PUSH;          // 지우기
        end
        $display("T17 info: start -> first count latency max %0d ns over 5 starts (shared tick: up to 1 tick = 1 us scaled = 10 ms real)", m0);
        if (m0 > 1_100) begin err = err + 1; $display("T17 FAIL latency > 1 tick"); end
        // 랩: RUN -> D(랩) -> 화면 고정, 내부 진행 -> D -> 복귀 -> R 정지 -> L 지움 (랩 포함)
        btnR = 1; #PUSH; btnR = 0; #PUSH; #300_000;
        btnD = 1; #PUSH; btnD = 0; #PUSH; m0 = dut.w_sw_msec + 100 * dut.w_sw_sec;
        #300_000;
        if (dut.w_lap_active !== 1 || (dut.w_sw_msec + 100 * dut.w_sw_sec) !== m0) begin err = err + 1; $display("T17 FAIL lap display moved"); end
        if ((dut.U_STOPWATCH_DATAPATH.w_msec + 100 * dut.U_STOPWATCH_DATAPATH.w_sec) == m0) begin err = err + 1; $display("T17 FAIL internal stopped during lap"); end
        btnD = 1; #PUSH; btnD = 0; #PUSH;
        if (dut.w_lap_active !== 0) begin err = err + 1; $display("T17 FAIL unlap"); end
        // (10/16) RUN 중 L: 무시 -> 계속 달리고 0 으로 안 감
        m0 = dut.U_STOPWATCH_DATAPATH.w_msec + 100 * dut.U_STOPWATCH_DATAPATH.w_sec;
        btnL = 1; #PUSH; btnL = 0; #PUSH;
        if (dut.w_run_stop !== 1 || (dut.U_STOPWATCH_DATAPATH.w_msec + 100 * dut.U_STOPWATCH_DATAPATH.w_sec) < m0) begin err = err + 1; $display("T17 FAIL L during RUN cleared (msec %0d run %b)", dut.U_STOPWATCH_DATAPATH.w_msec, dut.w_run_stop); end
        // (10/16) RUN 중 U: 무시 -> mode 그대로 0
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        if (dut.w_mode !== 0) begin err = err + 1; $display("T17 FAIL U during RUN toggled mode"); end
        btnR = 1; #PUSH; btnR = 0; #PUSH;    // STOP
        if (dut.w_mode) begin btnU = 1; #PUSH; btnU = 0; #PUSH; end
        btnL = 1; #PUSH; btnL = 0; #PUSH;
        // 다운 돌기: mode=1, RUN, 1 tick -> 23:59:59.99
        btnU = 1; #PUSH; btnU = 0; #PUSH;
        btnR = 1; #PUSH; btnR = 0; @(posedge dut.U_STOPWATCH_DATAPATH.w_tick_10ms); #50; btnR = 1; #PUSH; btnR = 0; #PUSH;
        if ({dut.U_STOPWATCH_DATAPATH.w_hour, dut.U_STOPWATCH_DATAPATH.w_min, dut.U_STOPWATCH_DATAPATH.w_sec} !== {5'd23, 6'd59, 6'd59}) begin err = err + 1; $display("T17 FAIL down wrap %0d:%0d:%0d.%0d", dut.U_STOPWATCH_DATAPATH.w_hour, dut.U_STOPWATCH_DATAPATH.w_min, dut.U_STOPWATCH_DATAPATH.w_sec, dut.U_STOPWATCH_DATAPATH.w_msec); end
        btnU = 1; #PUSH; btnU = 0; #PUSH; btnL = 1; #PUSH; btnL = 0; #PUSH; sw_mode = 0; #100;

        // ================= T18 오후 LED: 시 0~23 전부 (12시간 표시), 24시간 표시 · 다른 화면에서는 꺼짐 =================
        sw_set = 1; sw_24h = 0; sw_display_mode = 1; #100;
        btnL = 1; #PUSH; btnL = 0; #PUSH; btnL = 1; #PUSH; btnL = 0; #PUSH;   // 시 자리
        for (i = 0; i < 24; i = i + 1) begin
            if (led[15] !== (wt_hour >= 12)) begin err = err + 1; $display("T18 FAIL pm led at hour %0d", wt_hour); end
            if (dut.w_hour !== ((wt_hour == 0) ? 5'd12 : (wt_hour > 12) ? wt_hour - 5'd12 : wt_hour)) begin err = err + 1; $display("T18 FAIL 12h display at %0d -> %0d", wt_hour, dut.w_hour); end
            btnU = 1; #PUSH; btnU = 0; #PUSH;
        end
        sw_24h = 1; #100; if (led[15] !== 0) begin err = err + 1; $display("T18 FAIL pm led in 24h"); end
        sw_24h = 0; sw_mode = 1; #100; if (led[15] !== 0) begin err = err + 1; $display("T18 FAIL pm led in stopwatch view"); end
        sw_mode = 0; sw_timer = 1; #100; if (led[15] !== 0) begin err = err + 1; $display("T18 FAIL pm led in timer view"); end
        sw_timer = 0; sw_set = 0; #100;

        // ================= T19 Top 디바운스: 짧은 누름 무시 · 튐 누름 1회 =================
        sw_set = 1; #100; m0 = cursor;
        btnL = 1; #300; btnL = 0; #PUSH;                       // 3 샘플 -> 무시
        if (cursor !== m0) begin err = err + 1; $display("T19 FAIL 300 ns press moved cursor"); end
        for (i = 0; i < 10; i = i + 1) begin btnL = ~btnL; #(60 + i * 20); end   // 튐 (조각 < 800 ns)
        btnL = 1; #5_000; btnL = 0;
        for (i = 0; i < 10; i = i + 1) begin btnL = ~btnL; #(60 + i * 20); end
        btnL = 0; #PUSH;
        if (cursor !== ((m0 + 1) % 3)) begin err = err + 1; $display("T19 FAIL bouncy press -> cursor %0d (exp %0d)", cursor, (m0 + 1) % 3); end
        sw_set = 0; #100;

        // ================= T20 화면 스위치를 흔들어도 카운터 값은 안 바뀜 =================
        sw_mode = 1; #100; btnR = 1; #PUSH; btnR = 0; #PUSH; #200_000; btnR = 1; #PUSH; btnR = 0; #PUSH;   // 스톱워치 값 고정
        m0 = dut.U_STOPWATCH_DATAPATH.w_msec + 100 * dut.U_STOPWATCH_DATAPATH.w_sec;
        for (i = 0; i < 40; i = i + 1) begin sw_display_mode = ~sw_display_mode; sw_24h = ~sw_24h; sw_mode = ~sw_mode; sw_timer = (i % 7 == 0); #777; end
        sw_mode = 1; sw_timer = 0; sw_24h = 0; sw_display_mode = 0; #100;
        if ((dut.U_STOPWATCH_DATAPATH.w_msec + 100 * dut.U_STOPWATCH_DATAPATH.w_sec) !== m0) begin err = err + 1; $display("T20 FAIL stopwatch changed by display switches"); end
        btnL = 1; #PUSH; btnL = 0; #PUSH; sw_mode = 0; #100;

        // ================= T21 빠른 시작/정지 10번 -> 매번 토글 =================
        sw_mode = 1; #100;
        for (i = 0; i < 10; i = i + 1) begin
            btnR = 1; #PUSH; btnR = 0; #PUSH;
            if (dut.w_run_stop !== (i % 2 == 0)) begin err = err + 1; $display("T21 FAIL toggle %0d", i); end
        end
        btnL = 1; #PUSH; btnL = 0; #PUSH; sw_mode = 0; #100;

        $display("---- monitor: %0d cycles checked, LED mismatches %0d, FND mismatches %0d", mon_n, mon_err_led, mon_err_fnd);
        err = err + mon_err_led + mon_err_fnd;

        if (err == 0) $display("TOTAL MISMATCH = 0  (PASS)");
        else $display("TOTAL MISMATCH = %0d", err);
        $finish;
    end
endmodule
