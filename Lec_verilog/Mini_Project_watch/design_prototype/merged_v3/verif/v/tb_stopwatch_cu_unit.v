`timescale 1ns / 1ps
// [검증 TB] 팀 stopwatch_control_unit — 수업(9일차 판서) FSM 기준으로 검사
// 수업 기준: STOP 에서 R -> RUN, L -> CLEAR(1클럭) -> STOP, U -> MODE 토글 -> STOP. RUN 에서는 R 만 받음.
// 팀 판이 다르게 동작하면 DEVIATION 으로 센다(의도 확인 필요), 자기 모순은 MISMATCH.
module tb_stopwatch_cu_unit ();
    reg clk, reset, bR, bL, bU;
    wire run_stop, clear, mode;
    stopwatch_control_unit dut (.clk(clk), .reset(reset), .btn_run_stop(bR), .btn_clear(bL), .btn_mode(bU),
                                .run_stop(run_stop), .clear(clear), .mode(mode));
    always #5 clk = ~clk;
    integer err, dev;

    initial begin
        clk = 0; reset = 1; bR = 0; bL = 0; bU = 0; err = 0; dev = 0;
        #22 reset = 0;
        if (run_stop !== 0 || mode !== 0 || clear !== 0) begin err = err + 1; $display("FAIL reset outputs"); end

        // STOP: R -> RUN (다음 클럭부터 run_stop = 1, 누른 클럭에는 아직 0 = 무어)
        @(negedge clk); bR = 1; #1;
        if (run_stop !== 0) begin err = err + 1; $display("FAIL run_stop mealy-like at press clock"); end
        @(negedge clk); bR = 0; #1;
        if (run_stop !== 1) begin err = err + 1; $display("FAIL STOP->RUN"); end

        // RUN: R -> STOP
        @(negedge clk); bR = 1; @(negedge clk); bR = 0; #1;
        if (run_stop !== 0) begin err = err + 1; $display("FAIL RUN->STOP"); end

        // STOP: L -> clear 1클럭, 상태 STOP 유지
        @(negedge clk); bL = 1; #1;
        if (clear !== 1) begin err = err + 1; $display("FAIL clear not 1 with L in STOP"); end
        @(negedge clk); bL = 0; #1;
        if (clear !== 0 || run_stop !== 0) begin err = err + 1; $display("FAIL clear not 1 clk / state moved"); end

        // STOP: U -> mode 토글 (한 번 누르면 정확히 한 번)
        @(negedge clk); bU = 1; @(negedge clk); bU = 0; #1;
        if (mode !== 1) begin err = err + 1; $display("FAIL mode toggle 0->1"); end
        @(negedge clk); bU = 1; @(negedge clk); bU = 0; #1;
        if (mode !== 0) begin err = err + 1; $display("FAIL mode toggle 1->0"); end

        // STOP: R + L 같은 클럭 -> 수업: R 우선(RUN), clear 안 남
        @(negedge clk); bR = 1; bL = 1; #1;
        if (clear !== 0) begin dev = dev + 1; $display("DEVIATION R+L same clock in STOP: clear=1 (class FSM: R first, no clear)"); end
        @(negedge clk); bR = 0; bL = 0; #1;
        if (run_stop !== 1) begin err = err + 1; $display("FAIL R+L -> not RUN"); end

        // RUN: L -> 수업 기준 무시. 팀 판?
        @(negedge clk); bL = 1; #1;
        if (clear !== 0) begin dev = dev + 1; $display("DEVIATION L in RUN gives clear=1 (class FSM: ignored in RUN)"); end
        @(negedge clk); bL = 0; #1;
        if (run_stop !== 1) begin err = err + 1; $display("FAIL L in RUN changed state"); end

        // RUN: U -> 수업 기준 무시. 팀 판?
        @(negedge clk); bU = 1; @(negedge clk); bU = 0; #1;
        if (mode !== 0) begin dev = dev + 1; $display("DEVIATION U in RUN toggles mode (class FSM: ignored in RUN)"); end
        if (run_stop !== 1) begin err = err + 1; $display("FAIL U in RUN changed state"); end
        // 되돌리기 (팀 판이면 mode 가 1 이 되어 있음)
        if (mode === 1) begin @(negedge clk); bU = 1; @(negedge clk); bU = 0; #1; end

        // RUN: R + U 같은 클럭 -> STOP 으로, mode 는?
        @(negedge clk); bR = 1; bU = 1; @(negedge clk); bR = 0; bU = 0; #1;
        if (run_stop !== 0) begin err = err + 1; $display("FAIL R+U in RUN -> not STOP"); end
        if (mode !== 0) begin dev = dev + 1; $display("DEVIATION R+U same clock in RUN toggled mode"); @(negedge clk); bU = 1; @(negedge clk); bU = 0; #1; end

        // 연속 R 두 클럭(디바운서가 1클럭 펄스를 보장하지만 혹시 2클럭이면) -> 두 번 토글 = 제자리
        @(negedge clk); bR = 1; @(negedge clk); @(negedge clk); bR = 0; #1;
        if (run_stop !== 0) $display("info: 2-clk wide R pulse toggles twice (state back to STOP) - debouncer must give 1-clk pulse");

        // reset 중 버튼 -> 무시, 리셋 해제 후 STOP · mode 0
        @(negedge clk); bR = 1; bU = 1; reset = 1; @(negedge clk); @(negedge clk); reset = 0; bR = 0; bU = 0; #1;
        if (run_stop !== 0 || mode !== 0) begin err = err + 1; $display("FAIL after reset with buttons held"); end

        $display("TOTAL MISMATCH = %0d, DEVIATION = %0d", err, dev);
        $finish;
    end
endmodule
