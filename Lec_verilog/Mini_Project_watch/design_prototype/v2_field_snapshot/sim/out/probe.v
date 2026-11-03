module probe;
  initial begin
    #1;
    $display("wt F_COUNT=%0d sw F_COUNT=%0d", tb_stopwatch_watch.dut.U_WATCH_DATAPATH.U_TICK_GEN_100HZ.F_COUNT, tb_stopwatch_watch.dut.U_STOPWATCH_DATAPATH.U_TICK_GEN_100HZ.F_COUNT);
  end
  always @(tb_stopwatch_watch.wt_sec) if (tb_stopwatch_watch.wt_sec % 20 == 0) $display("%0t  %0d:%0d:%0d", $time, tb_stopwatch_watch.wt_hour, tb_stopwatch_watch.wt_min, tb_stopwatch_watch.wt_sec);
endmodule
