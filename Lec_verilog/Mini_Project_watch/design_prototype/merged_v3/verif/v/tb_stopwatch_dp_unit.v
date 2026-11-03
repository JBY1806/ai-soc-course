`timescale 1ns / 1ps
// [검증 TB] stopwatch_datapath (팀 통합판: tick 입력, 랩 포함) — 업/다운 · 돌기 · clear · 랩 · mode 전환
module tb_stopwatch_dp_unit ();
    reg clk, rst, tick, run_stop, clear, mode, btn_lap;
    wire [6:0] msec; wire [5:0] sec, min; wire [4:0] hour; wire lap_active;
    stopwatch_datapath dut (.clk(clk), .rst(rst), .i_tick_10ms(tick), .run_stop(run_stop), .clear(clear), .mode(mode),
        .btn_lap(btn_lap), .msec(msec), .sec(sec), .min(min), .hour(hour), .lap_active(lap_active));
    always #5 clk = ~clk;
    integer err, i; reg [6:0] m_saved;

    initial begin
        clk = 0; rst = 1; tick = 0; run_stop = 0; clear = 0; mode = 0; btn_lap = 0; err = 0;
        #22 rst = 0;
        // run_stop = 0 이면 tick 이 와도 안 셈
        for (i = 0; i < 5; i = i + 1) begin @(negedge clk); tick = 1; @(negedge clk); tick = 0; end
        #1 if (msec !== 0) begin err = err + 1; $display("FAIL counted while stopped"); end
        // run: 100 tick -> 00:01.00 (리플 1클럭)
        run_stop = 1;
        for (i = 0; i < 100; i = i + 1) begin @(negedge clk); tick = 1; @(negedge clk); tick = 0; end
        repeat (2) @(negedge clk);
        if (sec !== 1 || msec !== 0) begin err = err + 1; $display("FAIL 100 ticks %0d.%0d", sec, msec); end
        // down mode: 1.00 -> 0.99 (msec 0 -> 99 + sec 빌림 1클럭 뒤)
        mode = 1;
        @(negedge clk); tick = 1; @(negedge clk); tick = 0; repeat (2) @(negedge clk);
        if (sec !== 0 || msec !== 99) begin err = err + 1; $display("FAIL down borrow %0d.%0d", sec, msec); end
        // down 으로 0 지나면 23:59:59.99 (요구사항대로 '마이너스' 돌기)
        for (i = 0; i < 99; i = i + 1) begin @(negedge clk); tick = 1; @(negedge clk); tick = 0; end
        repeat (2) @(negedge clk);
        if ({hour, min, sec, msec} !== 0) begin err = err + 1; $display("FAIL down to zero %0d:%0d:%0d.%0d", hour, min, sec, msec); end
        @(negedge clk); tick = 1; @(negedge clk); tick = 0; repeat (4) @(negedge clk);
        if ({hour, min, sec, msec} !== {5'd23, 6'd59, 6'd59, 7'd99}) begin err = err + 1; $display("FAIL underflow wrap %0d:%0d:%0d.%0d", hour, min, sec, msec); end
        // mode 를 tick 과 같은 클럭에 바꾸면 그 tick 은 이전 mode 로 센다 (mode 는 레지스터 입력이므로 TB 가 같은 클럭에 바꿈)
        @(negedge clk); tick = 1; mode = 0; @(negedge clk); tick = 0; repeat (4) @(negedge clk);
        // mode=0 이 tick 과 같은 negedge 에 바뀌었으니 다음 posedge 에 up 으로 셈: 99 -> 0, sec 59->0 ... 한 바퀴: 00:00:00.00
        if ({hour, min, sec, msec} !== 0) begin err = err + 1; $display("FAIL mode flip at tick %0d:%0d:%0d.%0d", hour, min, sec, msec); end
        // 랩: 50 tick 뒤 lap, 그 뒤 30 tick 동안 화면 고정, 내부는 흐름, 풀면 80
        for (i = 0; i < 50; i = i + 1) begin @(negedge clk); tick = 1; @(negedge clk); tick = 0; end
        @(negedge clk); m_saved = dut.w_msec; btn_lap = 1; @(negedge clk); btn_lap = 0;
        for (i = 0; i < 30; i = i + 1) begin @(negedge clk); tick = 1; @(negedge clk); tick = 0; end
        #1 if (lap_active !== 1 || msec !== m_saved) begin err = err + 1; $display("FAIL lap frozen %0d (saved %0d)", msec, m_saved); end
        if (dut.w_msec !== 80) begin err = err + 1; $display("FAIL internal kept counting %0d", dut.w_msec); end
        @(negedge clk); btn_lap = 1; @(negedge clk); btn_lap = 0; #1;
        if (lap_active !== 0 || msec !== 80) begin err = err + 1; $display("FAIL unfreeze %0d", msec); end
        // clear: 카운터 · 랩 모두 0, 같은 클럭 tick 은 무시
        @(negedge clk); btn_lap = 1; @(negedge clk); btn_lap = 0;
        @(negedge clk); clear = 1; tick = 1; @(negedge clk); clear = 0; tick = 0; #1;
        if ({hour, min, sec, msec} !== 0 || lap_active !== 0) begin err = err + 1; $display("FAIL clear"); end
        // run_stop 내리기: 멈춘 동안 tick 무시, 다시 올리면 이어서
        for (i = 0; i < 7; i = i + 1) begin @(negedge clk); tick = 1; @(negedge clk); tick = 0; end
        run_stop = 0;
        for (i = 0; i < 7; i = i + 1) begin @(negedge clk); tick = 1; @(negedge clk); tick = 0; end
        #1 if (msec !== 7) begin err = err + 1; $display("FAIL stop %0d", msec); end
        run_stop = 1;
        for (i = 0; i < 3; i = i + 1) begin @(negedge clk); tick = 1; @(negedge clk); tick = 0; end
        #1 if (msec !== 10) begin err = err + 1; $display("FAIL resume %0d", msec); end
        // up 방향 긴 돌기: 23:59:59.99 -> 00:00:00.00 (clear 후 down 1 tick 으로 23:59:59.99 만든 뒤 up)
        @(negedge clk); clear = 1; @(negedge clk); clear = 0; mode = 1;
        @(negedge clk); tick = 1; @(negedge clk); tick = 0; repeat (4) @(negedge clk);
        if ({hour, min, sec, msec} !== {5'd23, 6'd59, 6'd59, 7'd99}) begin err = err + 1; $display("FAIL prep 23:59:59.99"); end
        mode = 0; @(negedge clk); tick = 1; @(negedge clk); tick = 0; repeat (4) @(negedge clk);
        if ({hour, min, sec, msec} !== 0) begin err = err + 1; $display("FAIL up overflow wrap %0d:%0d:%0d.%0d", hour, min, sec, msec); end
        $display("TOTAL MISMATCH = %0d", err);
        $finish;
    end
endmodule
