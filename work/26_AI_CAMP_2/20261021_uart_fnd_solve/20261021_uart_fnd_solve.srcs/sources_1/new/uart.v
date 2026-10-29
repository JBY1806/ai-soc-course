`timescale 1ns / 1ps

module uart_loopback (
    input clk,
    input rst,
    input rx,  // from PC
    output rx_done,
    output [7:0] rx_data,
    output tx
);

    wire       w_b_tick;
    wire       w_rx_done;
    wire [7:0] w_rx_data;

    assign rx_done = w_rx_done;  // 추가 : 안쪽 선 → 바깥 출력 포트
    assign rx_data = w_rx_data;  // 추가

    uart_rx U_UART_RX (
        .clk    (clk),
        .rst    (rst),
        .b_tick (w_b_tick),
        .rx     (rx),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    uart_tx U_UART_TX (
        .clk     (clk),
        .rst     (rst),
        .tx_start(w_rx_done),
        .tx_data (w_rx_data),
        .b_tick  (w_b_tick),
        .tx      (tx),
        .tx_busy ()
    );

    baud_tick_gen U_BAUD_TICK_GEN (
        .clk   (clk),
        .rst   (rst),
        .b_tick(w_b_tick)
    );

endmodule


module baud_tick_gen (
    input      clk,
    input      rst,
    output reg b_tick
);
    // 100Mhz -> 153,600 Hz (9600hz * 16)
    parameter F_COUNT = 100_000_000 / (9600 * 16);
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick      <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                b_tick      <= 1'b1;
            end else begin
                b_tick <= 1'b0;
            end
        end
    end
endmodule










