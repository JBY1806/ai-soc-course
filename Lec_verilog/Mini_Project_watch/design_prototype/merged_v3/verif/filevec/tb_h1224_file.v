`timescale 1ns / 1ps
// [작성] 단계 1: hour_12_24 — 입력 파일 읽고, 정답 파일과 비교 (조합회로라 #1 뒤 비교)
module tb_h1224_file ();
    reg  [5:0] vin  [0:63];   // {sw_12h, hour[4:0]}
    reg  [5:0] vexp [0:63];   // {pm, o_hour[4:0]}
    reg        sw_12h;
    reg  [4:0] i_hour;
    wire [4:0] o_hour;
    wire       pm;
    integer i, err;

    hour_12_24 #(.HOUR_BIT_WIDTH(5)) dut (.sw_12h(sw_12h), .i_hour(i_hour), .o_hour(o_hour), .pm(pm));

    initial begin
        $readmemh("in_h1224.hex", vin);
        $readmemh("exp_h1224.hex", vexp);
        err = 0;
        for (i = 0; i < 64; i = i + 1) begin
            {sw_12h, i_hour} = vin[i];
            #1;
            if ({pm, o_hour} !== vexp[i]) begin
                err = err + 1;
                $display("FAIL line %0d: in sw=%b hour=%0d -> got pm=%b hour=%0d, exp pm=%b hour=%0d",
                         i + 1, sw_12h, i_hour, pm, o_hour, vexp[i][5], vexp[i][4:0]);
            end
        end
        $display("TOTAL MISMATCH = %0d (64 vectors)", err);
        $finish;
    end
endmodule
