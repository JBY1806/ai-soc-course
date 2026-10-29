`timescale 1ns / 1ps

module tb_gate_premitive();

    reg a, b;
    wire s, c;

    half_adder DUT(
    .a(a),
    .b(b),
    .s(s),
    .c(c)
    );

    initial begin
        a=0;
        b=0;
        #1;

        a=1;

        #1;
        a=0;
        b=1;

        #1;
        a=1;
        b=1;
        #1;

        $stop;
    end
endmodule
