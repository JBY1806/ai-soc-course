`timescale 1ns / 1ps

module bram_ip (
    input        clk,
    input        we,
    input  [7:0] addr,
    input  [7:0] wdata,
    output [7:0] rdata
);

    reg [7:0] ram[0:255];

    always @(posedge clk) begin
        // write
        if (we) ram[addr] <= wdata;
        // SL read
        //else rdata <= ram[addr];
    end

    // CL output
    assign rdata = ram[addr];

endmodule
