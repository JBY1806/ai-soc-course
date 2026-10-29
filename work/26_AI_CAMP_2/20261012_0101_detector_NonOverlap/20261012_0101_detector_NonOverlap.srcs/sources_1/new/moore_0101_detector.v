`timescale 1ns / 1ps

module moore_0101_detector (
    input clk,
    input reset,
    input din_bit,
    output reg o_detected
);

    reg [2:0] c_state, n_state;

    // 상태 선언
    parameter S0 = 3'b000;
    parameter S1 = 3'b001;
    parameter S2 = 3'b010;
    parameter S3 = 3'b011;
    parameter S4 = 3'b100;

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
            S0: begin
                o_detected = 0;
                if (din_bit == 0) begin
                    n_state = S1;
                end else if (din_bit == 1) begin
                    n_state = S0;
                end
            end


            S1: begin
                o_detected = 0;
                if (din_bit == 1) begin
                    n_state = S2;
                end else if (din_bit == 0) begin
                    n_state = S1;
                end
            end


            S2: begin
                o_detected = 0;
                if (din_bit == 0) begin
                    n_state = S3;
                end else if (din_bit == 1) begin
                    n_state = S0;
                end
            end



            S3: begin
                o_detected = 0;
                if (din_bit == 1) begin
                    n_state = S4;
                end else if (din_bit == 0) begin
                    n_state = S1;
                end
            end

            S4: begin
                o_detected = 1;
                if (din_bit == 1) begin
                    n_state = S0;
                end else if (din_bit == 0) begin
                    n_state = S1;
                end
            end

        endcase
    end


endmodule
