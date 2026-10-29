`timescale 1ns / 1ps

module tb_adder_fnd ();

    reg clk, reset;
    wire o_clk_800hz;

    clk_div_800hz dut (
        .clk        (clk),
        .reset      (reset),
        .o_clk_800hz(o_clk_800hz)
    );

    // generate 100Mhz clock, duty 1:1
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 0;
        #1
        reset = 1;
        #10;
        reset = 0;
        //(250_000 clk  * 10nsec(1clock cycle time))
        #(250_000*10);
        #100;
        $stop;
    end

endmodule
