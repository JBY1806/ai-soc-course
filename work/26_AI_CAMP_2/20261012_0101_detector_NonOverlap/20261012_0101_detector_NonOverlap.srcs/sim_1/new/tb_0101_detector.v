`timescale 1ns / 1ps


module tb_0101_detector;

    reg clk, reset, din_bit;
    wire o_mealy, o_moore;

    mealy_0101_detector u_mealy (
        .clk(clk),
        .reset(reset),
        .din_bit(din_bit),
        .o_detected(o_mealy)
    );

    moore_0101_detector u_moore (
        .clk(clk),
        .reset(reset),
        .din_bit(din_bit),
        .o_detected(o_moore)
    );

    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        reset = 1;
        din_bit = 0;
        #10 reset = 0;
        
        // 시나리오 A. 목적: 15번째 비트에서 다시 찾지 않는지(non-overlap)
        #10 din_bit = 0; //20ns
        #10 din_bit = 0;
        #10 din_bit = 1;
        #10 din_bit = 1;
        #10 din_bit = 0;
        #10 din_bit = 1;
        #10 din_bit = 0;
        #10 din_bit = 1;
        #10 din_bit = 1;
        #10 din_bit = 0;
        #10 din_bit = 1;
        #10 din_bit = 0;
        #10 din_bit = 1;
        #10 din_bit = 0;
        #10 din_bit = 1; //160ns

        // 다음 시나리오 시작 전 초기 상태로 리셋
        #10 reset = 1;
        #10 reset = 0;
        // 시나리오 B. 목적:  0101 이 바로 이어 나올 때 두 번 다 찾는지
        #10 din_bit = 0; //190ns
        #10 din_bit = 1;
        #10 din_bit = 0;
        #10 din_bit = 1;
        #10 din_bit = 0;
        #10 din_bit = 1;
        #10 din_bit = 0;
        #10 din_bit = 1; //260ns

        // 다음 시나리오 시작 전 초기 상태로 리셋
        #10 reset = 1;
        #10 reset = 0;
        // 시나리오 C. 목적: 010 다음에 0 이 오면 S3 → S1 로 돌아가는지
        #10 din_bit = 0; //290ns
        #10 din_bit = 1;
        #10 din_bit = 0;
        #10 din_bit = 0;
        #10 din_bit = 1;
        #10 din_bit = 0;
        #10 din_bit = 1; //350ns


        // 다음 시나리오 시작 전 초기 상태로 리셋
        #10 reset = 1;
        #10 reset = 0;
        // 시나리오 D. 목적: 도중에 reset 을 걸면 진행 상황이 지워지는지
        #10 din_bit = 0; //380ns
        #10 din_bit = 1;
        #10 din_bit = 0;
        #10 reset = 1;
        #10 reset = 0;
        #10 din_bit = 1;   // reset 이 지웠으면 0, 안 지웠으면 1
        #20;
        $stop;
    end

endmodule
