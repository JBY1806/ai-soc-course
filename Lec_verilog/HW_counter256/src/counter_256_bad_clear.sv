// 시험용 고장 DUT : clear 를 무시 (검증 TB 가 잡는지 확인용, 원본은 counter_256.sv)
`timescale 1ns / 1ps

module counter_256 (
    input  logic       clk,
    input  logic       rst,
    input  logic       mode,
    input  logic       run_stop,
    input  logic       clear,
    output logic [7:0] counter
);

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin  // 시험용 고장 : clear 를 무시
            counter <= 0;
        end else begin
            if (run_stop) begin
                if (mode) begin
                    counter <= counter - 1;
                end else begin
                    counter <= counter + 1;
                end
            end
        end
    end
endmodule

