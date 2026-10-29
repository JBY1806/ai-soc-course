`timescale 1ns / 1ps
// 3 단계 : pop 조합 vs 순차 비교 — UART 로 'r' 한 글자를 보내고, pop 과 디코더 run_stop 이 몇 클럭 1 인지 센다.
//  조합 (pop = enable 그대로) 과 순차 (pop 을 레지스터로 한 클럭 늦게) 두 번 돌려 결과를 비교한다.
// 경로 이름 (dut.U_ASCII_DECODER ...) 은 내 Top 인스턴스 이름에 맞춘다.
module tb_hw3_pop_compare ();
    parameter BAUD_BIT_PERIOD = 100_000_000 / 9600 * 10;
    reg clk, rst, rx;
    wire tx;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;
    wire [15:0] led;
    integer n_pop, n_r;

    uart_fifo_ascii dut (
        .clk             (clk),
        .rst             (rst),
        .rx              (rx),
        .btn_R           (1'b0),
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
    always @(posedge clk) begin
        if (dut.U_ASCII_DECODER.o_pop)      n_pop = n_pop + 1;
        if (dut.U_ASCII_DECODER.o_key_run_stop) n_r   = n_r + 1;
    end

    task sender_uart(input [7:0] send_data);
        integer i;
        begin
            rx = 0; #(BAUD_BIT_PERIOD);
            for (i = 0; i < 8; i = i + 1) begin rx = send_data[i]; #(BAUD_BIT_PERIOD); end
            rx = 1; #(BAUD_BIT_PERIOD);
        end
    endtask

    initial begin
        clk = 0; rst = 1; rx = 1; n_pop = 0; n_r = 0;
        #10 rst = 0;
        sender_uart("r");
        #1000;
        $display("'r' x1 : pop high %0d clocks, run_stop high %0d clocks, control_unit run_stop = %b",
                 n_pop, n_r, dut.U_STOPWATCH_WATCH.U_STOPWATCH_CONTROL_UNIT.o_sw_run_stop);
        $stop;
    end
endmodule
