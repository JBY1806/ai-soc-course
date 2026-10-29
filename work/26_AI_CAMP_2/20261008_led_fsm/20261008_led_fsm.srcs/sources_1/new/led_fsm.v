`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/08 15:07:55
// Design Name: 
// Module Name: led_fsm
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module led_fsm (
    input        clk,
    input        reset,
    input        sw0,
    output [1:0] led
);
    parameter S1 = 1'b0, S2 = 1'b1;

    reg current_state, next_state;

    // state register
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_state <= S1;
        end else begin
            current_state <= next_state;
        end
    end

    // next state Combinational logic
    always @(*) begin
        if (current_state == S1) begin
            if (sw0 == 1'b1) begin
                next_state = S2;
            end else begin
                next_state = current_state;
            end
        end else if (current_state == S2) begin
            if (sw0 == 1'b0) begin
                next_state = S1;
            end else begin
                next_state = current_state;
            end

        end else begin
            next_state = current_state;
        end
    end

    // output Combinational logic
    assign led = (current_state == S1) ? 2'b01 : 2'b10;

endmodule


module led_fsm_1 (
    input clk,
    input reset,
    input [1:0] sw,
    output reg [2:0] led
);

    parameter S0 = 3'b000, S1 = 3'b001, S2 = 3'b010, S3 = 3'b011, S4 = 3'b100;

    reg [2:0] c_state, n_state;

    //// output CL
    //assign led = (c_state == S0) ? 3'b000:
    //            (c_state == S1) ? 3'b001:
    //            (c_state == S2) ? 3'b010:
    //            (c_state == S3) ? 3'b100:
    //            (c_state == S4) ? 3'b111:3'b000;
    always @(*) begin
        led = 3'b000;
        case(c_state)
            S0: led = 3'b000;
            S1: led = 3'b001;
            S2: led = 3'b010;
            S3: led = 3'b100;
            S4: led = 3'b111;
        endcase
    end
    

    // state register : SL
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= S0;
        end else begin
            c_state <= n_state;
        end
    end

    // next CL
    always @(*) begin
        n_state = c_state; // 초기값 설정 -> 래치 방지. 
        case (c_state)
            S0: begin
                if (sw == 2'b01) n_state = S1;
               // else n_state = c_state;
            end

            S1: begin
                if (sw == 2'b10) n_state = S2;
               // else n_state = c_state;
            end

            S2: begin
                if (sw == 2'b11) n_state = S3;
               // else n_state = c_state;
            end

            S3: begin
                if (sw == 2'b10) n_state = S4;
                else if (sw == 2'b00) n_state = S0;
                else if (sw == 2'b01) n_state = S1;
               // else n_state = c_state;
            end

            S4: begin
                if (sw == 2'b00) n_state = S0;
               // else n_state = c_state;
            end

           // default: n_state = c_state;
        endcase
    end



endmodule
