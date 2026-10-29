`timescale 1ns / 1ps
// 2 단계 : ascii_decoder (명령판) 단독 시험
//  enable 을 1 클럭 주면서 ascii 에 글자를 넣고, 그 뒤 8 클럭 동안 출력마다 1 인 클럭 수를 센다.
//  'r' → run_stop 만 1 번, 'c' → clear 만 1 번, 'u' → mode 만 1 번, 's' → status 만 1 번, '1' · 'R' → 모두 0 번
//  pop 은 글자마다 1 번
module tb_hw2_decoder ();
    reg clk, rst, enable;
    reg [7:0] ascii;
    wire pop, run_stop, clear, mode, status;
    integer err, n_pop, n_r, n_c, n_u, n_s;

    ascii_decoder dut (
        .clk           (clk),
        .rst           (rst),
        .i_enable    (enable),
        .i_ascii (ascii),
        .o_pop      (pop),
        .o_key_run_stop(run_stop),
        .o_key_clear   (clear),
        .o_key_mode    (mode),
        .o_key_status  (status)
    );

    always #5 clk = ~clk;
    always @(posedge clk) begin   // 상승 엣지에서 1 인 클럭 수 (control_unit 이 보는 시점)
        if (pop)      n_pop = n_pop + 1;
        if (run_stop) n_r   = n_r + 1;
        if (clear)    n_c   = n_c + 1;
        if (mode)     n_u   = n_u + 1;
        if (status)   n_s   = n_s + 1;
    end

    task one_char(input [7:0] ch, input integer er, input integer ec, input integer eu, input integer es);
        begin
            n_pop = 0; n_r = 0; n_c = 0; n_u = 0; n_s = 0;
            @(negedge clk); ascii = ch; enable = 1;
            @(negedge clk); enable = 0; ascii = 8'hxx;   // FIFO pop_data 처럼 pop 뒤에는 모르는 값
            repeat (8) @(negedge clk);
            if (n_pop !== 1 || n_r !== er || n_c !== ec || n_u !== eu || n_s !== es) begin
                err = err + 1;
                $display("MISMATCH '%c' (%h) : pop %0d run_stop %0d clear %0d mode %0d status %0d (expect 1 %0d %0d %0d %0d)", ch, ch, n_pop, n_r, n_c, n_u, n_s, er, ec, eu, es);
            end else
                $display("'%c' (%h) : pop %0d run_stop %0d clear %0d mode %0d status %0d", ch, ch, n_pop, n_r, n_c, n_u, n_s);
        end
    endtask

    initial begin
        clk = 0; rst = 1; enable = 0; ascii = 0; err = 0;
        #10 rst = 0;
        one_char("r", 1, 0, 0, 0);
        one_char("c", 0, 1, 0, 0);
        one_char("u", 0, 0, 1, 0);
        one_char("s", 0, 0, 0, 1);
        one_char("1", 0, 0, 0, 0);
        one_char("R", 0, 0, 0, 0);   // 대문자도 받기로 했다면 기대값을 1, 0, 0, 0 으로 바꾼다
        $display("TOTAL MISMATCH = %0d", err);
        $stop;
    end
endmodule
