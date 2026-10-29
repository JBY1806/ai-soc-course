`timescale 1ns / 1ps
// 5 단계 : 's' → ascii_sender 가 고정 데이터를 FIFO_TX 에 push → UART_TX → PC 가 받음
//  EXP0 · EXP1 = 내가 정한 고정 데이터로 바꾼다 (아래는 예시 "OK").
//  (1) '1' 을 보내면 tx 는 조용해야 함 (루프백 끊김)   (2) 's' 를 보내면 EXP0 · EXP1 이 차례로 돌아옴
module tb_hw5_sender ();
    parameter BAUD_BIT_PERIOD = 100_000_000 / 9600 * 10;
    parameter [7:0] EXP0 = "O", EXP1 = "K";
    reg clk, rst, rx;
    wire tx;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;
    wire [15:0] led;
    reg [7:0] r0, r1;
    integer err, tx_fall;

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
    always @(negedge tx) tx_fall = tx_fall + 1;

    // 시간 초과 감시 : 바이트가 덜 오면 receive_uart 가 영원히 기다리므로 20 ms 에 멈춘다
    initial begin
        #20_000_000;
        $display("%t TIMEOUT - PC got only part of the bytes (got r0 = %h). TOTAL MISMATCH = %0d", $time, r0, err + 1);
        $stop;
    end

    task sender_uart(input [7:0] send_data);
        integer i;
        begin
            rx = 0; #(BAUD_BIT_PERIOD);
            for (i = 0; i < 8; i = i + 1) begin rx = send_data[i]; #(BAUD_BIT_PERIOD); end
            rx = 1; #(BAUD_BIT_PERIOD);
        end
    endtask

    task receive_uart(output [7:0] rx_data);
        integer i;
        begin
            wait (~tx);
            #(BAUD_BIT_PERIOD / 2);
            for (i = 0; i < 8; i = i + 1) begin #(BAUD_BIT_PERIOD); rx_data[i] = tx; end
            #(BAUD_BIT_PERIOD);
        end
    endtask

    initial begin
        clk = 0; rst = 1; rx = 1; err = 0; tx_fall = 0;
        #10 rst = 0;

        sender_uart("1");
        #(BAUD_BIT_PERIOD * 12);
        if (tx_fall !== 0) begin err = err + 1; $display("%t (1) MISMATCH tx fell %0d times after '1' (expect 0)", $time, tx_fall); end
        else $display("%t (1) '1' -> tx quiet (no loopback)", $time);

        fork
            sender_uart("s");
            begin receive_uart(r0); receive_uart(r1); end
        join
        if (r0 !== EXP0 || r1 !== EXP1) begin err = err + 1; $display("%t (2) MISMATCH PC got %h %h (expect %h %h)", $time, r0, r1, EXP0, EXP1); end
        else $display("%t (2) 's' -> PC got %h %h", $time, r0, r1);

        #1000;
        $display("TOTAL MISMATCH = %0d", err);
        $stop;
    end
endmodule
