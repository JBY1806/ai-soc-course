`timescale 1ns / 1ps
// [검증 TB] lap_controller (이종혁) — 얼리기 · 풀기 · clear · 동시 입력 · reset
module tb_lap_unit ();
    reg clk, rst, clear, btn_lap;
    reg [6:0] msec; reg [5:0] sec, min; reg [4:0] hour;
    wire [6:0] d_msec; wire [5:0] d_sec, d_min; wire [4:0] d_hour; wire lap_active;
    lap_controller dut (.clk(clk), .rst(rst), .clear(clear), .btn_lap(btn_lap),
        .msec(msec), .sec(sec), .min(min), .hour(hour),
        .disp_msec(d_msec), .disp_sec(d_sec), .disp_min(d_min), .disp_hour(d_hour), .lap_active(lap_active));
    always #5 clk = ~clk;
    integer err, i;
    reg [6:0] m_saved;

    // 입력 시간은 클럭마다 1 씩 올라가게 (스톱워치처럼)
    always @(posedge clk) if (!rst) msec <= (msec == 99) ? 0 : msec + 1;

    initial begin
        clk = 0; rst = 1; clear = 0; btn_lap = 0; msec = 0; sec = 5; min = 6; hour = 7; err = 0;
        #22 rst = 0;
        // 평소: 입력 그대로 통과
        repeat (3) @(negedge clk);
        if (d_msec !== msec || d_sec !== 5 || d_min !== 6 || d_hour !== 7 || lap_active !== 0) begin err = err + 1; $display("FAIL passthrough"); end

        // LAP: 누른 클럭의 입력값(엣지 전 값)이 저장되고 화면은 그 값에 고정
        @(negedge clk); m_saved = msec; btn_lap = 1;
        @(negedge clk); btn_lap = 0;
        if (lap_active !== 1) begin err = err + 1; $display("FAIL lap_active"); end
        if (d_msec !== m_saved) begin err = err + 1; $display("FAIL saved value %0d expect %0d", d_msec, m_saved); end
        repeat (10) @(negedge clk);
        if (d_msec !== m_saved) begin err = err + 1; $display("FAIL frozen value drifted %0d", d_msec); end
        if (msec == m_saved) begin err = err + 1; $display("FAIL input did not advance?"); end

        // LAP 다시 -> 실시간으로 복귀
        @(negedge clk); btn_lap = 1; @(negedge clk); btn_lap = 0;
        if (lap_active !== 0 || d_msec !== msec) begin err = err + 1; $display("FAIL unfreeze"); end

        // LAP 중 clear -> 풀리고 0 (입력은 TB 가 계속 올리므로 화면은 입력 그대로)
        @(negedge clk); btn_lap = 1; @(negedge clk); btn_lap = 0;
        @(negedge clk); clear = 1; @(negedge clk); clear = 0;
        if (lap_active !== 0) begin err = err + 1; $display("FAIL clear did not release lap"); end
        if (dut.save_msec !== 0) begin err = err + 1; $display("FAIL clear did not zero saved"); end

        // btn_lap 과 clear 같은 클럭 -> clear 우선 (lap 안 켜짐)
        @(negedge clk); btn_lap = 1; clear = 1; @(negedge clk); btn_lap = 0; clear = 0;
        if (lap_active !== 0) begin err = err + 1; $display("FAIL clear+lap same clock -> lap on"); end

        // 2클럭 폭 펄스면 두 번 토글(제자리) -> 디바운서 1클럭 보장 필요 (정보)
        @(negedge clk); btn_lap = 1; @(negedge clk); @(negedge clk); btn_lap = 0;
        if (lap_active !== 0) $display("info: 2-clk pulse -> toggled twice");

        // LAP 중 reset -> 풀림
        @(negedge clk); btn_lap = 1; @(negedge clk); btn_lap = 0;
        if (lap_active !== 1) begin err = err + 1; $display("FAIL lap on before reset"); end
        rst = 1; #3; rst = 0; #1;
        if (lap_active !== 0 || dut.save_msec !== 0) begin err = err + 1; $display("FAIL reset in lap"); end

        $display("TOTAL MISMATCH = %0d", err);
        $finish;
    end
endmodule
