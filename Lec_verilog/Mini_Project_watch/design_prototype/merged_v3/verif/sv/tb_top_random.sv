`timescale 1ns / 1ps
// ============================================================================
// [검증 TB — SystemVerilog] 팀 통합판 Top(stopwatch_watch) 제약 랜덤 검증
//  - 자극: 클래스 기반 제약 랜덤 (버튼 길이 · 간격 · 동시 누름 · 튐, 스위치 전환, 비동기 리셋)
//  - 참조 모델: 사양(10/16 팀 합의 + 9일차 판서)으로 따로 쓴 클럭 단위 모델. DUT 의 디바운서 펄스 · 100 Hz tick ·
//               4 kHz 펄스만 관찰해 같은 사건으로 모델을 진행시키고, 매 클럭 전부 비교(스코어보드)
//  - 어서션: 동시(SVA) + 즉시
//  - 커버리지: 상태 · 전이 · 동시 입력 · 경계값
//  축소: 100 Hz tick 1 us(F_COUNT 100), 4 kHz 생성기 10 MHz(샘플 100 ns, 디바운스 창 800 ns)
// ============================================================================
module tb_top_random;
    localparam int TICK_FC = 100;
    localparam int GEN_FRQ = 10_000_000;
    localparam int SAMPLE_NS = 100;           // 4 kHz 생성기 축소 주기
    localparam int WIN_NS = 8 * SAMPLE_NS;    // 디바운스 창

    logic clk = 0; always #5 clk = ~clk;
    logic rst, btnR, btnL, btnU, btnD;
    logic sw_mode, sw_display_mode, sw_set, sw_24h, sw_timer;
    wire [3:0] fnd_com; wire [7:0] fnd_font; wire [15:0] led;

    defparam dut.U_TICK_GEN_100HZ.F_COUNT = TICK_FC;
    defparam dut.U_CLK_GEN_4KHz.CLK_FRQ   = GEN_FRQ;

    stopwatch_watch dut (.clk(clk), .rst(rst), .btnR(btnR), .btnL(btnL), .btnU(btnU), .btnD(btnD),
        .sw_mode(sw_mode), .sw_display_mode(sw_display_mode), .sw_set(sw_set), .sw_24h(sw_24h), .sw_timer(sw_timer),
        .fnd_com(fnd_com), .fnd_font(fnd_font), .led(led));

    // ------------------------------------------------------------------ plusargs
    int sim_us = 20000;     // 시뮬 길이 (us) — xsim.bat 가 plusarg 의 '=' 를 못 넘겨 기본값으로 돎
    int max_err = 30;
    initial begin
        if (!$value$plusargs("SIM_US=%d", sim_us)) sim_us = 20000;
        if (!$value$plusargs("MAX_ERR=%d", max_err)) max_err = 30;
    end

    // ------------------------------------------------------------------ 참조 모델 상태
    typedef enum int {W_N, W_H, W_M10, W_M1} wstate_t;
    typedef enum int {T_SET, T_RUN, T_ALARM} tstate_t;
    // 스톱워치
    bit        m_sw_run, m_sw_mode, m_lap;
    int        m_sw_ms, m_sw_s, m_sw_m, m_sw_h;          // 실제 카운터
    bit        m_sw_ot_ms, m_sw_ot_s, m_sw_ot_m;         // 리플(o_tick) 레지스터
    int        m_lap_ms, m_lap_s, m_lap_m, m_lap_h;
    // 시계
    wstate_t   m_wst;
    int        m_wt_ms, m_wt_s, m_wt_m, m_wt_h;
    bit        m_wt_ot_ms, m_wt_ot_s, m_wt_ot_m;
    // 타이머
    tstate_t   m_tst;
    int        m_tm_ms, m_tm_s, m_tm_m, m_tm_h;
    // FND 스캔
    int        m_sel;

    // 랩 저장용: 스텝 전 스톱워치 값
    int m_sw_ms_prev, m_sw_s_prev, m_sw_m_prev, m_sw_h_prev;

    function automatic void model_reset();
        m_sw_run = 0; m_sw_mode = 0; m_lap = 0;
        m_sw_ms = 0; m_sw_s = 0; m_sw_m = 0; m_sw_h = 0; m_sw_ot_ms = 0; m_sw_ot_s = 0; m_sw_ot_m = 0;
        m_lap_ms = 0; m_lap_s = 0; m_lap_m = 0; m_lap_h = 0;
        m_wst = W_N; m_wt_ms = 0; m_wt_s = 0; m_wt_m = 0; m_wt_h = 12; m_wt_ot_ms = 0; m_wt_ot_s = 0; m_wt_ot_m = 0;
        m_tst = T_SET; m_tm_ms = 0; m_tm_s = 0; m_tm_m = 0; m_tm_h = 0;
        m_sel = 0;
    endfunction

    // 스톱워치 tick_counter 한 칸 (수업 tick_counter 의미): clear > tick(업/다운, 돌기, o_tick) > 유지
    function automatic void sw_cnt(input int TIMES, input bit clear, input bit tick_in, input bit mode,
                                   ref int cur, ref bit ot);
        if (clear) begin cur = 0; ot = 0; end
        else if (tick_in) begin
            if (mode) begin if (cur == 0) begin cur = TIMES - 1; ot = 1; end else begin cur = cur - 1; end end
            else      begin if (cur == TIMES - 1) begin cur = 0; ot = 1; end else begin cur = cur + 1; end end
            // 돌지 않으면 o_tick 은 이전 값 유지 (RTL 과 같게)
        end else ot = 0;
    endfunction

    // 시계 watch_tick_counter 한 칸: tick 우선 > up/down(step, 돌기, o_tick 없음)
    function automatic void wt_cnt(input int TIMES, input bit tick_in, input bit up, input bit dn, input int step,
                                   ref int cur, ref bit ot);
        if (tick_in) begin
            if (cur == TIMES - 1) begin cur = 0; ot = 1; end else begin cur = cur + 1; ot = 0; end
        end else begin
            ot = 0;
            if (up) cur = (cur + step >= TIMES) ? cur + step - TIMES : cur + step;
            else if (dn) cur = (cur < step) ? cur + TIMES - step : cur - step;
        end
    endfunction

    // 현재 상태에서의 조합 출력 (비교용)
    function automatic int cursor_of(wstate_t s);
        case (s) W_M1: return 0; W_M10: return 1; W_H: return 2; default: return 3; endcase
    endfunction
    function automatic int hour12(input int h);
        return (h == 0) ? 12 : (h > 12) ? h - 12 : h;
    endfunction

    // 한 클럭 진행: 입력 = 이번 posedge 에서 DUT 가 보는 값들
    function automatic void model_step(input bit tick, input bit pR, input bit pL, input bit pU, input bit pD,
                                       input bit s_mode, input bit s_disp, input bit s_set, input bit s_24h, input bit s_tm);
        bit sel_tm, sel_sw, sel_wt;
        bit sw_clear, run_now, tick_sw;
        bit ot_ms_n, ot_s_n, ot_m_n;
        bit wt_L, wt_R, wt_U, wt_D, o_up, o_dn, setm;
        int cur;
        bit tm_L, tm_R, tm_U, tm_D, zero_now, tm_run_now, tm_clear, tm_add; int amt;
        int sec_sum, min_sum, carry;
        sel_tm = s_tm; sel_sw = ~s_tm & s_mode; sel_wt = ~s_tm & ~s_mode;

        // ---------------- 스톱워치 ----------------
        run_now  = m_sw_run;                         // 무어: 지금 상태
        sw_clear = pL & sel_sw & ~run_now;           // (10/16) 팀 CU: L 은 STOP 에서만
        tick_sw  = tick & run_now;
        begin : SWC
            bit o1, o2, o3; o1 = m_sw_ot_ms; o2 = m_sw_ot_s; o3 = m_sw_ot_m;
            // 각 칸의 i_tick 은 아래 칸의 "지금" o_tick (레지스터)
            sw_cnt(24,  sw_clear, m_sw_ot_m,  m_sw_mode, m_sw_h, o3);  // hour 의 o_tick 은 안 씀
            sw_cnt(60,  sw_clear, m_sw_ot_s,  m_sw_mode, m_sw_m, o3);
            sw_cnt(60,  sw_clear, m_sw_ot_ms, m_sw_mode, m_sw_s, o2);
            sw_cnt(100, sw_clear, tick_sw,    m_sw_mode, m_sw_ms, o1);
            m_sw_ot_ms = o1; m_sw_ot_s = o2; m_sw_ot_m = o3;
        end
        // 위 호출 순서 때문에 hour 에 쓴 o3 가 min 의 o3 로 덮임 -> min 의 o_tick 이 맞는 값. (hour o_tick 미사용)
        // 랩
        if (sw_clear) begin m_lap = 0; m_lap_ms = 0; m_lap_s = 0; m_lap_m = 0; m_lap_h = 0; end
        else if (pD & sel_sw) begin
            if (!m_lap) begin m_lap_ms = m_sw_ms_prev; m_lap_s = m_sw_s_prev; m_lap_m = m_sw_m_prev; m_lap_h = m_sw_h_prev; end
            m_lap = ~m_lap;
        end
        // CU 상태
        if (pR & sel_sw) m_sw_run = ~m_sw_run;
        if (pU & sel_sw & ~run_now) m_sw_mode = ~m_sw_mode;   // (10/16) U 는 STOP 에서만

        // ---------------- 시계 ----------------
        wt_L = pL & sel_wt; wt_R = pR & sel_wt; wt_U = pU & sel_wt; wt_D = pD & sel_wt;
        setm = (m_wst != W_N);
        cur  = cursor_of(m_wst);
        o_up = setm & s_set & wt_U;
        o_dn = setm & s_set & wt_D & ~wt_U;
        begin : WTC
            bit o1, o2, o3, dummy; o1 = m_wt_ot_ms; o2 = m_wt_ot_s; o3 = m_wt_ot_m;
            wt_cnt(24,  m_wt_ot_m,  o_up & (cur == 2), o_dn & (cur == 2), 1, m_wt_h, dummy);
            wt_cnt(60,  m_wt_ot_s,  o_up & (cur <= 1), o_dn & (cur <= 1), (cur == 1) ? 10 : 1, m_wt_m, o3);
            wt_cnt(60,  m_wt_ot_ms, 0, 0, 1, m_wt_s, o2);
            wt_cnt(100, tick,       0, 0, 1, m_wt_ms, o1);
            m_wt_ot_ms = o1; m_wt_ot_s = o2; m_wt_ot_m = o3;
        end
        // FSM 다음 상태 (우선: sw_set=0 > L > R)
        case (m_wst)
            W_N:   m_wst = s_set ? W_M1 : W_N;
            default: begin
                if (!s_set) m_wst = W_N;
                else if (wt_L) m_wst = (m_wst == W_M1) ? W_M10 : (m_wst == W_M10) ? W_H : W_M1;
                else if (wt_R) m_wst = (m_wst == W_M1) ? W_H : (m_wst == W_M10) ? W_M1 : W_M10;
            end
        endcase

        // ---------------- 타이머 ----------------
        tm_L = pL & sel_tm; tm_R = pR & sel_tm; tm_U = pU & sel_tm; tm_D = pD & sel_tm;
        zero_now = (m_tm_ms == 0 && m_tm_s == 0 && m_tm_m == 0 && m_tm_h == 0);
        tm_run_now = (m_tst == T_RUN);
        tm_clear = 0; tm_add = 0; amt = 0;
        case (m_tst)
            T_SET: begin
                if (tm_L) begin if (!zero_now) m_tst = T_RUN; end
                else if (tm_U) begin tm_add = 1; amt = 0; end
                else if (tm_R) begin tm_add = 1; amt = 1; end
                else if (tm_D) begin tm_add = 1; amt = 2; end
            end
            T_RUN: begin
                if (tm_L) begin m_tst = T_SET; tm_clear = 1; end
                else if (zero_now) m_tst = T_ALARM;
            end
            T_ALARM: if (tm_L | tm_R | tm_U | tm_D) m_tst = T_SET;
        endcase
        if (tm_clear) begin m_tm_ms = 0; m_tm_s = 0; m_tm_m = 0; m_tm_h = 0; end
        else if (tick & tm_run_now & !zero_now) begin
            if (m_tm_ms != 0) m_tm_ms--;
            else begin m_tm_ms = 99;
                if (m_tm_s != 0) m_tm_s--;
                else begin m_tm_s = 59;
                    if (m_tm_m != 0) m_tm_m--; else begin m_tm_m = 59; m_tm_h--; end
                end
            end
        end else if (tm_add) begin
            sec_sum = m_tm_s + ((amt == 0) ? 10 : 0);
            carry = (sec_sum >= 60); if (carry) sec_sum -= 60;
            min_sum = m_tm_m + ((amt == 1) ? 1 : (amt == 2) ? 10 : 0) + carry;
            if (min_sum >= 60) begin m_tm_m = 59; m_tm_s = 59; m_tm_ms = 0; end
            else begin m_tm_m = min_sum; m_tm_s = sec_sum; end
        end
    endfunction

    // ------------------------------------------------------------------ 기대 출력 계산 (현재 모델 상태의 조합 출력)
    logic [7:0] seg [0:15];
    initial begin
        seg[0]=8'hC0; seg[1]=8'hF9; seg[2]=8'hA4; seg[3]=8'hB0; seg[4]=8'h99; seg[5]=8'h92; seg[6]=8'h82; seg[7]=8'hF8; seg[8]=8'h80; seg[9]=8'h90;
        seg[10]=8'hC0; seg[11]=8'hC0; seg[12]=8'hC0; seg[13]=8'hFF; seg[14]=8'h7F; seg[15]=8'hFF;
    end
    function automatic logic [15:0] exp_led();
        bit sel_tm = sw_timer, sel_sw = ~sw_timer & sw_mode, sel_wt = ~sw_timer & ~sw_mode;
        bit alarm = (m_tst == T_ALARM), blink = (m_wt_ms >= 50), pm = (m_wt_h >= 12);
        logic [15:0] l;
        l[0] = alarm ? blink : sel_wt;  l[1] = alarm ? blink : sel_sw;
        l[2] = alarm ? blink : (~sw_timer & sw_display_mode); l[3] = alarm ? blink : (~sw_timer & ~sw_display_mode);
        l[4] = alarm ? blink : 1'b0;    l[5] = alarm ? blink : sel_tm;
        l[6] = alarm ? blink : (m_tst == T_RUN); l[7] = alarm ? blink : (sel_sw & m_lap);
        l[14:8] = (alarm & blink) ? 7'h7f : 7'h00;
        l[15] = alarm ? blink : (sel_wt & ~sw_24h & pm);
        return l;
    endfunction
    // 화면 값 (Top MUX + 랩 + 12/24 + 타이머 분.초 매핑)
    function automatic void disp_vals(output int d_ms, output int d_s, output int d_m, output int d_h, output bit disp);
        int sw_ms = m_lap ? m_lap_ms : m_sw_ms, sw_s = m_lap ? m_lap_s : m_sw_s, sw_m = m_lap ? m_lap_m : m_sw_m, sw_h = m_lap ? m_lap_h : m_sw_h;
        int wt_hd = sw_24h ? m_wt_h : hour12(m_wt_h);
        if (sw_timer) begin d_ms = m_tm_ms; d_s = m_tm_s; d_m = m_tm_s; d_h = m_tm_m; end
        else if (sw_mode) begin d_ms = sw_ms; d_s = sw_s; d_m = sw_m; d_h = sw_h; end
        else begin d_ms = m_wt_ms; d_s = m_wt_s; d_m = m_wt_m; d_h = wt_hd; end
        disp = sw_timer | sw_display_mode;
    endfunction
    function automatic void exp_fnd(output logic [3:0] com, output logic [7:0] font);
        int d_ms, d_s, d_m, d_h; bit disp, dot, blank; int g[4]; int code; int cur;
        disp_vals(d_ms, d_s, d_m, d_h, disp);
        dot = (d_ms >= 50);
        if (!disp) begin g[0] = d_ms % 10; g[1] = d_ms / 10; g[2] = d_s % 10; g[3] = d_s / 10; end
        else       begin g[0] = d_m % 10;  g[1] = d_m / 10;  g[2] = d_h % 10; g[3] = d_h / 10; end
        blank = sw_set & disp & ~(sw_mode | sw_timer) & dot;
        cur = cursor_of(m_wst);
        if (blank && cur <= 2) g[cur] = 13;
        case (m_sel)
            0,1,2,3: code = g[m_sel];
            6: code = dot ? 15 : 14;   // dot 모듈: msec >= 50 이면 1 = 점 OFF (수업 판과 같음)
            default: code = 15;
        endcase
        font = seg[code];
        case (m_sel[1:0]) 0: com = 4'b1110; 1: com = 4'b1101; 2: com = 4'b1011; default: com = 4'b0111; endcase
    endfunction

    // ------------------------------------------------------------------ 스코어보드 (매 negedge)
    int err = 0, n_cmp = 0, n_press = 0, n_rst = 0;
    bit model_valid = 0;
    logic [3:0] e_com; logic [7:0] e_font; logic [15:0] e_led;
    int d_ms, d_s, d_m, d_h; bit d_disp;
    task automatic fail(string s);
        err++;
        if (err <= max_err) $display("[%0t] FAIL %s", $time, s);
        if (err == max_err) $display("... (max_err reached, further FAIL messages suppressed)");
    endtask

    always @(negedge clk) begin
        #2;   // 스위치는 negedge 에 바뀜 -> 조합 출력이 정리된 뒤 비교
        if (rst) begin
            model_reset(); model_valid = 1;
        end else if (model_valid) begin
            // 1) 4 kHz 펄스가 이번 posedge 에 떴으면 DUT counter8 도 이미 +1 되었음
            if (dut.w_clk_4Khz) m_sel = (m_sel + 1) % 8;
            // 2) 비교
            n_cmp++;
            if (dut.U_STOPWATCH_DATAPATH.w_msec !== m_sw_ms || dut.U_STOPWATCH_DATAPATH.w_sec !== m_sw_s ||
                dut.U_STOPWATCH_DATAPATH.w_min !== m_sw_m || dut.U_STOPWATCH_DATAPATH.w_hour !== m_sw_h)
                fail($sformatf("stopwatch raw %0d:%0d:%0d.%0d exp %0d:%0d:%0d.%0d", dut.U_STOPWATCH_DATAPATH.w_hour, dut.U_STOPWATCH_DATAPATH.w_min, dut.U_STOPWATCH_DATAPATH.w_sec, dut.U_STOPWATCH_DATAPATH.w_msec, m_sw_h, m_sw_m, m_sw_s, m_sw_ms));
            if (dut.w_run_stop !== m_sw_run || dut.w_mode !== m_sw_mode || dut.w_lap_active !== m_lap)
                fail($sformatf("stopwatch ctrl run %b mode %b lap %b exp %b %b %b", dut.w_run_stop, dut.w_mode, dut.w_lap_active, m_sw_run, m_sw_mode, m_lap));
            if (m_lap && (dut.w_sw_msec !== m_lap_ms || dut.w_sw_sec !== m_lap_s || dut.w_sw_min !== m_lap_m || dut.w_sw_hour !== m_lap_h))
                fail($sformatf("lap display %0d:%0d:%0d.%0d exp %0d:%0d:%0d.%0d", dut.w_sw_hour, dut.w_sw_min, dut.w_sw_sec, dut.w_sw_msec, m_lap_h, m_lap_m, m_lap_s, m_lap_ms));
            if (dut.w_wt_msec !== m_wt_ms || dut.w_wt_sec !== m_wt_s || dut.w_wt_min !== m_wt_m || dut.w_wt_hour !== m_wt_h)
                fail($sformatf("watch %0d:%0d:%0d.%0d exp %0d:%0d:%0d.%0d", dut.w_wt_hour, dut.w_wt_min, dut.w_wt_sec, dut.w_wt_msec, m_wt_h, m_wt_m, m_wt_s, m_wt_ms));
            if (dut.w_cursor !== cursor_of(m_wst) || dut.w_set_mode !== (m_wst != W_N))
                fail($sformatf("watch fsm cursor %0d set %b exp %0d %b", dut.w_cursor, dut.w_set_mode, cursor_of(m_wst), (m_wst != W_N)));
            if (dut.w_tm_msec !== m_tm_ms || dut.w_tm_sec !== m_tm_s || dut.w_tm_min !== m_tm_m || dut.w_tm_hour !== m_tm_h)
                fail($sformatf("timer %0d:%0d:%0d.%0d exp %0d:%0d:%0d.%0d", dut.w_tm_hour, dut.w_tm_min, dut.w_tm_sec, dut.w_tm_msec, m_tm_h, m_tm_m, m_tm_s, m_tm_ms));
            if (dut.w_tm_run !== (m_tst == T_RUN) || dut.w_tm_alarm !== (m_tst == T_ALARM))
                fail($sformatf("timer fsm run %b alarm %b exp state %s", dut.w_tm_run, dut.w_tm_alarm, m_tst.name()));
            e_led = exp_led();
            if (led !== e_led) fail($sformatf("led %h exp %h", led, e_led));
            exp_fnd(e_com, e_font);
            if (fnd_com !== e_com || fnd_font !== e_font) fail($sformatf("fnd com %b font %h exp %b %h (sel %0d)", fnd_com, fnd_font, e_com, e_font, m_sel));
            // 3) 다음 posedge 를 위한 모델 진행 (DUT 가 posedge 에 볼 입력 = 지금 보이는 펄스 · tick · 스위치)
            m_sw_ms_prev = m_sw_ms; m_sw_s_prev = m_sw_s; m_sw_m_prev = m_sw_m; m_sw_h_prev = m_sw_h;
        end
    end
    // 자극 변경(스위치)은 negedge 의 다른 always 에서 하므로, 모델 스텝은 negedge 보다 약간 뒤(#1)에 — 그때의 스위치 값이 posedge 에 DUT 가 보는 값
    always @(negedge clk) begin
        #3;
        if (!rst && model_valid)
            model_step(dut.w_tick_10ms, dut.w_btnR, dut.w_btnL, dut.w_btnU, dut.w_btnD, sw_mode, sw_display_mode, sw_set, sw_24h, sw_timer);
    end

    // ------------------------------------------------------------------ SVA
    property p_pulse1(sig); @(posedge clk) disable iff (rst) sig |=> !sig; endproperty
    ap_pR: assert property (p_pulse1(dut.w_btnR)) else fail("SVA btnR pulse > 1 clk");
    ap_pL: assert property (p_pulse1(dut.w_btnL)) else fail("SVA btnL pulse > 1 clk");
    ap_pU: assert property (p_pulse1(dut.w_btnU)) else fail("SVA btnU pulse > 1 clk");
    ap_pD: assert property (p_pulse1(dut.w_btnD)) else fail("SVA btnD pulse > 1 clk");
    ap_tick: assert property (p_pulse1(dut.w_tick_10ms)) else fail("SVA tick pulse > 1 clk");
    ap_cur: assert property (@(posedge clk) disable iff (rst) (dut.w_cursor == 3) == !dut.w_set_mode) else fail("SVA cursor/set_mode");
    ap_alarm_zero: assert property (@(posedge clk) disable iff (rst) dut.w_tm_alarm |-> dut.w_tm_zero) else fail("SVA alarm without zero");
    ap_range_wt: assert property (@(posedge clk) disable iff (rst) dut.w_wt_hour < 24 && dut.w_wt_min < 60 && dut.w_wt_sec < 60 && dut.w_wt_msec < 100) else fail("SVA watch range");
    ap_range_sw: assert property (@(posedge clk) disable iff (rst) dut.U_STOPWATCH_DATAPATH.w_hour < 24 && dut.U_STOPWATCH_DATAPATH.w_min < 60 && dut.U_STOPWATCH_DATAPATH.w_sec < 60 && dut.U_STOPWATCH_DATAPATH.w_msec < 100) else fail("SVA stopwatch range");
    ap_range_tm: assert property (@(posedge clk) disable iff (rst) dut.w_tm_hour == 0 && dut.w_tm_min < 60 && dut.w_tm_sec < 60 && dut.w_tm_msec < 100) else fail("SVA timer range");
    ap_com: assert property (@(posedge clk) disable iff (rst) $countones(~fnd_com) == 1) else fail("SVA fnd_com not one-hot");
    ap_lapfreeze: assert property (@(posedge clk) disable iff (rst) (dut.w_lap_active && $past(dut.w_lap_active) && !dut.w_clear) |-> $stable({dut.w_sw_msec, dut.w_sw_sec, dut.w_sw_min, dut.w_sw_hour})) else fail("SVA lap display not frozen");
    ap_run_only_tick: assert property (@(posedge clk) disable iff (rst) (!dut.w_run_stop && !dut.w_clear) |=> $stable(dut.U_STOPWATCH_DATAPATH.w_msec)) else fail("SVA stopwatch moved while stopped");
    ap_tm_set_hold: assert property (@(posedge clk) disable iff (rst) (!dut.w_tm_run && !dut.w_tm_add && !dut.w_tm_clear) |=> $stable({dut.w_tm_msec, dut.w_tm_sec, dut.w_tm_min})) else fail("SVA timer moved while not running");

    // ------------------------------------------------------------------ 커버리지
    bit [3:0] cov_btn; int cov_dur;
    covergroup cg_watch @(posedge clk);
        option.per_instance = 1;
        c_wst: coverpoint m_wst;
        c_cur_btn: cross c_wst, cov_btn { ignore_bins none = binsof(cov_btn) intersect {0}; }
        c_h: coverpoint m_wt_h { bins zero = {0}; bins noon = {12}; bins last = {23}; bins other = default; }
        c_m: coverpoint m_wt_m { bins zero = {0}; bins last = {59}; bins other = default; }
        c_set_sw: coverpoint sw_set;
    endgroup
    covergroup cg_sw @(posedge clk);
        option.per_instance = 1;
        c_run: coverpoint m_sw_run; c_mode: coverpoint m_sw_mode; c_lap: coverpoint m_lap;
        c_cross: cross c_run, c_mode, c_lap;
        c_h: coverpoint m_sw_h { bins zero = {0}; bins last = {23}; bins other = default; }
    endgroup
    covergroup cg_tm @(posedge clk);
        option.per_instance = 1;
        c_tst: coverpoint m_tst;
        c_cap: coverpoint (m_tm_m == 59 && m_tm_s == 59) { bins cap = {1}; }
        c_min: coverpoint m_tm_m { bins zero = {0}; bins mid = {[1:58]}; bins max = {59}; }
    endgroup
    covergroup cg_stim @(posedge clk);
        option.per_instance = 1;
        c_view: coverpoint {sw_timer, sw_mode, sw_display_mode, sw_24h};
        c_multi: coverpoint $countones(cov_btn) { bins one = {1}; bins two = {2}; bins three_four = {[3:4]}; }
        c_dur: coverpoint cov_dur { bins short_ignored = {[0:600]}; bins normal = {[1200:5000]}; bins long_ = {[5001:$]}; }
    endgroup
    cg_watch cgw = new(); cg_sw cgs = new(); cg_tm cgt = new(); cg_stim cgst = new();
    // tick 과 버튼 같은 클럭(분 카운터에 초 넘김 tick + up)
    int n_same_clk_tick_btn = 0, n_tick_any_btn = 0, n_sw_clear_tick = 0, n_inj = 0, n_alarm = 0;
    always @(posedge dut.w_tm_alarm) n_alarm++;
    always @(posedge clk) if (!rst) begin
        if (dut.U_WATCH_DATAPATH.U_MIN_COUNTER.i_tick && (dut.U_WATCH_DATAPATH.U_MIN_COUNTER.i_up | dut.U_WATCH_DATAPATH.U_MIN_COUNTER.i_down)) n_same_clk_tick_btn++;
        if (dut.w_tick_10ms && (dut.w_btnR | dut.w_btnL | dut.w_btnU | dut.w_btnD)) n_tick_any_btn++;
        if (dut.w_tick_10ms && dut.w_clear && dut.w_run_stop) n_sw_clear_tick++;
    end
    bit inj_hold = 0;

    // ------------------------------------------------------------------ 자극 클래스
    class Press;
        rand bit [3:0] which;        // {D,U,L,R}
        rand int unsigned dur;       // ns
        rand int unsigned gap;       // ns, 누른 뒤 쉬는 시간
        rand bit bounce;
        rand int unsigned nb;        // 튐 조각 수
        constraint c_which { which != 0; which dist {4'b0001 := 30, 4'b0010 := 30, 4'b0100 := 20, 4'b1000 := 20, [4'b0011:4'b1111] := 10}; }
        constraint c_dur { dur dist {[100:600] := 15, [1200:5000] := 70, [5001:30000] := 15}; }
        constraint c_gap { gap dist {[0:300] := 10, [1000:20000] := 80, [20001:80000] := 10}; }
        constraint c_b { bounce dist {0 := 70, 1 := 30}; nb inside {[2:10]}; }
    endclass
    class SwChange;
        rand int unsigned wait_ns;
        rand int unsigned which;     // 0 mode 1 disp 2 set 3 24h 4 timer
        constraint c_w { wait_ns inside {[500:60000]}; }
        constraint c_s { which dist {0 := 20, 1 := 20, 2 := 35, 3 := 10, 4 := 15}; }
    endclass

    // 버튼 드라이버 (4개 동시 가능)
    task automatic do_press(Press p);
        int k; int unsigned seg_ns;
        cov_btn = p.which; cov_dur = p.dur;
        if (p.bounce) begin
            for (k = 0; k < p.nb; k++) begin
                seg_ns = 30 + $urandom_range(0, 250);         // 튐 조각 < 창(800 ns)
                {btnD, btnU, btnL, btnR} = (k % 2 == 0) ? p.which : 4'b0000; #(seg_ns);
            end
        end
        {btnD, btnU, btnL, btnR} = p.which; #(p.dur);
        if (p.bounce) begin
            for (k = 0; k < p.nb; k++) begin
                seg_ns = 30 + $urandom_range(0, 250);
                {btnD, btnU, btnL, btnR} = (k % 2 == 0) ? 4'b0000 : p.which; #(seg_ns);
            end
        end
        {btnD, btnU, btnL, btnR} = 4'b0000;
        n_press++;
        #(p.gap);
        cov_btn = 0;
    endtask

    // ------------------------------------------------------------------ 메인
    initial begin
        Press p = new(); SwChange s = new();
        rst = 1; btnR = 0; btnL = 0; btnU = 0; btnD = 0;
        sw_mode = 0; sw_display_mode = 0; sw_set = 0; sw_24h = 0; sw_timer = 0;
        #103 rst = 0;
        $display("tb_top_random: SIM_US=%0d", sim_us);
        fork
            // 버튼
            forever begin
                if (!p.randomize()) $fatal(1, "randomize Press");
                do_press(p);
                if ($urandom_range(0, 99) < 3) #($urandom_range(800_000, 1_500_000));
                // 타이머 시나리오(2%): 타이머 화면에서 +10초 -> 시작 -> 알람까지 조용히 -> 아무 버튼 (랜덤만으로는 L 이 취소해 ALARM 에 못 감)
                if ($urandom_range(0, 99) < 2 && !inj_hold) begin
                    inj_hold = 1;                       // 스위치 프로세스 멈춤 (타이머 화면 유지)
                    @(negedge clk); sw_timer = 1; #2000;
                    if (dut.w_tm_run) begin btnL = 1; #3000; btnL = 0; #3000; end          // 진행 중이면 취소 -> 0
                    if (dut.w_tm_alarm) begin btnD = 1; #3000; btnD = 0; #3000; end        // 알람 중이면 끄기
                    if (!dut.w_tm_zero) begin btnL = 1; #3000; btnL = 0; #3000; btnL = 1; #3000; btnL = 0; #3000; end  // 시작+취소 -> 0
                    btnU = 1; #3000; btnU = 0; #3000;   // +10초
                    btnL = 1; #3000; btnL = 0;          // 시작
                    #($urandom_range(1_050_000, 1_300_000));   // 10 "초" = 1 ms 뒤 알람
                    btnD = 1; #3000; btnD = 0; #3000;   // 끄기 (더해지지 않아야)
                    n_press += 5;
                    inj_hold = 0;
                end
            end
            // 스위치
            forever begin
                if (!s.randomize()) $fatal(1, "randomize SwChange");
                #(s.wait_ns);
                @(negedge clk);
                if (inj_hold) continue;
                case (s.which)
                    0: sw_mode = ~sw_mode; 1: sw_display_mode = ~sw_display_mode; 2: sw_set = ~sw_set;
                    3: sw_24h = ~sw_24h; default: sw_timer = ~sw_timer;
                endcase
            end
            // 비동기 리셋 (드물게, 클럭과 무관한 시각)
            forever begin
                #($urandom_range(3_000_000, 8_000_000));
                #($urandom_range(0, 9));
                rst = 1; n_rst++;
                #($urandom_range(30, 300));
                @(negedge clk); #1; rst = 0;   // 해제는 negedge+1: 비교(+2) · 모델 스텝(+3) 전
            end
            // 충돌 주입: 분 카운터에 '초 넘김 tick' 과 U 펄스를 같은 클럭에 (디바운서 우회, w_btnU 를 1클럭 force)
            begin
                #60_000;
                forever begin
                    #($urandom_range(200_000, 600_000));
                    wait (dut.w_wt_sec == 59 && dut.w_wt_msec >= 90 && !rst);   // 초 넘김 약 1 ms 전
                    inj_hold = 1;
                    @(negedge clk); sw_timer = 0; sw_mode = 0; sw_set = 1;
                    repeat (4) @(negedge clk);
                    if (dut.w_cursor == 2) begin @(negedge clk); #2.5; force dut.w_btnL = 1; @(negedge clk); #2.5; release dut.w_btnL; end
                    wait ((dut.w_wt_sec == 59 && dut.w_wt_msec == 99) || rst || dut.w_wt_sec != 59);
                    @(negedge clk); while (!dut.w_tick_10ms && !rst && dut.w_wt_sec == 59) @(negedge clk);
                    @(negedge clk);              // posedge: msec 99->0
                    @(negedge clk); #2.5;        // posedge: sec 59->0 (sec o_tick=1) -> 다음 posedge 에 분 i_tick=1
                    if (!rst && dut.w_cursor <= 1 && sw_set && !sw_mode && !sw_timer && dut.U_WATCH_DATAPATH.U_SEC_COUNTER.o_tick) begin
                        force dut.w_btnU = 1; n_inj++;
                        @(negedge clk); #2.5; release dut.w_btnU;
                    end
                    repeat (3) @(negedge clk);
                    inj_hold = 0;
                end
            end
            // 종료
            begin
                #(sim_us * 1000);
                $display("---- cycles compared %0d, presses %0d, resets %0d", n_cmp, n_press, n_rst);
                $display("---- timer alarms %0d", n_alarm);
                $display("---- coincidences: tick+any button pulse same clock %0d, stopwatch tick+clear while running %0d, min-counter tick+U/D same clock %0d (injected %0d)", n_tick_any_btn, n_sw_clear_tick, n_same_clk_tick_btn, n_inj);
                $display("---- coverage: watch %0.1f%%  stopwatch %0.1f%%  timer %0.1f%%  stim %0.1f%%", cgw.get_inst_coverage(), cgs.get_inst_coverage(), cgt.get_inst_coverage(), cgst.get_inst_coverage());
                if (err == 0) $display("TOTAL MISMATCH = 0  (PASS)"); else $display("TOTAL MISMATCH = %0d", err);
                $finish;
            end
        join
    end
endmodule
