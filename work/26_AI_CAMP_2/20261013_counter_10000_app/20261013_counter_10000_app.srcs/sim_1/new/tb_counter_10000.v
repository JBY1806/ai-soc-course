`timescale 1ns / 1ps

module tb_counter_10000 ();

    parameter BD_PUSH_TIME = 1000;

    reg clk, reset, btnU, btnL, btnR;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;

    counter_10000 dut (
        .clk(clk),
        .reset(reset),
        .btnU(btnU),     //mode
        .btnL(btnL),     //clear
        .btnR(btnR),     //run_stop
        .fnd_com(fnd_com),
        .fnd_font(fnd_font)
    );

    // gen 100MHz clock
    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        reset = 1;
        btnU  = 0;
        btnL  = 0;
        btnR  = 0;
        #10;
        reset = 0;

        // senario 0 : runstop btn 1 push / pop
        btnR  = 1;
        repeat (BD_PUSH_TIME)
        @(posedge clk); // 1000클럭 준 이유: q_reg 8칸(SIPO)이 1 MHz(100클럭)마다 한 칸씩 밀림 → 8 x 100 = 800클럭 필요, 여유 두고 1000 
        btnR = 0;

        // run state
        repeat (3) begin
            #(10_000_000 * 10);
        end

        // run to stop state
        btnR = 1;
        repeat (BD_PUSH_TIME)
        @(posedge clk);  // 1000클럭 준 이유: q_reg 8칸(SIPO)이 1 MHz(100클럭)마다 한 칸씩 밀림 → 8 x 100 = 800클럭 필요, 여유 두고 1000 
        btnR = 0;

        // 버튼 사이 쉬는 구간
        repeat (BD_PUSH_TIME) @(posedge clk);

        // U 누름
        btnU = 1;
        repeat (BD_PUSH_TIME)
        @(posedge clk); // 1000클럭 준 이유: q_reg 8칸(SIPO)이 1 MHz(100클럭)마다 한 칸씩 밀림 → 8 x 100 = 800클럭 필요, 여유 두고 1000
        btnU = 0;

        // 간격
        repeat (BD_PUSH_TIME) @(posedge clk);

        // R 누름
        btnR = 1;
        repeat (BD_PUSH_TIME)
        @(posedge clk); // 1000클럭 준 이유: q_reg 8칸(SIPO)이 1 MHz(100클럭)마다 한 칸씩 밀림 → 8 x 100 = 800클럭 필요, 여유 두고 1000 
        btnR = 0;

        // run state 350 ms 대기:  0003 → 0002 → 0001 → 0000 다운
        repeat (3) begin
            #(10_000_000 * 10);
        end
        #(5_000_000 * 10);

        // ⑥ RUN 중 L 누름 → 무시됨, 0000 유지
        btnL = 1;
        repeat (BD_PUSH_TIME) @(posedge clk);
        btnL = 0;

        // ⑦ 200 ms 대기 → 9999 → 9998
        repeat (2) begin
            #(10_000_000 * 10);
        end

        // ⑧ R 누름 → STOP
        btnR = 1;
        repeat (BD_PUSH_TIME) @(posedge clk);
        btnR = 0;

        // ⑨ 간격
        repeat (BD_PUSH_TIME) @(posedge clk);

        // ⑩ L 누름 → CLEAR → 0000
        btnL = 1;
        repeat (BD_PUSH_TIME) @(posedge clk);
        btnL = 0;

        // ⑪ 간격
        repeat (BD_PUSH_TIME) @(posedge clk);

        $stop;
    end

endmodule
