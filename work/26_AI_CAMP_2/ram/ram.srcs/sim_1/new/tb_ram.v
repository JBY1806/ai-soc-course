`timescale 1ns / 1ps

module tb_ram ();

    reg clk, we;
    reg [7:0] addr, wdata;
    wire [7:0] rdata;

    bram_ip dut (
        .clk(clk),
        .we(we),
        .addr(addr),
        .wdata(wdata),
        .rdata(rdata)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        we = 0;
        addr = 0;
        wdata = 0;

        //write to ram
        @(negedge clk);
        we = 1;
        addr = 10;
        wdata = 8'h0a;

        @(negedge clk);
        addr  = 11;
        wdata = 8'h0b;
        @(negedge clk);
        addr  = 31;
        wdata = 8'h0c;
        @(negedge clk);
        addr  = 32;
        wdata = 8'h0d;

        //read from ram
        @(negedge clk);
        we = 0;

        @(negedge clk);
        addr = 10;

        @(negedge clk);
        addr = 11;
        @(negedge clk);
        addr = 31;

        @(negedge clk);
        addr = 32;

        @(negedge clk);
        $stop;
    end
endmodule
