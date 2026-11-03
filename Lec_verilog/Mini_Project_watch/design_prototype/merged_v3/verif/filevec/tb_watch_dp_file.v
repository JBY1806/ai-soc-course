`timescale 1ns / 1ps
// [작성] 단계 3: watch_datapath — 입력 파일의 cursor · up · down 은 단계 2 의 "정답 출력"
// 클럭마다 입력 한 줄을 넣고, 그 클럭 상승 에지 뒤 시각을 정답 한 줄과 비교
module tb_watch_dp_file ();
    parameter N = 40000;
    reg  [4:0]  vin  [0:N-1];  // {tick, cursor[1:0], up, down}
    reg  [23:0] vexp [0:N-1];  // {hour[4:0], min[5:0], sec[5:0], msec[6:0]}
    reg  clk, rst, tick, i_up, i_down;
    reg  [1:0] cursor;
    wire [6:0] msec; wire [5:0] sec, min; wire [4:0] hour;
    integer i, n, err;

    watch_datapath dut (.clk(clk), .rst(rst), .i_tick_10ms(tick), .cursor(cursor), .i_up(i_up), .i_down(i_down),
        .msec(msec), .sec(sec), .min(min), .hour(hour));

    always #5 clk = ~clk;

    initial begin
        for (i = 0; i < N; i = i + 1) vin[i] = 5'bx;
        $readmemh("in_dp.hex", vin);
        $readmemh("exp_dp.hex", vexp);
        n = 0; while (n < N && vin[n] !== 5'bx) n = n + 1;
        clk = 0; rst = 1; err = 0;
        {tick, cursor, i_up, i_down} = 0;
        #22 rst = 0;
        for (i = 0; i < n; i = i + 1) begin
            @(negedge clk);
            {tick, cursor, i_up, i_down} = vin[i];
            @(posedge clk); #1;
            if ({hour, min, sec, msec} !== vexp[i]) begin
                err = err + 1;
                if (err <= 10) $display("FAIL line %0d: got %0d:%0d:%0d.%0d exp %0d:%0d:%0d.%0d", i + 1,
                    hour, min, sec, msec, vexp[i][23:19], vexp[i][18:13], vexp[i][12:7], vexp[i][6:0]);
            end
        end
        $display("TOTAL MISMATCH = %0d (%0d clocks), last %0d:%0d:%0d.%0d", err, n, hour, min, sec, msec);
        $finish;
    end
endmodule
