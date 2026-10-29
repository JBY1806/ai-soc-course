`timescale 1ns / 1ps

module tb_fifo ();

    parameter DEPTH = 4;
    reg clk, rst, push, pop;
    reg  [7:0] push_data;
    wire [7:0] pop_data;
    wire full, empty;
    reg [7:0] compare_buffer[0:DEPTH-1];
    integer i;
    integer pass_cnt, fail_cnt;
    reg [1:0]
        push_cnt,
        pop_cnt;  // 칸 4개 (0 ~ 3) → 2비트, 3 + 1 = 0 으로 FIFO 포인터처럼 되감김
    fifo #(
        .DEPTH(DEPTH)
    ) dut (
        .clk      (clk),
        .rst      (rst),
        .push     (push),
        .pop      (pop),
        .push_data(push_data),
        .pop_data (pop_data),
        .full     (full),
        .empty    (empty)
    );

    always #5 clk = ~clk;

    initial begin
        clk       = 0;
        rst       = 1;
        push      = 0;
        pop       = 0;
        push_data = 0;

        i         = 0;
        push_cnt  = 0;
        pop_cnt   = 0;
        pass_cnt  = 0;
        fail_cnt  = 0;
        @(negedge clk);
        @(negedge clk);

        rst = 0;
        @(negedge clk);
        if (full == 0) begin
            $display("%t : pass full signal", $time);
        end else begin
            $display("%t : fail full signal", $time);
        end

        if (empty == 1) begin
            $display("%t : pass empty signal", $time);
        end else begin
            $display("%t : fail empty signal", $time);
        end

        $display("===== push only (%0d ns) =====", $time);
        // push only, push 5 times
        for (i = 0; i < 5; i = i + 1) begin
            @(negedge clk);
            push_data = 8'h0a + i;
            push = 1'b1;
            $display("%t : push data = %h, full = %b", $time, push_data, full);
            if (!full) begin
                compare_buffer[push_cnt] = push_data;
                push_cnt = push_cnt + 1;
            end
        end
        @(negedge clk);
        push = 1'b0;

         $display("===== pop only (%0d ns) =====", $time);
        // pop only, pop 5 times
        for (i = 0; i < 5; i = i + 1) begin
            @(negedge clk);
            pop = 1'b1;
            if (!empty) begin
                if (pop_data == compare_buffer[pop_cnt]) begin
                    $display("%t : pass pop data = %h", $stime, pop_data);
                end else begin
                    $display("%t : fail pop data = %h, compare = %h", $stime,
                             pop_data, compare_buffer[pop_cnt]);
                end
                pop_cnt = pop_cnt + 1;  // 실제로 pop 된 때만 (비었으면 FIFO 가 pop 을 무시)
            end
        end

        //empty state would be '1'
        if (empty) begin
            $display("%t : pass empty signal", $stime);
        end else begin
            $display("%t : fail empty signal", $stime);
        end

        @(negedge clk);
        push = 1'b0;
        pop  = 1'b0;

          $display("===== push/pop (%0d ns) =====", $time);
        // push/pop 5 times 
        for (i = 0; i < 5; i = i + 1) begin
            @(negedge clk);
            push = 1'b1;
            push_data = 8'h0f - i;
            $display("%t : push data = %h, full = %b, empty = %b", $time, push_data, full, empty);
            if (!full) begin
                compare_buffer[push_cnt] = push_data;
                push_cnt = push_cnt + 1;
            end

            pop = 1'b1;


            if (!empty) begin
                if (pop_data == compare_buffer[pop_cnt]) begin
                    $display("%t : pass pop data = %h", $stime, pop_data);
                end else begin
                    $display("%t : fail pop data = %h, compare = %h", $stime,
                             pop_data, compare_buffer[pop_cnt]);
                end
                pop_cnt = pop_cnt + 1;  // 실제로 pop 된 때만 (empty 면 push 만 일어남)
            end
        end

         $display("===== empty fifo (%0d ns) =====", $time);
        //for empty fifo
        @(negedge clk);
        push = 0;
        pop = 1;
        pop_cnt = pop_cnt + 1;
        @(negedge clk);
        pop = 0;
        @(negedge clk);

     $display("===== random test (%0d ns) =====", $time);
        // random test
        for (i = 0; i < 256; i = i + 1) begin
            @(negedge clk);
            push = $random() % 2;
            pop = $random() % 2;
            push_data = $random() % 256;

            //push 1
            if (push & (!full)) begin
                compare_buffer[push_cnt] = push_data;
                push_cnt = push_cnt + 1;
            end

            //pop 1
            if (pop & (!empty)) begin
                if (pop_data == compare_buffer[pop_cnt]) begin
                    pass_cnt = pass_cnt + 1;
                    $display("%t : pass pop data = %h", $time, pop_data);
                end else begin
                    fail_cnt = fail_cnt + 1;
                    $display("%t : fail pop data = %h, compare = %h", $time,
                             pop_data, compare_buffer[pop_cnt]);
                    //  $display("%t : fail !!", $time);
                end
                pop_cnt = pop_cnt + 1;
            end
        end


        #10;
        //report
        $display("*** Random test result ***");
        $display("toal random count = %d", i);
        $display("pass count = %d", pass_cnt);
        $display("fail count = %d", fail_cnt);

        #10;
        $finish;
    end

endmodule
