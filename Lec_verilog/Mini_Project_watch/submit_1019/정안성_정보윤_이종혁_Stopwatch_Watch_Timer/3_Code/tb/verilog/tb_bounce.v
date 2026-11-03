`timescale 1ns/1ps
// 디바운서 샘플 박자 비교: 같은 튀는 버튼 입력을 1 MHz 판 · 4 kHz 판에 동시에 넣고 o_btn 개수를 센다 (10/18)
// 버튼 모델: 누를 때 · 뗄 때 접점이 0.5 ~ 3 ms 동안 튐 (조각 20 ~ 400 us), 누른 채 150 ms 유지, 뗀 뒤 150 ms
module tb_bounce;
  reg clk = 0, rst = 1, btn = 0;
  always #5 clk = ~clk;
  wire tick_1m, tick_4k, p_1m, p_4k;
  clock_tick_generator #(.CLK_FRQ(1_000_000)) U_GEN_1M (.i_clk(clk), .i_rst(rst), .o_clk_4khz(tick_1m));
  clock_tick_generator #(.CLK_FRQ(4000))      U_GEN_4K (.i_clk(clk), .i_rst(rst), .o_clk_4khz(tick_4k));
  btn_debounce U_BD_1M (.i_clk(clk), .i_rst(rst), .i_clk_4khz(tick_1m), .i_btn(btn), .o_btn(p_1m));
  btn_debounce U_BD_4K (.i_clk(clk), .i_rst(rst), .i_clk_4khz(tick_4k), .i_btn(btn), .o_btn(p_4k));
  integer n_1m = 0, n_4k = 0, k, j, nseg, seed, d, before_1m, before_4k, bad_1m = 0, bad_4k = 0;
  always @(posedge clk) begin
    if (p_1m) n_1m = n_1m + 1;
    if (p_4k) n_4k = n_4k + 1;
  end
  initial begin
    seed = 1018;
    #1000 rst = 0;
    for (k = 0; k < 20; k = k + 1) begin
      before_1m = n_1m; before_4k = n_4k;
      // 누를 때 튐
      nseg = 4 + ({$random(seed)} % 8);
      for (j = 0; j < nseg; j = j + 1) begin
        btn = ~btn; d = 20_000 + ({$random(seed)} % 380_000); #(d);
      end
      btn = 1; #(150_000_000);
      // 뗄 때 튐
      nseg = 4 + ({$random(seed)} % 8);
      for (j = 0; j < nseg; j = j + 1) begin
        btn = ~btn; d = 20_000 + ({$random(seed)} % 380_000); #(d);
      end
      btn = 0; #(150_000_000);
      if (n_1m - before_1m != 1) bad_1m = bad_1m + 1;
      if (n_4k - before_4k != 1) bad_4k = bad_4k + 1;
      $display("press %2d : 1MHz o_btn %0d  |  4kHz o_btn %0d", k + 1, n_1m - before_1m, n_4k - before_4k);
    end
    $display("TOTAL press 20 : 1MHz o_btn = %0d (wrong presses %0d)  |  4kHz o_btn = %0d (wrong presses %0d)", n_1m, bad_1m, n_4k, bad_4k);
    $finish;
  end
endmodule
