`timescale 1ns / 1ps
interface uart_interface (
    input clk
);
    logic       rst;  // reset
    logic       start;  // tx start
    logic [7:0] tx_data;  //randomize tx_data
    logic       tx;
    logic       tx_busy;
endinterface

class transaction;
    bit rst;
    bit start;
    rand bit [7:0] tx_data;
    rand
    int unsigned
    interval;  // tx start interval -> 범위가 너무 커서 제약걸어줘야 할 필요성 있음. 
    logic tx;
    logic tx_busy;
    // for MON, SCB
    bit start_bit_error;
    bit stop_bit_error;
    bit frame_time_error;

    constraint interval_range {interval < 1000;}

    function void debug_print(string name);
        $display(
            "%t : [%s] rst = %d, start = %d, tx_data = %d, interval = %d, tx = %d, tx_busy = %d",
            $time, name, rst, start, tx_data, interval, tx, tx_busy);
    endfunction
endclass

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_evt;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_evt);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_evt = gen_next_evt;
    endfunction

    task run(int run_count);
        repeat (run_count) begin
            tr = new();
            tr.randomize();
            tr.rst   = 0;
            tr.start = 0;
            gen2drv_mbox.put(tr);
            tr.debug_print("GEN");
            @(gen_next_evt);
        end
    endtask

endclass

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual uart_interface uart_vif;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual uart_interface uart_vif);
        this.gen2drv_mbox = gen2drv_mbox;
        this.uart_vif = uart_vif;
    endfunction

    int busy_check_count = 0;

    task preset();
        uart_vif.rst = 1;
        uart_vif.tx_data = 0;
        uart_vif.start = 0;
        repeat (2) @(negedge uart_vif.clk);
        uart_vif.rst = 0;

    endtask

    task run();
        forever begin
            @(negedge uart_vif.clk);
            busy_check_count = 0;
            gen2drv_mbox.get(tr);
            tr.debug_print("DRV");
            // check tx_busy
            while (uart_vif.tx_busy) begin
                @(negedge uart_vif.clk);
                busy_check_count++;
                if (busy_check_count > 10416 * 10) begin
                    $display("tx_busy hige was too long...... !");
                    break;
                end
            end

            if (!uart_vif.tx_busy) begin
                // interval
                repeat (tr.interval) @(negedge uart_vif.clk);
                uart_vif.rst     = 0;
                uart_vif.start   = 1;
                uart_vif.tx_data = tr.tx_data;
                @(negedge uart_vif.clk);
                uart_vif.start = 0;
            end
            uart_vif.tx_data = 8'hxx;
        end
    endtask
endclass


class monitor;
    transaction tr_in, tr_out;
    mailbox #(transaction) mon2scb_in_mbox;
    mailbox #(transaction) mon2scb_out_mbox;
    virtual uart_interface uart_vif;
    parameter BAUD_TIME = 10416 * 10;  // 10416 clock * 10nsec
    parameter FRAME_TIME = BAUD_TIME * 10;

    function new(mailbox#(transaction) mon2scb_in_mbox,
                 mailbox#(transaction) mon2scb_out_mbox,
                 virtual uart_interface uart_vif);
        this.mon2scb_in_mbox = mon2scb_in_mbox;
        this.mon2scb_out_mbox = mon2scb_out_mbox;
        this.uart_vif = uart_vif;
    endfunction

    time frame_start_time;
    time start_time, c_time;  // time variable.


    task uart_receive(output logic [7:0] receive_data);
        @(negedge uart_vif.tx);
        // To check of start bit error

        start_time = $time;
        frame_start_time = start_time;
        c_time = start_time;
        //#(BAUD_TIME / 2);

        // check start bit
        while (uart_vif.tx == 0 & (c_time - start_time) <= BAUD_TIME) begin
            @(posedge uart_vif.clk);
            c_time = $time;
        end
        if ((c_time - start_time) >= (BAUD_TIME - (BAUD_TIME / 16))) begin
            tr_out.start_bit_error = 0;  // PASS
        end else begin
            tr_out.start_bit_error = 1;  // FAIL
        end
        $display("%t  : c_time - start_time = %d", $time,
                 (c_time - start_time));
        // data bit read
        for (int i = 0; i < 8; i++) begin
            #(BAUD_TIME / 2);
            receive_data[i] = uart_vif.tx;
            #(BAUD_TIME / 2);
        end

        start_time = $time;
        c_time = start_time;

        while ((!uart_vif.tx) && ((c_time - start_time) <= BAUD_TIME / 2)) begin // 0이면 탈출. 무한 loop 방지
            @(posedge uart_vif.clk);
            c_time = $time;
        end
        if ((c_time - start_time) >= ((BAUD_TIME / 2))) begin
            tr_out.stop_bit_error = 1;
        end else begin
            // stop bit check
            start_time = $time;
            c_time = start_time;
            // stop bit begin
            while ((uart_vif.tx == 1) && (uart_vif.tx_busy) && ((c_time - start_time) <= BAUD_TIME)) begin
                @(posedge uart_vif.clk);
                c_time = $time;
            end
            if ((c_time - start_time) >= (BAUD_TIME - (BAUD_TIME / 16))) begin
                tr_out.stop_bit_error = 0;  // PASS
            end else begin
                tr_out.stop_bit_error = 1;  // FAIL
            end
            $display("STOP bit time");
            $display("%t: c_time - start_time = %d", $time,
                     (c_time - start_time));

        end
        // frame time check
        c_time = $time;
        if(((c_time - frame_start_time) <= (FRAME_TIME + (BAUD_TIME/2))) &&
         ((c_time - frame_start_time ) >= (FRAME_TIME - (BAUD_TIME/2)))) begin
            tr_out.frame_time_error = 0;
        end else begin
            tr_out.frame_time_error = 1;
        end
        $display("%t : fram time = %d ", $time, (c_time - frame_start_time));
    endtask

    time start_interval = 0, c_time_interval = 0;
    int  interval_cnt   = 0;
    task run();
        forever begin
            // 1. wait check start == 1
            //@(posedge uart_vif.clk);
            while (!uart_vif.start) begin
                @(posedge uart_vif.clk);
            end
            c_time_interval = $time;
            // 2. mon2scb_in_mbox put
            tr_in = new;
            tr_in.tx_data = uart_vif.tx_data;
            tr_in.interval = (c_time_interval - start_interval) / 10;
            mon2scb_in_mbox.put(tr_in);
            tr_in.debug_print("MON_IN");
            // 3. baud_time * 10 , mon2scb_out_mbox put,
            // receive task
            tr_out = new;
            uart_receive(tr_out.tx_data);
            tr_out.rst     = uart_vif.rst;
            tr_out.tx_busy = uart_vif.tx_busy;
            tr_out.tx      = uart_vif.tx;
            start_interval = $time;
            mon2scb_out_mbox.put(tr_out);
            tr_out.debug_print("MON_OUT");
        end
    endtask
endclass

class scoreboard;
    transaction tr_in, tr_out;
    mailbox #(transaction) mon2scb_in_mbox;
    mailbox #(transaction) mon2scb_out_mbox;
    event gen_next_evt;

    // scoreboard pass/fail variable
    int total_cnt = 0;
    int tx_data_pass_cnt = 0, tx_data_fail_cnt = 0;
    int tx_start_bit_pass_cnt = 0, tx_start_bit_fail_cnt = 0;
    int tx_stop_bit_pass_cnt = 0, tx_stop_bit_fail_cnt = 0;
    int tx_frame_time_pass_cnt = 0, tx_frame_time_fail_cnt = 0;

    // coverage declaration
    covergroup cg_uart;
        option.per_instance = 1;

        cp_tx_data: coverpoint tr_in.tx_data {
            bins coner[] = {8'h55, 8'haa}; bins data[] = {[0 : 255]};
        }
        cp_interval: coverpoint tr_in.interval {
            bins interval_coner = {0}; bins interval_time[] = {[1 : 1041]};
        }
    endgroup

    function new(mailbox#(transaction) mon2scb_in_mbox,
                 mailbox#(transaction) mon2scb_out_mbox, event gen_next_evt);
        this.mon2scb_in_mbox = mon2scb_in_mbox;
        this.mon2scb_out_mbox = mon2scb_out_mbox;
        this.gen_next_evt = gen_next_evt;
        cg_uart = new();
    endfunction

    task run();
        forever begin
            mon2scb_in_mbox.get(tr_in);
            tr_in.debug_print("SCB_IN");
            mon2scb_out_mbox.get(tr_out);
            tr_out.debug_print("SCB_OUT");
            total_cnt++;
            // TX start bit pass/fail
            if (!tr_out.start_bit_error) begin
                tx_start_bit_pass_cnt++;
                $display(" tx start bit pass !!!");
            end else begin
                tx_start_bit_fail_cnt++;
                $display(" tx start bit fail !!!");
            end



            if (tr_in.tx_data == tr_out.tx_data) begin
                tx_data_pass_cnt++;
                $display("tx_data Pass !!! ");
            end else begin
                tx_data_fail_cnt++;
                $display("tx_data Fail !!! ");
            end

            if (!tr_out.stop_bit_error) begin
                tx_stop_bit_pass_cnt++;
                $display(" tx stop bit pass !!!");
            end else begin
                tx_stop_bit_fail_cnt++;
                $display(" tx stop bit fail !!!");
            end

            if (!tr_out.frame_time_error) begin
                tx_frame_time_pass_cnt++;
                $display(" tx frame time pass !!!");
            end else begin
                tx_frame_time_fail_cnt++;
                $display(" tx frame time fail !!!");
            end

            cg_uart.sample();

            ->gen_next_evt;
        end
    endtask

    task report();
        $display("***********************************");
        $display("** UART TX Verification Test ******");
        $display("***********************************");
        $display("** total          test num = %4d **", total_cnt);
        $display("** start bit      pass num = %4d **", tx_start_bit_pass_cnt);
        $display("** start bit      fail num = %4d **", tx_start_bit_fail_cnt);
        $display("** tx_data        pass num = %4d **", tx_data_pass_cnt);
        $display("** tx_data        fail num = %4d **", tx_data_fail_cnt);
        $display("** stop bit       pass num = %4d **", tx_stop_bit_pass_cnt);
        $display("** stop bit       fail num = %4d **", tx_stop_bit_fail_cnt);
        $display("** frame time     pass num = %4d **", tx_frame_time_pass_cnt);
        $display("** frame time     fail num = %4d **", tx_frame_time_fail_cnt);
        $display("***********************************");
        $display("**       UART TX Coverage ******");
        $display("***********************************");
        $display("** tx data   = %6.2f %%**", cg_uart.cp_tx_data.get_coverage());
        $display("** Interval   = %6.2f %%**",
                 cg_uart.cp_interval.get_coverage());
        $display("***********************************");

    endtask


endclass

class environment;
    generator              gen;
    driver                 drv;
    monitor                mon;
    scoreboard             scb;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_in_mbox;
    mailbox #(transaction) mon2scb_out_mbox;
    event                  gen_next_evt;

    function new(virtual uart_interface uart_vif);
        gen2drv_mbox = new;
        mon2scb_in_mbox = new;
        mon2scb_out_mbox = new;
        gen = new(gen2drv_mbox, gen_next_evt);
        drv = new(gen2drv_mbox, uart_vif);
        mon = new(mon2scb_in_mbox, mon2scb_out_mbox, uart_vif);
        scb = new(mon2scb_in_mbox, mon2scb_out_mbox, gen_next_evt);
    endfunction

    task run(int run_count);
        drv.preset();
        fork
            gen.run(run_count);
            drv.run();
            mon.run();
            scb.run();
        join_any
        scb.report();
    endtask

endclass



module tb_uart_sv ();
    parameter BAUD_TIME = (100_000_000 / 9600) * 10;
    logic clk = 0;
    uart_interface uart_if (clk);
    environment env;

    uart dut (
        .clk    (clk),
        .rst    (uart_if.rst),
        .start  (uart_if.start),
        .tx_data(uart_if.tx_data),
        .tx     (uart_if.tx),
        .tx_busy(uart_if.tx_busy)
    );

    always #5 clk = ~clk;

    initial begin
        /* 
        uart_if.rst = 1;
        uart_if.start = 0;
        uart_if.tx_data = 8'haa;
        #10;
        uart_if.rst = 0;
        #10;
        uart_if.start = 1;
        #10;
        uart_if.start = 0;
        #(BAUD_TIME * 10);  // 10bit 나가기
        #100;
*/
        env = new(uart_if);
        env.run(20);
        $finish;
    end

endmodule
