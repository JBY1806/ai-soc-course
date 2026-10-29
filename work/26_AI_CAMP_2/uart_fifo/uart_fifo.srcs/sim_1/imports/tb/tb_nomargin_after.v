`timescale 1ns / 1ps

// 5단계 : 마진 시험
//   보드가 한 글자를 다 받은 순간(rx_done) 기준으로 얼마 뒤에 다음 글자를 보내는가
//   margin 0        : rx_done 이 뜨자마자 바로 (노마진, 워스트 케이스)
//   margin 1/4 비트
//   margin 1/2 비트 : stop bit 를 끝까지 보낸 것과 같음 (보통 PC)
//   margin 1 비트
module tb_nomargin_after ();

    parameter BAUD_BIT_PERIOD = 100_000_000 / 9600 * 10;
    parameter N = 16;  // 마진 하나당 보낼 글자 수

    reg clk, rst, rx;
    reg [7:0] result_data, expected_data;
    wire tx;

    reg [7:0] send_mem[0:N-1];  // 보낸 글자
    reg [7:0] recv_mem[0:N-1];  // 돌아온 글자
    integer recv_cnt;  // 돌아온 글자 수
    integer m, k, margin, match_cnt, err;

    uart_fifo_loopback dut (
        .clk(clk),
        .rst(rst),
        .rx (rx),
        .tx (tx)
    );

    always #5 clk = ~clk;

    // stop bit 를 1 로 올리고 바로 나온다 (얼마나 쉴지는 부르는 쪽이 rx_done 기준으로 정함)
    task sender_uart(input [7:0] send_data);
        integer i;
        begin
            rx = 0;  // start bit
            #(BAUD_BIT_PERIOD);
            for (i = 0; i < 8; i = i + 1) begin
                rx = send_data[i];
                #(BAUD_BIT_PERIOD);
            end
            rx = 1;  // stop bit (여기서 바로 나옴)
        end
    endtask

    task receive_uart(output [7:0] rx_data);
        integer i;
        begin
            wait (~tx);
            #(BAUD_BIT_PERIOD / 2);
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

    // initial 1 : 받는 쪽 (PC 수신) — 돌아오는 글자를 계속 받아 차례로 저장
    initial begin
        recv_cnt = 0;
        #20;
        forever begin
            receive_uart(result_data);
            if (recv_cnt < N) recv_mem[recv_cnt] = result_data;
            recv_cnt = recv_cnt + 1;
        end
    end

    // initial 2 : 보내는 쪽 (PC 송신)
    initial begin
        clk = 0;
        rst = 1;
        rx = 1;
        err = 0;
        expected_data = 8'h00;
        result_data = 8'h00;

        #10 rst = 0;
        #1000;

        for (m = 0; m < 4; m = m + 1) begin
            case (m)
                0: margin = 0;
                1: margin = BAUD_BIT_PERIOD / 4;
                2: margin = BAUD_BIT_PERIOD / 2;
                3: margin = BAUD_BIT_PERIOD;
            endcase
            recv_cnt = 0;
            for (k = 0; k < N; k = k + 1) begin
                expected_data = $random % 256;
                send_mem[k]   = expected_data;
                sender_uart(expected_data);
                @(posedge dut.w_rx_done);           // 보드가 이 글자를 다 받은 순간까지 기다림
                #(margin);  // 마진만큼 쉬고 다음 글자
            end
            #(BAUD_BIT_PERIOD * 15);  // 마지막 글자가 돌아올 때

            // 돌아온 순서대로 보낸 것과 같은지
            match_cnt = 0;
            for (k = 0; k < N; k = k + 1) begin
                if (k < recv_cnt && recv_mem[k] === send_mem[k])
                    match_cnt = match_cnt + 1;
            end
            if (recv_cnt != N || match_cnt != N) err = err + 1;
            $display(
                "MARGIN %0d ns (%0d/100 bit) : SENT = %0d, ECHOED = %0d, IN ORDER MATCH = %0d",
                margin, margin * 100 / BAUD_BIT_PERIOD, N, recv_cnt, match_cnt);
        end

        $display("MARGIN TEST : %0d of 4 margins lost or changed data", err);
        $stop;
    end
endmodule
