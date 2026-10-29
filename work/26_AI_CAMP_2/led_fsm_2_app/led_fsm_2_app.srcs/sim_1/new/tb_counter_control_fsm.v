`timescale 1ns / 1ps
// [자동 방식] 같은 시나리오를 표(배열)로 적고 for 문이 넣고 + 검사까지 한다.
//  - 단계마다 기대 상태와 실제 상태를 비교, 틀리면 Tcl Console 에 FAIL 한 줄.
//  - 끝에 TOTAL 14, MISMATCH = 0 이 나오면 전부 맞은 것.
//  - 파형은 수동 방식과 같은 모양 (단계가 0 ns 부터 30 ns 간격이라 시각만 조금 다름).

module tb_counter_control_fsm_auto;
    reg clk, reset;
    reg [1:0] sw;
    wire run_stop, clear;

    // 시나리오 표: 단계별 reset · sw · 기대 상태 (0 = STOP, 1 = RUN, 2 = CLEAR)
    reg       rst_seq[0:13];
    reg [1:0] sw_seq [0:13];
    reg [1:0] exp_st [0:13];
    integer i, err;

    counter_control_fsm dut (
        .clk(clk),
        .reset(reset),
        .sw(sw),
        .run_stop(run_stop),
        .clear(clear)
    );

    always #5 clk = ~clk;

    initial begin
        // ---- 표 채우기 (배열은 한 번에 초기화가 안 돼서 한 칸씩) ----
        rst_seq[0]  = 1; sw_seq[0]  = 2'b00; exp_st[0]  = 0;  //  1 리셋 -> STOP
        rst_seq[1]  = 0; sw_seq[1]  = 2'b00; exp_st[1]  = 0;  //  2 리셋 해제, STOP 유지
        rst_seq[2]  = 0; sw_seq[2]  = 2'b10; exp_st[2]  = 2;  //  3 STOP -> CLEAR
        rst_seq[3]  = 0; sw_seq[3]  = 2'b11; exp_st[3]  = 2;  //  4 CLEAR 유지 (sw[0] 무시)
        rst_seq[4]  = 0; sw_seq[4]  = 2'b01; exp_st[4]  = 1;  //  5 CLEAR -> STOP -> RUN
        rst_seq[5]  = 0; sw_seq[5]  = 2'b00; exp_st[5]  = 0;  //  6 RUN -> STOP
        rst_seq[6]  = 0; sw_seq[6]  = 2'b11; exp_st[6]  = 1;  //  7 STOP -> RUN (sw[0] 우선)
        rst_seq[7]  = 0; sw_seq[7]  = 2'b10; exp_st[7]  = 2;  //  8 RUN -> STOP -> CLEAR
        rst_seq[8]  = 0; sw_seq[8]  = 2'b00; exp_st[8]  = 0;  //  9 CLEAR -> STOP
        rst_seq[9]  = 0; sw_seq[9]  = 2'b01; exp_st[9]  = 1;  // 10 STOP -> RUN
        rst_seq[10] = 0; sw_seq[10] = 2'b11; exp_st[10] = 1;  // 11 RUN 유지 (sw[1] 무시)
        rst_seq[11] = 1; sw_seq[11] = 2'b11; exp_st[11] = 0;  // 12 동작 중 리셋 -> STOP
        rst_seq[12] = 0; sw_seq[12] = 2'b11; exp_st[12] = 1;  // 13 리셋 해제 -> RUN
        rst_seq[13] = 0; sw_seq[13] = 2'b00; exp_st[13] = 0;  // 14 RUN -> STOP

        clk = 1'b0;
        err = 0;

        // ---- 표대로 넣고 검사 ----
        for (i = 0; i < 14; i = i + 1) begin
            reset = rst_seq[i];
            sw    = sw_seq[i];
            #25;  // 클럭 상승 2번 (+5, +15) 이 지난 뒤 검사
            // 무어형이라 출력은 상태로 정해짐: RUN 이면 run_stop = 1, CLEAR 이면 clear = 1
            if ({dut.c_state, run_stop, clear} !== {exp_st[i], exp_st[i] == 1, exp_st[i] == 2}) begin
                err = err + 1;
                $display("FAIL step %0d t=%0d: state=%0d run_stop=%b clear=%b (expect state %0d)",
                         i + 1, $time, dut.c_state, run_stop, clear, exp_st[i]);
            end
            #5;
        end

        $display("TOTAL 14, MISMATCH = %0d", err);
        $stop;  // 420 ns
    end
endmodule
