`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/07 12:43:10
// Design Name: 
// Module Name: counter_10000
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


module counter_10000 (
    input        clk,
    input        reset,
    input        btnU,     //mode
    input        btnL,     //clear
    input        btnR,     //run_stop
    output [3:0] fnd_com,
    output [7:0] fnd_font
);

    wire [13:0] w_counter;
    wire w_run_stop, w_clear, w_mode;
    wire w_btn_run_stop, w_btn_clear, w_btn_mode;

    btn_debounce U_BD_RUNSTOP (
        .clk  (clk),
        .reset(reset),
        .i_btn(btnR),
        .o_btn(w_btn_run_stop)
    );

    btn_debounce U_BD_CLEAR (
        .clk  (clk),
        .reset(reset),
        .i_btn(btnL),
        .o_btn(w_btn_clear)
    );

    btn_debounce U_BD_MODE (
        .clk  (clk),
        .reset(reset),
        .i_btn(btnU),
        .o_btn(w_btn_mode)
    );

    control_unit U_CONTROL_UNIT (
        .clk         (clk),
        .reset       (reset),
        .btn_run_stop(w_btn_run_stop),  // run_stop
        .btn_clear   (w_btn_clear),     //clear
        .btn_mode    (w_btn_mode),      //mode        
        .run_stop    (w_run_stop),
        .clear       (w_clear),
        .mode        (w_mode)
    );

    counter_datapath U_COUNTER_DATAPATH (
        .clk(clk),
        .reset(reset),
        .run_stop(w_run_stop),
        .clear(w_clear),
        .mode(w_mode),
        .counter(w_counter)
    );

    fnd_controller U_FND_CNTL (
        .clk(clk),
        .reset(reset),
        .fnd_data(w_counter),  // 9bit {c, s}
        .fnd_com(fnd_com),
        .fnd_font(fnd_font)
    );

endmodule



module counter_datapath (
    input clk,
    input reset,
    input run_stop,
    input clear,
    input mode,
    output [13:0] counter
);

    wire w_tick;

    tick_gen U_TICK_GEN (
        .clk     (clk),
        .reset   (reset),
        .run_stop(run_stop),
        .clear   (clear),
        .o_tick  (w_tick)
    );
    tick_counter U_TICK_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick),
        .clear(clear),
        .mode(mode),
        .counter(counter)
    );


endmodule


module tick_gen (
    input  clk,
    input  reset,
    input  run_stop,
    input  clear,
    output o_tick
);
    parameter F_COUNT = 10_000_000;
    reg [$clog2(F_COUNT) - 1:0] counter_reg;
    reg tick_reg;

    assign o_tick = tick_reg;

    always @(posedge clk or posedge reset) begin
        if (reset | clear) begin
            counter_reg <= 0;
            tick_reg <= 1'b0;
        end else begin
            if (run_stop) begin
                counter_reg <= counter_reg + 1;
                //to generate 1hz tick signal
                if (counter_reg == F_COUNT - 1) begin
                    counter_reg <= 0;
                    tick_reg <= 1'b1;
                end else begin
                    tick_reg <= 1'b0;
                end
            end
        end
    end

endmodule


module tick_counter (
    input         clk,
    input         reset,
    input         i_tick,
    input         clear,
    input         mode,
    output [13:0] counter
);

    reg [13:0] counter_reg;

    assign counter = counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset | clear) begin
            counter_reg <= 0;
        end else begin
            if (!mode) begin
                //up count
                if (i_tick) begin
                    counter_reg <= counter_reg + 1;
                    if (counter_reg == 10000 - 1) begin
                        counter_reg <= 0;
                    end
                end
            end else begin
                //down count
                if (i_tick) begin
                    counter_reg <= counter_reg - 1;
                    if (counter_reg == 0) begin
                        counter_reg <= 9999;
                    end
                end
            end
        end
    end

endmodule




