`timescale 1ns / 1ps

module tb_uart ();

    parameter BAUD_BIT_PERIOD = 100_000_000 / 9600 * 10;

    reg clk, rst, rx;
    reg [7:0] result_data, expected_data;
    wire tx;
    integer i;
    integer pass_count, fail_count;

    uart_fifo_loopback dut (
        .clk(clk),
        .rst(rst),
        .rx (rx),
        .tx (tx)
    );

    always #5 clk = ~clk;

    task sender_uart(input [7:0] send_data);
        integer i;
        begin
            rx = 0;  // start bit
            #(BAUD_BIT_PERIOD);
            // check start bit 0
            for (i = 0; i < 8; i = i + 1) begin
                rx = send_data[i];
                #(BAUD_BIT_PERIOD);
            end
            rx = 1;  // stop bit
            #(BAUD_BIT_PERIOD);
        end
    endtask

    task receive_uart(output [7:0] rx_data);
        integer i;
        begin
            wait (~tx);
            #(BAUD_BIT_PERIOD / 2);
            // check start bit 0. 중간 지점에서 start bit가 아직 0인지 확인.
            if (tx != 0) begin
                $display("error start bit error");
            end
            for (i = 0; i < 8; i = i + 1) begin
                #(BAUD_BIT_PERIOD);
                rx_data[i] = tx;
            end
            #(BAUD_BIT_PERIOD);
            if (!tx) $display("error stop bit");

        end
    endtask

    task score_board(input [7:0] result, input [7:0] expected);
        begin
            // to compare result data with expected data
            if (result == expected) begin
                pass_count = pass_count + 1;
                $display("%t : pass!!!", $time);
            end
            else begin
               fail_count = fail_count + 1;
               $display("%t : fail!!!", $time);
            end
        end
    endtask

    initial begin
        clk  = 0;
        rst  = 1;
        rx = 1;
        i = 0;
        pass_count=0;
        fail_count=0;
        expected_data = 8'h30;

        #10 rst = 0;

        for (i = 0; i < 1; i = i + 1) begin
            expected_data = $random() % 256;
            sender_uart(expected_data);
            receive_uart(result_data);
            score_board(result_data, expected_data);
        end
        #1000;
        $display("total test num = %0d", i);
        $display("Pass count = %0d", pass_count);
        $display("Fail count = %0d", fail_count);

        $stop;
    end                                                                                                                                                            endmodule