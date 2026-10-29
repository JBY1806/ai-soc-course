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
    input clk,
    input reset,
    input run_stop,
    input clear,
    input up_down,
    output [3:0] fnd_com,
    output [7:0] fnd_font
);

    wire [13:0] w_counter;

    counter_datapath U_COUNTER_DATAPATH (
        .clk(clk),
        .reset(reset),
        .run_stop(run_stop),
        .clear(clear),
        .up_down(up_down),
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
    input up_down,
    output [13:0] counter
);

    wire w_tick;

    tick_gen U_TICK_GEN (
        .clk(clk),
        .reset(reset),
        .run_stop(run_stop),
        .clear(clear),
        .o_tick(w_tick)
    );
    tick_counter U_TICK_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick),
        .run_stop(run_stop),
        .clear(clear),
        .up_down(up_down),
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
        if (reset) begin
            counter_reg <= 0;
            tick_reg <= 1'b0;
        end else if (clear) begin
            counter_reg <= 0;
            tick_reg <= 1'b0;
        end else if (run_stop) begin
            counter_reg <= counter_reg + 1;
            //to generate 10hz tick signal
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                tick_reg <= 1'b1;
            end else begin
                tick_reg <= 1'b0;
            end
        end else begin
            counter_reg <= counter_reg;
            tick_reg <= tick_reg;
        end
    end

endmodule


module tick_counter (
    input         clk,
    input         reset,
    input         i_tick,
    input         run_stop,
    input         clear,
    input         up_down,
    output [13:0] counter
);

    reg [13:0] counter_reg;

    assign counter = counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin  //reset
            counter_reg <= 0;
        end else if (clear) begin  //clear
            if (!up_down) begin
                counter_reg <= 9900;
            end else begin
                counter_reg <= 0;
            end
        end else if (run_stop && i_tick) begin  //
            if (!up_down) begin
                counter_reg <= counter_reg + 1;
                if (counter_reg == 10000 - 1) begin
                    counter_reg <= 0;
                end
            end else begin
                counter_reg <= counter_reg - 1;
                if (counter_reg == 0) begin
                    counter_reg <= 10000 - 1;
                end
            end
        end
    end
endmodule






