`timescale 1ns / 1ps

module mealy_0101_detector (
    input clk,
    input reset,
    input din_bit,
    output reg o_detected
);

    reg [1:0] c_state, n_state;

    // 상태 선언
    parameter S0 = 2'b00;
    parameter S1 = 2'b01;
    parameter S2 = 2'b10;
    parameter S3 = 2'b11;

    // 상태 업데이트
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= S0;
        end else begin
            c_state <= n_state;
        end
    end

    // 다음 상태 & 출력 로직
    always @(*) begin
        n_state = S0;
        o_detected = 1'b0;
        case (c_state)
            S0: if (din_bit == 0) begin
                o_detected = 0;
                n_state = S1;
            end else if (din_bit == 1) begin
                o_detected = 0;
                n_state = S0;
            end

            S1: if (din_bit == 1) begin
                o_detected = 0;
                n_state = S2;
            end else if (din_bit == 0) begin
                o_detected = 0;
                n_state = S1;
            end

            S2: if (din_bit == 0) begin
                o_detected = 0;
                n_state = S3;
            end else if (din_bit == 1) begin
                o_detected = 0;
                n_state = S0;
            end

            S3: if (din_bit == 1) begin
                o_detected = 1;
                n_state = S0;
            end else if (din_bit == 0) begin
                o_detected = 0;
                n_state = S1;
            end
        endcase
    end
    

endmodule
