`timescale 1ns / 1ps
// [작성] 단계 2: watch_control_unit — 매 클럭 입력 한 줄, 그 클럭 출력(조합)을 정답 한 줄과 비교
module tb_watch_cu_file ();
    parameter N = 40000;
    reg  [4:0] vin  [0:N-1];  // {sw_set, L, R, U, D}
    reg  [4:0] vexp [0:N-1];  // {set_mode, cursor[1:0], o_up, o_down}
    reg  clk, rst, sw_set, btn_left, btn_right, btn_up, btn_down;
    wire set_mode, o_up, o_down;
    wire [1:0] cursor;
    integer i, n, err;

    watch_control_unit dut (.clk(clk), .rst(rst), .btn_left(btn_left), .btn_right(btn_right), .btn_up(btn_up),
        .btn_down(btn_down), .sw_set(sw_set), .set_mode(set_mode), .cursor(cursor), .o_up(o_up), .o_down(o_down));

    always #5 clk = ~clk;

    initial begin
        for (i = 0; i < N; i = i + 1) vin[i] = 5'bx;
        $readmemh("in_cu.hex", vin);
        $readmemh("exp_cu.hex", vexp);
        n = 0; while (n < N && vin[n] !== 5'bx) n = n + 1;   // 파일 줄 수
        clk = 0; rst = 1; err = 0;
        {sw_set, btn_left, btn_right, btn_up, btn_down} = 0;
        #22 rst = 0;
        for (i = 0; i < n; i = i + 1) begin
            @(negedge clk);
            {sw_set, btn_left, btn_right, btn_up, btn_down} = vin[i];
            #1;
            if ({set_mode, cursor, o_up, o_down} !== vexp[i]) begin
                err = err + 1;
                if (err <= 10) $display("FAIL line %0d: got %b exp %b", i + 1, {set_mode, cursor, o_up, o_down}, vexp[i]);
            end
        end
        $display("TOTAL MISMATCH = %0d (%0d clocks)", err, n);
        $finish;
    end
endmodule
