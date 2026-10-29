/*
`timescale 1ns / 1ps

module control_unit (
    input            clk,
    input            reset,
    input      [2:0] sw,
    output reg       run_stop,
    output reg       clear,
    output           mode
);
    parameter STOP = 2'b00, RUN = 2'b01, CLEAR = 2'b10, MODE = 2'b11;
    reg [1:0] c_state, n_state;

    assign mode = sw[2];

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= STOP;
        end else begin
            c_state <= n_state;
        end
    end

    // next / output CL
    always @(*) begin
        n_state  = c_state;
        run_stop = 1'b0;
        clear    = 1'b0;
        case (c_state)
            STOP: begin
                run_stop = 1'b0;
                clear = 1'b0;
                if (sw[0] == 1'b1) begin
                    n_state = RUN;
                end else if (sw[1] == 1'b1) begin
                    n_state = CLEAR;
                end
            end

            RUN: begin
                run_stop = 1'b1;
                if (sw[0] == 1'b0) begin
                    n_state = STOP;
                end
            end

            CLEAR: begin
                clear = 1'b1;
                if (sw[1] == 0) begin
                    n_state = STOP;
                end
            end
        endcase
    end
endmodule
*/



`timescale 1ns / 1ps

module control_unit (
    input      clk,
    input      reset,
    input      btnR,      // run_stop
    input      btnL,      // clear
    input      sw,        // mode
    output reg run_stop,
    output reg clear,
    output     mode
);
    parameter STOP = 2'b00, RUN = 2'b01, CLEAR = 2'b10, MODE = 2'b11;
    reg [1:0] c_state, n_state;

    assign mode = sw;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= STOP;
        end else begin
            c_state <= n_state;
        end
    end

    // next / output CL
    always @(*) begin
        n_state  = c_state;
        run_stop = 1'b0;
        clear    = 1'b0;
        case (c_state)
            STOP: begin
                run_stop = 1'b0;
                clear = 1'b0;
                if (btnR == 1'b1) begin
                    n_state = RUN;
                end else if (btnL == 1'b1) begin
                    n_state = CLEAR;
                end
            end

            RUN: begin
                run_stop = 1'b1;
                if (btnR == 1'b0) begin
                    n_state = STOP;
                end
            end

            CLEAR: begin
                clear   = 1'b1;
                n_state = STOP; //next posedge clk
            end
        endcase
    end
endmodule
