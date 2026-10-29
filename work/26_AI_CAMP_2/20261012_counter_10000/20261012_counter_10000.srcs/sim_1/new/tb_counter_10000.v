`timescale 1ns / 1ps

module tb_counter_10000();

    reg clk, reset;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;

counter_10000 dut(
    .clk(clk),
    .reset(reset),
    .fnd_com(fnd_com),
    .fnd_font(fnd_font)
);


// gen 100MHz clock
always #5 clk = ~clk;

initial begin
    clk = 0;
    reset = 1;
    #10;
    reset = 0;

    repeat(3) begin
        #(10_000_000*10);
    end

    $stop;    
end 

endmodule
