`timescale 1ns / 1ps

module ram_ip_sv (
    input  logic       clk,
    input  logic [5:0] addr,
    input  logic [7:0] wdata,
    input  logic       we,
    output logic [7:0] rdata
);
    logic [7:0] ram [0:63];

    always_ff @(posedge clk) begin
        if (we) begin
            ram[addr] <= ram[addr];  // bug : 쓰기를 안 함 (원래 wdata)        
        end
    end

    assign rdata = ram[addr];
endmodule

