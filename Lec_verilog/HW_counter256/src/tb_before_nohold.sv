`timescale 1ns / 1ps

class transaction;
    rand bit       rst;
    rand bit       mode;
    rand bit       run_stop;
    rand bit       clear;
    logic    [7:0] counter;

    function void debug_print(string name);
        $display(
            "%t : [%s] rst = %d, mode = %d, run_stop = %d, clear = %d, counter = %d",
            $time, name, rst, mode, run_stop, clear, counter);
    endfunction

    constraint mode_dist {  // 문법 = constraint <이름> { 조건 }. mode_dist 는 내가 붙인 이름 (mode 에 dist 를 건다는 뜻). _dist 는 문법이 아님
        mode dist {
            0 :/ 9,
            1 :/ 1
        };
    }
endclass

interface counter_interface (
    input clk
);
    logic       rst;
    logic       mode;
    logic       run_stop;
    logic       clear;
    logic [7:0] counter;

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

    logic [7:0] expected_count = 0;
    int pass_cnt, fail_cnt = 0, total_cnt = 0;

    // task run
    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.debug_print("SCB");
            if (!tr.rst && !tr.clear) begin
                total_cnt++;
                if (expected_count == tr.counter) begin
                    pass_cnt++;
                end else begin
                    fail_cnt++;
                end
                $display("expected_count = %d", expected_count);
                if (tr.run_stop) begin
                    if (tr.mode) begin
                        expected_count--;
                    end else begin
                        expected_count++;
                    end
                end
            end else begin
                expected_count = 0;
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


