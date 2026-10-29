`timescale 1ns / 1ps
// 4 단계 : Top (UART + FIFO + ascii_decoder + 스톱워치) — 키보드 · 버튼으로 스톱워치 제어
//  (1) 'r' → RUN (control_unit run_stop = 1)         (2) 25 ms 뒤 msec > 0 (100 Hz 로 셈)
//  (3) 'r' 한 번 더 → STOP, 15 ms 동안 msec 그대로   (4) 'u' → o_sw_down = 1 (down)
//  (5) 'c' → msec = 0                                (6) 버튼 btn_R 5 ms → RUN (OR 확인)
// 경로 이름은 내 Top 인스턴스 이름에 맞춘다 (U_STOPWATCH_WATCH = 미니프로젝트 제출판 stopwatch_watch).
module tb_hw4_top ();
    parameter BAUD_BIT_PERIOD = 100_000_000 / 9600 * 10;
    reg clk, rst, rx, btn_R;
    wire tx;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;
    wire [15:0] led;
    integer err;
    reg [6:0] m1;

    uart_fifo_ascii dut (
        .clk             (clk),
        .rst             (rst),
        .rx              (rx),
        .btn_R           (btn_R),
        .btn_L           (1'b0),
        .btn_U           (1'b0),
        .btn_D           (1'b0),
        .mode_sw0        (1'b1),   // 1 = 스톱워치 화면 (버튼이 스톱워치로 감)
        .display_mode_sw1(1'b0),
        .set_sw2         (1'b0),
        .hour24_sw3      (1'b0),
        .timer_sw4       (1'b0),
        .tx              (tx),
        .fnd_com         (fnd_com),
        .fnd_font        (fnd_font),
        .led             (led)
    );

    always #5 clk = ~clk;

    task sender_uart(input [7:0] send_data);
        integer i;
        begin
            rx = 0; #(BAUD_BIT_PERIOD);
            for (i = 0; i < 8; i = i + 1) begin rx = send_data[i]; #(BAUD_BIT_PERIOD); end
            rx = 1; #(BAUD_BIT_PERIOD);
        end
    endtask

    initial begin
        clk = 0; rst = 1; rx = 1; btn_R = 0; err = 0;
        #10 rst = 0;

        sender_uart("r"); #1000;
        if (dut.U_STOPWATCH_WATCH.U_STOPWATCH_CONTROL_UNIT.o_sw_run_stop !== 1'b1) begin err = err + 1; $display("%t (1) MISMATCH run_stop = %b (expect 1)", $time, dut.U_STOPWATCH_WATCH.U_STOPWATCH_CONTROL_UNIT.o_sw_run_stop); end
        else $display("%t (1) 'r' -> run_stop = 1", $time);

        #25_000_000;
        m1 = dut.U_STOPWATCH_WATCH.U_STOPWATCH_DATAPATH.o_sw_msec;
        if (m1 == 0) begin err = err + 1; $display("%t (2) MISMATCH msec = 0 (expect > 0)", $time); end
        else $display("%t (2) 25 ms later msec = %0d", $time, m1);

        sender_uart("r"); #1000;
        m1 = dut.U_STOPWATCH_WATCH.U_STOPWATCH_DATAPATH.o_sw_msec;
        #15_000_000;
        if (dut.U_STOPWATCH_WATCH.U_STOPWATCH_CONTROL_UNIT.o_sw_run_stop !== 1'b0 || dut.U_STOPWATCH_WATCH.U_STOPWATCH_DATAPATH.o_sw_msec !== m1) begin
            err = err + 1; $display("%t (3) MISMATCH run_stop = %b, msec %0d -> %0d (expect 0, same)", $time, dut.U_STOPWATCH_WATCH.U_STOPWATCH_CONTROL_UNIT.o_sw_run_stop, m1, dut.U_STOPWATCH_WATCH.U_STOPWATCH_DATAPATH.o_sw_msec); end
        else $display("%t (3) 'r' -> run_stop = 0, msec stays %0d", $time, m1);

        sender_uart("u"); #1000;
        if (dut.U_STOPWATCH_WATCH.U_STOPWATCH_CONTROL_UNIT.o_sw_down !== 1'b1) begin err = err + 1; $display("%t (4) MISMATCH o_sw_down = %b (expect 1)", $time, dut.U_STOPWATCH_WATCH.U_STOPWATCH_CONTROL_UNIT.o_sw_down); end
        else $display("%t (4) 'u' -> o_sw_down = 1", $time);

        sender_uart("c"); #1000;
        if (dut.U_STOPWATCH_WATCH.U_STOPWATCH_DATAPATH.o_sw_msec !== 0) begin err = err + 1; $display("%t (5) MISMATCH msec = %0d (expect 0)", $time, dut.U_STOPWATCH_WATCH.U_STOPWATCH_DATAPATH.o_sw_msec); end
        else $display("%t (5) 'c' -> msec = 0", $time);

        btn_R = 1; #5_000_000; btn_R = 0; #1_000_000;   // 디바운서 4 kHz x 8 번 = 약 2 ms 눌러야 인식
        if (dut.U_STOPWATCH_WATCH.U_STOPWATCH_CONTROL_UNIT.o_sw_run_stop !== 1'b1) begin err = err + 1; $display("%t (6) MISMATCH after btn_R run_stop = %b (expect 1)", $time, dut.U_STOPWATCH_WATCH.U_STOPWATCH_CONTROL_UNIT.o_sw_run_stop); end
        else $display("%t (6) btn_R -> run_stop = 1", $time);

        $display("TOTAL MISMATCH = %0d", err);
        $stop;
    end
endmodule
