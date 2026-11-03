`timescale 1ns / 1ps
// [검증 TB] Top — 실제 파라미터 그대로 (tick 10 ms, 4 kHz 디바운스 2 ms). 축소 시뮬이 숨겼을 수 있는 폭·주기 문제 확인
// 55 ms 만 돌린다 (100 MHz x 55 ms = 550만 클럭)
module tb_top_realtime ();
    reg clk, rst, btnR, btnL, btnU, btnD;
    reg sw_mode, sw_display_mode, sw_set, sw_24h, sw_timer;
    wire [3:0] fnd_com; wire [7:0] fnd_font; wire [15:0] led;
    stopwatch_watch dut (.clk(clk), .rst(rst), .btnR(btnR), .btnL(btnL), .btnU(btnU), .btnD(btnD),
        .sw_mode(sw_mode), .sw_display_mode(sw_display_mode), .sw_set(sw_set), .sw_24h(sw_24h), .sw_timer(sw_timer),
        .fnd_com(fnd_com), .fnd_font(fnd_font), .led(led));
    always #5 clk = ~clk;
    integer err, n_tick, n_4k, t0, t1, n_com, t_press, t_pulse;
    reg [3:0] com_d;
    always @(posedge clk) if (!rst) begin
        if (dut.w_tick_10ms) n_tick = n_tick + 1;
        if (dut.w_clk_4Khz) n_4k = n_4k + 1;
    end
    always @(fnd_com) n_com = n_com + 1;

    initial begin
        clk = 0; rst = 1; btnR = 0; btnL = 0; btnU = 0; btnD = 0; err = 0; n_tick = 0; n_4k = 0; n_com = 0;
        sw_mode = 1; sw_display_mode = 0; sw_set = 0; sw_24h = 0; sw_timer = 0;
        #100 rst = 0;
        // 1 ms 에 R 누름(25 ms 유지) -> 디바운스 2 ms 뒤 펄스 -> 약 3 ms 부터 RUN
        #1_000_000; t_press = $time; btnR = 1;
        @(posedge dut.w_btnR); t_pulse = $time;
        if ((t_pulse - t_press) < 1_990_000 || (t_pulse - t_press) > 2_260_000) begin err = err + 1; $display("FAIL debounce latency %0d ns", t_pulse - t_press); end
        else $display("debounce latency %0d ns (real 4 kHz x 8)", t_pulse - t_press);
        #25_000_000 btnR = 0;
        // 53 ms 시점: 리셋 후 tick 은 10, 20, 30, 40, 50 ms -> 스톱워치 5 (3 ms 부터 RUN), 시계 12:00:00.05
        @(posedge clk); while ($time < 53_000_000) @(posedge clk);
        if (dut.U_STOPWATCH_DATAPATH.w_msec !== 5) begin err = err + 1; $display("FAIL stopwatch msec %0d at 53 ms (expect 5)", dut.U_STOPWATCH_DATAPATH.w_msec); end
        if (dut.w_wt_msec !== 5 || dut.w_wt_hour !== 12) begin err = err + 1; $display("FAIL watch %0d:%0d.%0d", dut.w_wt_hour, dut.w_wt_min, dut.w_wt_msec); end
        if (n_tick !== 5) begin err = err + 1; $display("FAIL tick count %0d", n_tick); end
        // 4 kHz 펄스 수: 53 ms x 4000 = 212 (+-1)
        if (n_4k < 211 || n_4k > 213) begin err = err + 1; $display("FAIL 4 kHz pulses %0d (expect ~212)", n_4k); end
        // FND 스캔: 자리(com) 변화 = 4 kHz 마다 1 -> 약 212 회, 한 바퀴 2 ms
        if (n_com < 205 || n_com > 215) begin err = err + 1; $display("FAIL fnd com changes %0d", n_com); end
        $display("at 53 ms: stopwatch 00:00:00.%02d, watch %0d:%02d:%02d.%02d, ticks %0d, 4kHz pulses %0d, com changes %0d", dut.U_STOPWATCH_DATAPATH.w_msec, dut.w_wt_hour, dut.w_wt_min, dut.w_wt_sec, dut.w_wt_msec, n_tick, n_4k, n_com);
        // 정지: R 다시 (2 ms 디바운스 뒤) -> 그 뒤 tick 이 와도 안 셈
        btnR = 1; @(posedge dut.w_btnR); #3_000_000; btnR = 0;
        t0 = dut.U_STOPWATCH_DATAPATH.w_msec;
        @(posedge clk); while ($time < 75_000_000) @(posedge clk);
        if (dut.U_STOPWATCH_DATAPATH.w_msec !== t0) begin err = err + 1; $display("FAIL counted after stop"); end
        if (dut.w_wt_msec !== 7) begin err = err + 1; $display("FAIL watch msec at 75 ms = %0d (expect 7)", dut.w_wt_msec); end
        $display("TOTAL MISMATCH = %0d", err);
        $finish;
    end
endmodule
