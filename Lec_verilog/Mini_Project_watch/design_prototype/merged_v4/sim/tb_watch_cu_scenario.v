`timescale 1ns / 1ps
// [작성] 시계 컨트롤 유닛 시나리오 TB — 상태도의 화살표(A1~A11)와 출력(O1~O4) · 우선순위(P1~P3)를 하나씩
// 버튼 입력은 디바운서가 내는 것과 같은 1클럭 펄스로 준다. 판정은 출력(set_mode · cursor · o_up · o_down)으로만 한다
// → 정보윤이 직접 짠 watch_control_unit 도 포트 이름만 같으면 그대로 돌아간다 (상태 인코딩이 달라도 됨)
// 파형: scenario 신호를 ASCII 로 보면 지금 어느 화살표인지 보인다. c_state 를 같이 띄우면 상태도와 1:1 로 맞춰 볼 수 있다
module tb_watch_cu_scenario ();
    reg  clk, rst, sw_set, btn_left, btn_right, btn_up, btn_down;
    wire set_mode, o_up, o_down;
    wire [1:0] cursor;

    reg [8*20:1] scenario;
    integer err;

    watch_control_unit dut (
        .clk(clk), .rst(rst), .btn_left(btn_left), .btn_right(btn_right), .btn_up(btn_up), .btn_down(btn_down),
        .sw_set(sw_set), .set_mode(set_mode), .cursor(cursor), .o_up(o_up), .o_down(o_down));

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst = 1; err = 0;
        sw_set = 0; btn_left = 0; btn_right = 0; btn_up = 0; btn_down = 0;
        scenario = "RESET";

        // ===== A1 리셋 -> NORMAL (cursor 3, set_mode 0) =====
        #22 rst = 0; scenario = "A1 RST->NORMAL"; $display("A1 %0d ns", $time);
        @(negedge clk);
        if (set_mode !== 0 || cursor !== 3) begin err = err + 1; $display("A1 FAIL set_mode %b cursor %0d", set_mode, cursor); end

        // ===== O4 NORMAL 에서 L · U 는 무시 (자기 자신으로, 펄스 없음) =====
        scenario = "O4 NORMAL L,U X"; $display("O4 %0d ns", $time);
        btn_left = 1; @(negedge clk); btn_left = 0;
        btn_up = 1; #1;
        if (o_up !== 0) begin err = err + 1; $display("O4 FAIL o_up in NORMAL"); end
        @(negedge clk); btn_up = 0;
        if (cursor !== 3) begin err = err + 1; $display("O4 FAIL cursor moved %0d", cursor); end
        repeat (2) @(negedge clk);

        // ===== A2 NORMAL --sw2=1--> SET_MIN_1 (cursor 0) =====
        scenario = "A2 sw2=1->MIN_1"; $display("A2 %0d ns", $time);
        sw_set = 1; @(negedge clk);
        if (set_mode !== 1 || cursor !== 0) begin err = err + 1; $display("A2 FAIL set_mode %b cursor %0d", set_mode, cursor); end
        repeat (2) @(negedge clk);

        // ===== O1 · O2 SET 에서 U -> o_up 1클럭, D -> o_down 1클럭 (밀리: 누른 그 클럭에) =====
        scenario = "O1 O2 U,D pulse"; $display("O1 %0d ns", $time);
        btn_up = 1; #1;
        if (o_up !== 1 || o_down !== 0) begin err = err + 1; $display("O1 FAIL o_up %b", o_up); end
        @(negedge clk); btn_up = 0; #1;
        if (o_up !== 0) begin err = err + 1; $display("O1 FAIL o_up not 1 clock"); end
        @(negedge clk); btn_down = 1; #1;
        if (o_down !== 1 || o_up !== 0) begin err = err + 1; $display("O2 FAIL o_down %b", o_down); end
        @(negedge clk); btn_down = 0;
        if (cursor !== 0) begin err = err + 1; $display("O1 FAIL cursor moved"); end
        repeat (2) @(negedge clk);

        // ===== O3 U + D 같은 클럭 -> U 만 =====
        scenario = "O3 U+D -> U"; $display("O3 %0d ns", $time);
        btn_up = 1; btn_down = 1; #1;
        if (o_up !== 1 || o_down !== 0) begin err = err + 1; $display("O3 FAIL up %b down %b", o_up, o_down); end
        @(negedge clk); btn_up = 0; btn_down = 0;
        repeat (2) @(negedge clk);

        // ===== A3 · A4 · A5  L: MIN_1 -> MIN_10 -> HOUR -> MIN_1 (왼쪽 끝에서 돌아감) =====
        scenario = "A3 L MIN_1->MIN_10"; $display("A3 %0d ns", $time);
        btn_left = 1; @(negedge clk); btn_left = 0;
        if (cursor !== 1) begin err = err + 1; $display("A3 FAIL cursor %0d", cursor); end
        repeat (2) @(negedge clk);
        scenario = "A4 L MIN_10->HOUR"; $display("A4 %0d ns", $time);
        btn_left = 1; @(negedge clk); btn_left = 0;
        if (cursor !== 2) begin err = err + 1; $display("A4 FAIL cursor %0d", cursor); end
        repeat (2) @(negedge clk);
        scenario = "A5 L HOUR->MIN_1"; $display("A5 %0d ns", $time);
        btn_left = 1; @(negedge clk); btn_left = 0;
        if (cursor !== 0) begin err = err + 1; $display("A5 FAIL cursor %0d", cursor); end
        repeat (2) @(negedge clk);

        // ===== A6 · A7 · A8  R: MIN_1 -> HOUR -> MIN_10 -> MIN_1 (오른쪽 끝에서 돌아감) =====
        scenario = "A6 R MIN_1->HOUR"; $display("A6 %0d ns", $time);
        btn_right = 1; @(negedge clk); btn_right = 0;
        if (cursor !== 2) begin err = err + 1; $display("A6 FAIL cursor %0d", cursor); end
        repeat (2) @(negedge clk);
        scenario = "A7 R HOUR->MIN_10"; $display("A7 %0d ns", $time);
        btn_right = 1; @(negedge clk); btn_right = 0;
        if (cursor !== 1) begin err = err + 1; $display("A7 FAIL cursor %0d", cursor); end
        repeat (2) @(negedge clk);
        scenario = "A8 R MIN_10->MIN_1"; $display("A8 %0d ns", $time);
        btn_right = 1; @(negedge clk); btn_right = 0;
        if (cursor !== 0) begin err = err + 1; $display("A8 FAIL cursor %0d", cursor); end
        repeat (2) @(negedge clk);

        // ===== P3 L + R 같은 클럭 -> L 만 (MIN_1 -> MIN_10) =====
        scenario = "P3 L+R -> L"; $display("P3 %0d ns", $time);
        btn_left = 1; btn_right = 1; @(negedge clk); btn_left = 0; btn_right = 0;
        if (cursor !== 1) begin err = err + 1; $display("P3 FAIL cursor %0d (exp 1)", cursor); end
        repeat (2) @(negedge clk);

        // ===== A10 SET_MIN_10 --sw2=0--> NORMAL =====
        scenario = "A10 MIN_10 sw2=0"; $display("A10 %0d ns", $time);
        sw_set = 0; @(negedge clk);
        if (set_mode !== 0 || cursor !== 3) begin err = err + 1; $display("A10 FAIL"); end
        repeat (2) @(negedge clk);

        // ===== A9 SET_MIN_1 --sw2=0--> NORMAL =====
        scenario = "A9 MIN_1 sw2=0"; $display("A9 %0d ns", $time);
        sw_set = 1; @(negedge clk); @(negedge clk);            // 다시 진입 -> MIN_1
        sw_set = 0; @(negedge clk);
        if (set_mode !== 0 || cursor !== 3) begin err = err + 1; $display("A9 FAIL"); end
        repeat (2) @(negedge clk);

        // ===== A11 SET_HOUR --sw2=0--> NORMAL =====
        scenario = "A11 HOUR sw2=0"; $display("A11 %0d ns", $time);
        sw_set = 1; @(negedge clk);
        btn_right = 1; @(negedge clk); btn_right = 0;          // MIN_1 -> HOUR
        if (cursor !== 2) begin err = err + 1; $display("A11 FAIL setup cursor %0d", cursor); end
        sw_set = 0; @(negedge clk);
        if (set_mode !== 0 || cursor !== 3) begin err = err + 1; $display("A11 FAIL"); end
        repeat (2) @(negedge clk);

        // ===== P1 sw2 를 내리는 그 클럭에 L -> NORMAL (자리 이동 안 함) =====
        scenario = "P1 sw2=0 + L"; $display("P1 %0d ns", $time);
        sw_set = 1; @(negedge clk); @(negedge clk);            // MIN_1
        sw_set = 0; btn_left = 1; @(negedge clk); btn_left = 0;
        if (set_mode !== 0 || cursor !== 3) begin err = err + 1; $display("P1 FAIL cursor %0d", cursor); end
        repeat (2) @(negedge clk);

        // ===== P2 sw2 를 내리는 그 클럭에 U -> 펄스 없음 =====
        scenario = "P2 sw2=0 + U"; $display("P2 %0d ns", $time);
        sw_set = 1; @(negedge clk); @(negedge clk);
        sw_set = 0; btn_up = 1; #1;
        if (o_up !== 0) begin err = err + 1; $display("P2 FAIL o_up while sw2 falling"); end
        @(negedge clk); btn_up = 0;
        repeat (2) @(negedge clk);

        // ===== R1 설정 중 리셋 -> NORMAL =====
        scenario = "R1 RST in SET"; $display("R1 %0d ns", $time);
        sw_set = 1; @(negedge clk);
        btn_left = 1; @(negedge clk); btn_left = 0;            // MIN_10
        #2 rst = 1; #6 rst = 0;                                 // 비동기 리셋 (클럭 사이)
        #1;
        if (set_mode !== 0 || cursor !== 3) begin err = err + 1; $display("R1 FAIL not NORMAL during/after reset"); end
        @(negedge clk); @(negedge clk);                         // sw2 는 아직 1 -> 리셋 푼 뒤 첫 상승 에지에서 MIN_1 로 다시 진입
                                                                // (첫 negedge 는 리셋 해제 1 ns 뒤라 그 사이 상승 에지가 없음)
        if (cursor !== 0) begin err = err + 1; $display("R1 FAIL re-enter cursor %0d", cursor); end
        sw_set = 0; repeat (2) @(negedge clk);

        scenario = "END";
        $display("end %0d ns", $time);
        $display("TOTAL MISMATCH = %0d", err);
        $finish;
    end
endmodule
