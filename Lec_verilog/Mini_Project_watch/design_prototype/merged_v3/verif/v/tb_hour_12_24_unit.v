`timescale 1ns / 1ps
// [검증 TB] hour_12_24 — 0~23 x sw 전수 검사 (조합회로)
module tb_hour_12_24_unit ();
    reg sw_12h; reg [4:0] i_hour; wire [4:0] o_hour; wire pm;
    hour_12_24 dut (.sw_12h(sw_12h), .i_hour(i_hour), .o_hour(o_hour), .pm(pm));
    integer err, h, exp_h, exp_pm;
    initial begin
        err = 0;
        for (h = 0; h < 24; h = h + 1) begin
            exp_pm = (h >= 12) ? 1 : 0;
            sw_12h = 0; i_hour = h; #1;
            if (o_hour !== h || pm !== exp_pm) begin err = err + 1; $display("FAIL 24h h=%0d -> %0d pm %b", h, o_hour, pm); end
            sw_12h = 1; #1;
            exp_h = (h == 0) ? 12 : (h > 12) ? h - 12 : h;
            if (o_hour !== exp_h || pm !== exp_pm) begin err = err + 1; $display("FAIL 12h h=%0d -> %0d (exp %0d) pm %b", h, o_hour, exp_h, pm); end
        end
        // 24~31 (스톱워치 hour 는 0~23 뿐이지만 5비트 범위 밖 값에서 X 나 엉뚱한 값 안 나는지)
        for (h = 24; h < 32; h = h + 1) begin
            sw_12h = 1; i_hour = h; #1;
            if (^o_hour === 1'bx) begin err = err + 1; $display("FAIL X at h=%0d", h); end
        end
        $display("TOTAL MISMATCH = %0d  (48 cases + 8 out-of-range)", err);
        $finish;
    end
endmodule
