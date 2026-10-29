`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/11 23:44:26
// Design Name: 
// Module Name: counter_control_fsm
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


module counter_control_fsm (
    input clk,
    input reset,
    input [1:0] sw,
    output reg run_stop,
    output reg clear
);

    parameter STOP = 2'b00, RUN = 2'b01, CLEAR = 2'b10;

    reg [1:0] c_state, n_state;

    // state register : SL
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            c_state <= STOP;
        end else begin
            c_state <= n_state;
        end
    end

    // next CL
    always @(*) begin
        n_state = c_state;
        case (c_state)
            STOP:
            if (sw[0] == 1'b1) begin
                n_state = RUN;
            end else if (sw[0] == 1'b0 && sw[1] == 1'b1) begin
                n_state = CLEAR;
            end

            RUN:
            if (sw[0] == 1'b0) begin
                n_state = STOP;
            end

            CLEAR:
            if (sw[1] == 1'b0) begin
                n_state = STOP;
            end
        endcase
    end

    // output CL
    always @(*) begin
        run_stop = 1'b0;
        clear = 1'b0;
        case (c_state)
            STOP: begin
                run_stop = 1'b0;
                clear = 1'b0;
            end

            RUN: begin
                run_stop = 1'b1;
                clear = 1'b0;
            end

            CLEAR: begin
                run_stop = 1'b0;
                clear = 1'b1;
            end
        endcase
    end

endmodule
