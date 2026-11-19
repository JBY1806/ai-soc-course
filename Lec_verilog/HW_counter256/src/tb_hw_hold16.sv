`timescale 1ns / 1ps

class transaction;
    rand bit       rst;
    rand bit       mode;
    randc bit      run_stop;  // HW : cyclic → 0 · 1 반반 (dist 못 씀)
    rand bit       clear;
    logic    [7:0] counter;
    // HW : 이 객체 값을 몇 클럭 유지할지 (3 클럭 이상 연속)
    rand int unsigned run_stop_hold;

    function void debug_print(string name);
        $display(
            "%t : [%s] rst = %d, mode = %d, run_stop = %d, clear = %d, counter = %d, run_stop_hold = %0d",
            $time, name, rst, mode, run_stop, clear, counter, run_stop_hold);
    endfunction

    // HW : mode 5 : 5 (업 · 다운 반반)
    constraint mode_dist {  // 문법 = constraint <이름> { 조건 }. mode_dist 는 내가 붙인 이름 (mode 에 dist 를 건다는 뜻). _dist 는 문법이 아님
        mode dist {
            0 :/ 5,
            1 :/ 5
        };
    }

    // HW : clear 는 가끔 (0 : 9, 1 : 1)
    constraint clear_dist {  // clear_dist 도 이름 (clear 에 dist). 이름은 아무거나 되지만 무엇을 제한하는지 보이게 짓는다
        clear dist {
            0 :/ 9,
            1 :/ 1
        };
    }

    // HW : 유지 클럭 수 3 ~ 16 (처음 범위)
    constraint run_stop_hold_range {run_stop_hold inside {[3 : 16]};}  // run_stop_hold_range = 이름 (_range 는 문법 아님, "범위 제한" 뜻으로 붙임). 문법은 constraint · inside · {[최소 : 최대]}
endclass

interface counter_interface (
    input clk
);
    logic       rst;
    logic       mode;
    logic       run_stop;
    logic       clear;
    logic [7:0] counter;
    // HW 파형용 (TB 디버그 신호) : 지금 드라이브 중인 객체 번호 · 그 객체의 유지 클럭 수
    int         obj_no = 0;
    int         hold = 0;

    property rst_zero;
        @(posedge clk) rst |=> (counter == 8'd0);
    endproperty
    a_rst_zero :
    assert property (rst_zero)
    else begin
        $display("[Interface] rst counter value error !! %d", rst, counter);
    end
endinterface

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_evt;

    //function new
    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_evt);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_evt = gen_next_evt;
    endfunction

    // task run
    // run을 멈출 스위치라는 표시
    bit enable = 1;
    task run();
        while (enable) begin
            tr = new;
            assert (tr.randomize())
            else $display("[GEN] tr.randomized error !!!");
            // mode = randomized, run_stop = randomized, clear = randomized
            tr.rst = 0; // 리셋은 랜덤으로 안할거라서 0으로 덮어씀.
            //tr.mode = 0;
            //tr.run_stop = 1;
            //tr.clear = 0;
            gen2drv_mbox.put(tr);
            tr.debug_print("GEN");
            @(gen_next_evt);
        end
    endtask

endclass


class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual counter_interface counter_vif;
    event gen_next_evt;

    //function new
    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual counter_interface counter_vif, event gen_next_evt);
        this.gen2drv_mbox = gen2drv_mbox;
        this.counter_vif  = counter_vif;
        this.gen_next_evt = gen_next_evt;
    endfunction

    // task run
    task preset();
        counter_vif.rst      = 1;
        counter_vif.mode     = 0;
        counter_vif.run_stop = 0;
        counter_vif.clear    = 0;
        @(negedge counter_vif.clk);
        @(negedge counter_vif.clk);
        counter_vif.rst = 0;  // 20 ns에 리셋 끔.
    endtask

    task run();
        forever begin
            @(posedge counter_vif.clk);
            gen2drv_mbox.get(tr);
            tr.debug_print("DRV");
            #1;
            counter_vif.rst      = tr.rst;
            counter_vif.mode     = tr.mode;
            counter_vif.run_stop = tr.run_stop;
            counter_vif.clear    = tr.clear;
            counter_vif.obj_no   = counter_vif.obj_no + 1;  // 파형용
            counter_vif.hold     = tr.run_stop_hold;        // 파형용
            // HW : 첫 클럭은 위에서 썼으니 나머지 (hold - 1) 클럭 동안 그대로 유지
            repeat (tr.run_stop_hold - 1) begin
                @(posedge counter_vif.clk);
            end
            ->gen_next_evt;
        end

    endtask
endclass

class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual counter_interface counter_vif;

    //function new
    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual counter_interface counter_vif);
        this.mon2scb_mbox = mon2scb_mbox;
        this.counter_vif  = counter_vif;
    endfunction

    // task run
    task run();
        forever begin
            @(posedge counter_vif.clk);
            tr          = new;
            tr.rst      = counter_vif.rst;
            tr.mode     = counter_vif.mode;
            tr.run_stop = counter_vif.run_stop;
            tr.clear    = counter_vif.clear;
            tr.counter  = counter_vif.counter;
            mon2scb_mbox.put(tr);
            tr.debug_print("MON");
        end
    endtask
endclass


class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;

    //function new
    function new(mailbox#(transaction) mon2scb_mbox);
        this.mon2scb_mbox = mon2scb_mbox;
    endfunction

    logic [7:0] expected_count = 0;                    // 정답 counter : TB 가 DUT 와 같은 규칙으로 직접 세는 값. monitor 가 읽은 counter 와 비교한다
    int pass_cnt, fail_cnt = 0, total_cnt = 0;         // 비교한 전체 횟수 (total), 그중 맞은 횟수 (pass), 틀린 횟수 (fail)
    // HW ② 신호별 pass / fail : 비교 한 번을, 지난 클럭에 어떤 입력이 들어갔는지에 따라 아래 셋 중 어디에 셀지 정한다
    int mode_pass_cnt = 0, mode_fail_cnt = 0;          // 지난 클럭에 run_stop = 1 (세는 중) 이었던 비교. 업 / 다운 방향이 맞았으면 pass, 틀렸으면 fail 을 1 더함
    int run_stop_pass_cnt = 0, run_stop_fail_cnt = 0;  // 지난 클럭에 clear = 0 이었던 비교. 멈춤이면 값이 그대로인지, 움직임이면 1 바뀌었는지 맞았으면 pass, 틀렸으면 fail
    int clear_pass_cnt = 0, clear_fail_cnt = 0;        // 지난 클럭에 clear = 1 이었던 비교. counter 가 0 이 됐으면 pass, 안 됐으면 fail 을 1 더함
    // 앞 줄 (지난 클럭) 값 : 이번에 읽은 counter 는 지난 클럭 입력으로 DUT 가 만든 값이라서, 지난 입력을 기억해 둔다
    bit first_flag = 1;                                // 1 = 지금 객체가 첫 객체 (맨 처음 · rst 직후) : 앞 줄 값이 아직 없어서 비교를 건너뜀. 한 번 처리하면 0
    bit prev_mode, prev_run_stop, prev_clear;          // 바로 앞 객체 (지난 클럭) 의 mode · run_stop · clear. 신호별로 나눌 때와 유지 길이를 셀 때 같이 쓴다
    // HW ① 확인 : 신호마다 같은 값이 3 클럭 이상 이어진 구간이 몇 개 나왔는지 센다 (클럭 수가 아니라 구간 수. pass / fail 판정에는 안 씀)
    int hold_len_mode = 0, hold_len_run_stop = 0, hold_len_clear = 0;     // 지금 같은 값이 몇 클럭째 유지되고 있는지 (값이 바뀌면 1 부터 다시)
    int hold3_cnt_mode = 0, hold3_cnt_run_stop = 0, hold3_cnt_clear = 0;  // 3 클럭 이상 이어진 구간 수. hold_len 이 정확히 3 이 되는 순간에만 1 더하므로 한 구간은 4 클럭이든 6 클럭이든 1 (예 : 0000 → 111 이면 2). report 마지막 줄

    // task run
    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.debug_print("SCB");
            if (tr.rst) begin
                expected_count = 0;
                first_flag     = 1;  // rst 다음 객체는 다시 첫 객체로 (비교 건너뜀)
            end else begin
                // 이번에 읽은 counter 와 정답 counter 를 비교 (정답은 지난 클럭 입력으로 미리 갱신해 둔 값)
                if (!first_flag) begin  // 첫 객체가 아닐 때만 비교
                    total_cnt++;
                    if (expected_count == tr.counter) begin
                        pass_cnt++;
                    end else begin
                        fail_cnt++;
                    end
                    // 신호별로 나눠 세기 : 지난 클럭 입력이 무엇이었느냐로 이번 비교가 어느 신호의 시험인지 정한다
                    if (prev_clear) begin  // 지난 클럭 clear = 1 → counter 가 0 이 됐는지 본 비교
                        if (expected_count == tr.counter) begin
                            clear_pass_cnt++;
                        end else begin
                            clear_fail_cnt++;
                        end
                    end else begin
                        // 지난 클럭 clear = 0 → run_stop 시험 (run_stop 0 이면 값이 그대로인지, 1 이면 1 바뀌었는지)
                        if (expected_count == tr.counter) begin
                            run_stop_pass_cnt++;
                        end else begin
                            run_stop_fail_cnt++;
                        end
                        // 지난 클럭 run_stop = 1 (세는 중) 이었으면 방향도 본 것 → mode 로도 센다 (mode 0 업, 1 다운)
                        if (prev_run_stop) begin
                            if (expected_count == tr.counter) begin
                                mode_pass_cnt++;
                            end else begin
                                mode_fail_cnt++;
                            end
                        end
                    end
                end
                $display("expected_count = %d", expected_count);
                // 다음 비교에 쓸 정답 counter 를 이번 입력으로 갱신 (DUT 와 같은 규칙 : clear 면 0, run_stop 이면 mode 에 따라 +1 / -1)
                if (tr.clear) begin
                    expected_count = 0;
                end else if (tr.run_stop) begin
                    if (tr.mode) begin
                        expected_count--;
                    end else begin
                        expected_count++;
                    end
                end

                // 유지 길이 세기 (prev_ 를 이번 값으로 덮어쓰기 전에 해야 함) : 앞 줄과 값이 같으면 + 1, 다르면 1 부터 다시. 길이가 정확히 3 이 되는 순간에만 hold3_cnt 에 1 더함 (4 · 5 · 6 으로 늘어도 다시 안 더함)
                if (!first_flag && tr.mode == prev_mode) begin
                    hold_len_mode++;
                end else begin
                    hold_len_mode = 1;
                end
                if (hold_len_mode == 3) hold3_cnt_mode++;  // == 3 이라 한 구간에 한 번만 (>= 3 이면 6 클럭 구간을 4 번 셈)

                if (!first_flag && tr.run_stop == prev_run_stop) begin
                    hold_len_run_stop++;
                end else begin
                    hold_len_run_stop = 1;
                end
                if (hold_len_run_stop == 3) hold3_cnt_run_stop++;  // 같은 방식 : 구간 하나에 1

                if (!first_flag && tr.clear == prev_clear) begin
                    hold_len_clear++;
                end else begin
                    hold_len_clear = 1;
                end
                if (hold_len_clear == 3) hold3_cnt_clear++;  // 같은 방식 : 구간 하나에 1

                // 이번 객체 값을 앞 줄 값으로 저장 → 다음 객체에서 씀
                first_flag    = 0;
                prev_mode     = tr.mode;
                prev_run_stop = tr.run_stop;
                prev_clear    = tr.clear;
            end
        end
    endtask

    task report();
        $display("********************************");
        $display("*** counter 256 test program ***");
        $display("***    total test = %4d      ***", total_cnt);
        $display("***    pass test = %4d      ***", pass_cnt);
        $display("***    fail test = %4d      ***", fail_cnt);
        $display("********************************");
        $display("*** mode     pass = %4d, fail = %4d ***", mode_pass_cnt, mode_fail_cnt);
        $display("*** run_stop pass = %4d, fail = %4d ***", run_stop_pass_cnt, run_stop_fail_cnt);
        $display("*** clear    pass = %4d, fail = %4d ***", clear_pass_cnt, clear_fail_cnt);
        $display("********************************");
        $display("*** 3 clock hold : mode = %0d, run_stop = %0d, clear = %0d ***", hold3_cnt_mode, hold3_cnt_run_stop, hold3_cnt_clear);
        $display("********************************");
        $display("*** end counter 256 test program ***");
        $display("********************************");
    endtask
endclass



class environment;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    event gen_next_evt;


    function new(virtual counter_interface counter_vif);
        gen2drv_mbox = new;
        mon2scb_mbox = new;
        gen = new(gen2drv_mbox, gen_next_evt);
        drv = new(gen2drv_mbox, counter_vif, gen_next_evt);
        mon = new(mon2scb_mbox, counter_vif);
        scb = new(mon2scb_mbox);
    endfunction

    task run(int run_count);
        drv.preset();
        gen.enable = 1;
        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join_none
        #3000;
        gen.enable = 0;
        #10;
        scb.report();
        disable fork;
    endtask
endclass




module tb_counter_sv ();
    logic clk = 0;
    counter_interface counter_if (clk);
    always #5 clk = ~clk;

    environment env;

    counter_256 dut (
        .clk     (clk),
        .rst     (counter_if.rst),
        .mode    (counter_if.mode),
        .run_stop(counter_if.run_stop),
        .clear   (counter_if.clear),
        .counter (counter_if.counter)
    );

    initial begin
        env = new(counter_if);
        env.run(256);
        $finish;
    end
endmodule


