`timescale 1ns / 1ps
/*
module blk;

    reg clk, a, b;

    initial begin
        a = 0;
        b=1;
        clk=0;
    end

    always clk = #5 ~clk;

    always @(posedge clk ) begin
        a = b;
        b = a;
    end
endmodule
*/

/*
module non_blk;

    reg clk, a, b;

    initial begin
        a = 0;
        b=1;
        clk=0;
    end

    always clk = #5 ~clk;

    always @(posedge clk ) begin
        a <= b;
        b <= a;
    end
endmodule
*/

module mulptiple_nblk ();
reg a;

initial begin
    a= 1'b1;
end

initial begin
    a<=#5 1'b1;
    a<=#5 1'b0;
    #20 $stop;
end
    
endmodule
