`timescale 1ns / 1ps

module tb_counter_10000 ();

    parameter BD_PUSH_TIME = 1000;

    reg clk, reset, btnU, btnL, btnR;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;

    counter_10000 dut (
        .clk(clk),
        .reset(reset),
        .btnU(btnU),     //mode
        .btnL(btnL),     //clear
        .btnR(btnR),     //run_stop
        .fnd_com(fnd_com),
        .fnd_font(fnd_font)
    );

    // gen 100MHz clock
    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        reset = 1;
        btnU = 0;
        btnL = 0;
        btnR = 0;
        #10;
        reset = 0;

        // senario 0 : runstop btn 1 push / pop
        btnR = 1;
        repeat(BD_PUSH_TIME) @(posedge clk); // 10클럭 준 이유: 플립플롭 8개니까 안전하게 10 클럭. 
        btnR = 0;

        // run state
        repeat (3) begin
            #(10_000_000 * 10);
        end

        // run to stop state
        btnR = 1;
        repeat(BD_PUSH_TIME) @(posedge clk); // 1000사이클 준 이유? 
        btnR = 0;


        $stop;
    end

endmodule
