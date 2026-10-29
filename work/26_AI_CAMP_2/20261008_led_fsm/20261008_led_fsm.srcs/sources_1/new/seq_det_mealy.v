
`timescale 1ns / 1ps

module seq_det_mealy (
    input clk,
    input rst,
    input din_bit,
    output reg dout_bit
);
    reg [2:0] c_state, n_state;

    // 상태 선언
    parameter start = 3'b000;
    parameter rd0_once = 3'b001;
    parameter rd1_once = 3'b010;
    parameter rd0_twice = 3'b011;
    parameter rd1_twice = 3'b100;

    // 상태 업데이트
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            c_state <= start;
        end else begin
            c_state <= n_state;
        end
    end

    // 다음 상태 & 출력 로직 
    always @(*) begin
        n_state  = c_state;
        dout_bit = 0;
        case (c_state)
            start:
            if (din_bit == 0) begin
                dout_bit = 0;
                n_state  = rd0_once;
            end else if (din_bit == 1) begin
                dout_bit = 0;
                n_state  = rd1_once;
            end

            rd0_once:
            if (din_bit == 0) begin
                dout_bit = 1;
                n_state  = rd0_twice;
            end else if (din_bit == 1) begin
                dout_bit = 0;
                n_state  = rd1_once;
            end

            rd1_once:
            if (din_bit == 0) begin
                dout_bit = 0;
                n_state  = rd0_once;
            end else if (din_bit == 1) begin
                dout_bit = 1;
                n_state  = rd1_twice;
            end

            rd0_twice:
            if (din_bit == 0) begin
                dout_bit = 1;
                n_state  = rd0_twice;
            end else if (din_bit == 1) begin
                dout_bit = 0;
                n_state  = rd1_once;
            end

            rd1_twice:
            if (din_bit == 0) begin
                dout_bit = 0;
                n_state  = rd0_once;
            end else if (din_bit == 1) begin
                dout_bit = 1;
                n_state  = rd1_twice;
            end
        endcase
    end




endmodule



/*
`timescale 1ns / 1ps

module seq_det_mealy (
    input clk,
    input rst,
    input din_bit,
    output dout_bit
);
    reg [2:0] c_state, n_state;

    // 상태 선언
    parameter start = 3'b000;
    parameter rd0_once = 3'b001;
    parameter rd1_once = 3'b010;
    parameter rd0_twice = 3'b011;
    parameter rd1_twice = 3'b100;

    // 상태 업데이트
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            c_state <= start;
        end else begin
            c_state <= n_state;
        end
    end

    // 다음 상태 & 출력 로직 
    always @(*) begin
        n_state  = start;
        case (c_state)
            start:
            if (din_bit == 0) begin
                n_state  = rd0_once;
            end else if (din_bit == 1) begin
                n_state  = rd1_once;
            end 

            rd0_once:
            if (din_bit == 0) begin
                n_state  = rd0_twice;
            end else if (din_bit == 1) begin
                n_state  = rd1_once;
            end

            rd1_once:
            if (din_bit == 0) begin
                n_state  = rd0_once;
            end else if (din_bit == 1) begin
                n_state  = rd1_twice;
            end

            rd0_twice:
            if (din_bit == 0) begin
                n_state  = rd0_twice;
            end else if (din_bit == 1) begin
                n_state  = rd1_once;
            end

            rd1_twice:
            if (din_bit == 0) begin
                n_state  = rd0_once;
            end else if (din_bit == 1) begin
                n_state  = rd1_twice;
            end
        endcase
    end

    //출력 로직
    //assign dout_bit = ((c_state == rd0_twice) && (din_bit==0) || (c_state == rd1_twice) && (din_bit==1)) ? 1: 0;

    assign dout_bit = ((c_state == rd0_twice)|| (c_state == rd1_twice))  ? 1: 0;



endmodule
*/