`timescale 1ns / 1ps
// [작성] 위상 확인 TB — 타이머 "시작 → 첫 1/100초 감소" 까지 걸린 시간을 3번 잰다
// DUT = Top(stopwatch_watch), 실제 파라미터. 시작(L) 누르는 시각을 3 ms 씩 바꿔 가며 잰다.
//   공유 tick (before · after) : 시작 순간과 상관없이 정해진 박자 → 0 ~ 10 ms 사이로 매번 다름
//   자기 tick_gen (class)       : 시작할 때 0 부터 세므로 매번 약 10 ms
// 파형: wv_tm_run(시작), wv_tm_msec(남은 1/100초), wv_tick_10ms(공유 박자) 를 띄우고 마커로 간격을 잰다
module tb_phase_check ();
    reg clk, rst, btnR, btnL, btnU, btnD;
    reg sw_mode, sw_display_mode, sw_set, sw_24h, sw_timer;
    wire [3:0] fnd_com; wire [7:0] fnd_font; wire [15:0] led;

    stopwatch_watch dut (.clk(clk), .rst(rst), .btnR(btnR), .btnL(btnL), .btnU(btnU), .btnD(btnD),
        .sw_mode(sw_mode), .sw_display_mode(sw_display_mode), .sw_set(sw_set), .sw_24h(sw_24h), .sw_timer(sw_timer),
        .fnd_com(fnd_com), .fnd_font(fnd_font), .led(led));

    always #5 clk = ~clk;

    wire       wv_tm_run    = dut.w_tm_run;
    wire [6:0] wv_tm_msec   = dut.w_tm_msec;
    wire       wv_tick_10ms = dut.w_tick_10ms;

    integer i, t_run, t_first;
    reg [6:0] msec0;

    initial begin
        clk = 0; rst = 1; {btnR, btnL, btnU, btnD} = 0;
        sw_mode = 0; sw_display_mode = 0; sw_set = 0; sw_24h = 0; sw_timer = 1;   // 타이머 화면
        for (i = 0; i < 3; i = i + 1) begin
            rst = 1; #1000 rst = 0;                    // 시도마다 리셋부터 (공유 tick 도 0 부터 다시)
            #(3_000_000 * i);                          // 리셋 뒤 시작 시각을 3 ms 씩 밀기
            btnU = 1; #5_000_000; btnU = 0; #5_000_000; // 00:10 만들기
            btnL = 1;                                    // 시작
            @(posedge wv_tm_run); t_run = $time; msec0 = wv_tm_msec;
            @(wv_tm_msec); t_first = $time;              // 첫 감소
            $display("try %0d: start at %0d ns, first decrement %0d ns later (%0d.%03d ms)",
                     i + 1, t_run, t_first - t_run, (t_first - t_run) / 1_000_000, ((t_first - t_run) / 1_000) % 1000);
            #5_000_000; btnL = 0; #5_000_000;
        end
        $finish;
    end
endmodule
