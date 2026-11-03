`timescale 1ns / 1ps
// [검증 에이전트 세션 1] E15 — Top(stopwatch_watch) 실제 파라미터 그대로 (100 MHz, tick 10 ms, 디바운스 4 kHz 8칸)
// 시나리오 길이 약 32 ms (1초 이하). 정보윤 담당 경로: 디바운서 출력 -> watch_control_unit -> watch_datapath
module tb_e15_top ();
    reg clk, rst, btnR, btnL, btnU, btnD;
    reg sw_mode, sw_display_mode, sw_set, sw_24h, sw_timer;
    wire [3:0]  fnd_com;
    wire [7:0]  fnd_font;
    wire [15:0] led;

    integer err, n_up, n_down, n_tick;
    integer t_press, t_first_up, t_tick1, t_tick2;

    parameter PUSH = 5_000_000;   // 5 ms 누름 / 5 ms 뗌

    stopwatch_watch dut (
        .clk(clk), .rst(rst), .btnR(btnR), .btnL(btnL), .btnU(btnU), .btnD(btnD),
        .sw_mode(sw_mode), .sw_display_mode(sw_display_mode), .sw_set(sw_set), .sw_24h(sw_24h), .sw_timer(sw_timer),
        .fnd_com(fnd_com), .fnd_font(fnd_font), .led(led));

    always #5 clk = ~clk;

    // 시계 FSM 이 데이터패스로 보낸 +/- 펄스 수, 100 Hz tick 시각
    always @(posedge clk) begin
        if (dut.w_up === 1'b1) begin
            n_up = n_up + 1;
            if (t_first_up == 0) t_first_up = $time;
        end
        if (dut.w_down === 1'b1) n_down = n_down + 1;
        if (dut.w_tick_10ms === 1'b1) begin
            n_tick = n_tick + 1;
            if (n_tick == 1) t_tick1 = $time;
            if (n_tick == 2) t_tick2 = $time;
        end
    end

    initial begin
        clk = 0; rst = 1; err = 0; n_up = 0; n_down = 0; n_tick = 0; t_first_up = 0; t_tick1 = 0; t_tick2 = 0;
        btnR = 0; btnL = 0; btnU = 0; btnD = 0;
        sw_mode = 0; sw_display_mode = 1; sw_set = 1; sw_24h = 0; sw_timer = 0;
        #1000;
        @(negedge clk);

        // (a) 리셋 해제한 바로 그 클럭부터 U 를 누름 -> 디바운스(약 2 ms) 뒤 펄스 1개, 분 0 -> 1
        $display("E15a start %0d ns", $time);
        rst = 0; btnU = 1; t_press = $time;
        #PUSH; btnU = 0; #PUSH;
        if (dut.U_WATCH_CONTROL_UNIT.c_state !== 2'b11 || dut.w_cursor !== 2'd0) begin err = err + 1; $display("E15a FAIL state %b cursor %0d", dut.U_WATCH_CONTROL_UNIT.c_state, dut.w_cursor); end
        if (n_up !== 1 || dut.w_wt_min !== 6'd1 || dut.w_wt_hour !== 5'd12) begin err = err + 1; $display("E15a FAIL n_up %0d time %0d:%0d exp 1 pulse, 12:01", n_up, dut.w_wt_hour, dut.w_wt_min); end
        $display("E15a INFO press -> o_up pulse delay = %0d ns", t_first_up - t_press);
        if ((t_first_up - t_press) < 1_750_000 || (t_first_up - t_press) > 2_300_000) begin err = err + 1; $display("E15a FAIL debounce delay not about 2 ms"); end

        // (b) U 와 D 를 같은 순간에 누름 (디바운서 두 개가 같은 4 kHz 샘플로 같은 클럭 펄스) -> U, 분 1 -> 2
        $display("E15b start %0d ns", $time);
        btnU = 1; btnD = 1; #PUSH; btnU = 0; btnD = 0; #PUSH;
        if (n_up !== 2 || n_down !== 0 || dut.w_wt_min !== 6'd2) begin err = err + 1; $display("E15b FAIL n_up %0d n_down %0d min %0d exp 2, 0, 2", n_up, n_down, dut.w_wt_min); end

        // (c) L 과 R 을 같은 순간에 누름 -> L (SET_MIN_1 -> SET_MIN_10, cursor 1)
        $display("E15c start %0d ns", $time);
        btnL = 1; btnR = 1; #PUSH; btnL = 0; btnR = 0; #PUSH;
        if (dut.U_WATCH_CONTROL_UNIT.c_state !== 2'b10 || dut.w_cursor !== 2'd1) begin err = err + 1; $display("E15c FAIL state %b cursor %0d exp SET_MIN_10, 1", dut.U_WATCH_CONTROL_UNIT.c_state, dut.w_cursor); end
        if ({dut.w_wt_hour, dut.w_wt_min} !== {5'd12, 6'd2}) begin err = err + 1; $display("E15c FAIL time changed %0d:%0d", dut.w_wt_hour, dut.w_wt_min); end

        // (d) 100 Hz tick 이 실제 10 ms 간격, 시계 1/100초가 그만큼 흐름 (설정 중에도)
        $display("E15d INFO tick1 %0d ns, tick2 %0d ns, period %0d ns, ticks %0d, msec %0d", t_tick1, t_tick2, t_tick2 - t_tick1, n_tick, dut.w_wt_msec);
        if ((t_tick2 - t_tick1) !== 10_000_000) begin err = err + 1; $display("E15d FAIL tick period %0d ns exp 10,000,000", t_tick2 - t_tick1); end
        if (dut.w_wt_msec !== n_tick) begin err = err + 1; $display("E15d FAIL watch msec %0d != ticks %0d", dut.w_wt_msec, n_tick); end

        $display("end %0d ns", $time);
        $display("TOTAL MISMATCH = %0d", err);
        $finish;
    end
endmodule
