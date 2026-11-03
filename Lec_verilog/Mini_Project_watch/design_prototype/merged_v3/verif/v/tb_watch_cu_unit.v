`timescale 1ns / 1ps
// [검증 TB] watch_control_unit — 상태 4 x 입력 32 조합 전수 (다음 상태 · 출력) + 리셋
// 기대값은 TB 안의 표(사양)로 따로 계산한다. 상태 번호는 DUT 의 cursor 로 읽는다 (0 분일 · 1 분십 · 2 시 · 3 NORMAL)
module tb_watch_cu_unit ();
    reg clk, rst, bL, bR, bU, bD, sw_set;
    wire set_mode; wire [1:0] cursor; wire o_up, o_down;
    watch_control_unit dut (.clk(clk), .rst(rst), .btn_left(bL), .btn_right(bR), .btn_up(bU), .btn_down(bD), .sw_set(sw_set),
        .set_mode(set_mode), .cursor(cursor), .o_up(o_up), .o_down(o_down));
    always #5 clk = ~clk;
    integer err, st, in, n_chk;
    reg [1:0] exp_next, cur_before; reg exp_up, exp_dn, exp_set;
    // 사양 표: 상태 = cursor 값. 입력 in = {sw_set, L, R, U, D}
    // 다음 상태: NORMAL(3): sw_set ? 0 : 3. SET: ~sw_set ? 3 : L ? left(s) : R ? right(s) : s
    //   left: 0->1, 1->2, 2->0 ; right: 0->2, 1->0, 2->1
    // 출력: set_mode = (s != 3); up = (s!=3)&sw_set&U ; down = (s!=3)&sw_set&D&~U

    // 상태를 원하는 값으로 만드는 순서 (sw_set=1, 버튼 L 로 이동: NORMAL->0 ->1 ->2)
    integer target, guard;
    initial begin
        clk = 0; rst = 1; bL = 0; bR = 0; bU = 0; bD = 0; sw_set = 0; err = 0; n_chk = 0;
        #22 rst = 0;
        for (st = 0; st < 4; st = st + 1) begin
            for (in = 0; in < 32; in = in + 1) begin
                // 1) 상태 st 로 이동
                @(negedge clk); sw_set = 0; bL = 0; bR = 0; bU = 0; bD = 0; @(negedge clk);  // NORMAL
                if (cursor !== 3) begin err = err + 1; $display("FAIL cannot reach NORMAL"); end
                if (st != 3) begin
                    sw_set = 1; @(negedge clk);          // -> 0 (분 일)
                    guard = 0;
                    while (cursor != st && guard < 4) begin bL = 1; @(negedge clk); bL = 0; guard = guard + 1; end
                end
                if (cursor !== st) begin err = err + 1; $display("FAIL cannot reach state %0d (got %0d)", st, cursor); end
                // 2) 입력 조합 적용, 출력(조합) 확인, 엣지 후 다음 상태 확인
                cur_before = cursor;
                sw_set = in[4]; bL = in[3]; bR = in[2]; bU = in[1]; bD = in[0]; #1;
                exp_set = (st != 3);
                exp_up  = (st != 3) & in[4] & in[1];
                exp_dn  = (st != 3) & in[4] & in[0] & ~in[1];
                if (st == 3) exp_next = in[4] ? 2'd0 : 2'd3;
                else if (!in[4]) exp_next = 2'd3;
                else if (in[3]) exp_next = (st == 0) ? 2'd1 : (st == 1) ? 2'd2 : 2'd0;
                else if (in[2]) exp_next = (st == 0) ? 2'd2 : (st == 1) ? 2'd0 : 2'd1;
                else exp_next = st;
                if (set_mode !== exp_set || cursor !== cur_before || o_up !== exp_up || o_down !== exp_dn) begin
                    err = err + 1; $display("FAIL out st%0d in%b: set %b cur %0d up %b dn %b (exp %b %0d %b %b)", st, in[4:0], set_mode, cursor, o_up, o_down, exp_set, cur_before, exp_up, exp_dn);
                end
                @(negedge clk);
                if (cursor !== exp_next) begin err = err + 1; $display("FAIL next st%0d in%b -> %0d (exp %0d)", st, in[4:0], cursor, exp_next); end
                n_chk = n_chk + 1;
                sw_set = 0; bL = 0; bR = 0; bU = 0; bD = 0;
            end
        end
        // 리셋: 각 SET 상태에서 비동기 리셋 -> 즉시 NORMAL, 해제 뒤 sw_set=1 이면 다음 클럭에 분 일
        for (st = 0; st < 3; st = st + 1) begin
            @(negedge clk); sw_set = 1; @(negedge clk);
            guard = 0; while (cursor != st && guard < 4) begin bL = 1; @(negedge clk); bL = 0; guard = guard + 1; end
            #2 rst = 1; #1;
            if (cursor !== 3 || set_mode !== 0 || o_up !== 0) begin err = err + 1; $display("FAIL async reset from st%0d", st); end
            bU = 1; #1; if (o_up !== 0) begin err = err + 1; $display("FAIL o_up during reset"); end
            bU = 0; #2 rst = 0; @(negedge clk); @(negedge clk);
            if (cursor !== 0) begin err = err + 1; $display("FAIL after reset with sw_set=1 -> cursor %0d", cursor); end
            sw_set = 0; @(negedge clk);
        end
        $display("TOTAL MISMATCH = %0d  (%0d state x input combos + 3 resets)", err, n_chk);
        $finish;
    end
endmodule
