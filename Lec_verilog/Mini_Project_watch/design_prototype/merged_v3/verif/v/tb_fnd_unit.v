`timescale 1ns / 1ps
// [검증 TB] SW2_FND_CONTROLLER (정안성) — 핀(fnd_com · fnd_font)에서 8 슬롯 전부 해독해 기대값과 비교
// 기대값은 TB 안의 독립 7세그먼트 표 + 슬롯 규칙으로 계산 (DUT 내부 신호 안 봄)
module tb_fnd_unit ();
    reg clk, rst, clk_remake;
    reg [6:0] msec; reg [5:0] sec, min, hour;   // hour 6비트 (Top 과 같게, 타이머 분)
    reg disp, sw0, sw2; reg [1:0] cursor;
    wire [3:0] fnd_com; wire [7:0] fnd_font;

    SW2_FND_CONTROLLER #(.HOUR_BIT_WIDTH(6)) dut (
        .i_clk_remake(clk_remake), .i_cursor(cursor), .i_clk(clk), .i_reset(rst),
        .i_msec(msec), .i_sec(sec), .i_min(min), .i_hour(hour),
        .i_sw_display_mode(disp), .i_btn_R(1'b0), .i_btn_L(1'b0), .i_sw_0(sw0), .i_sw_2(sw2),
        .o_fnd_com(fnd_com), .o_fnd_data(fnd_font));

    always #5 clk = ~clk;
    // clk_remake: 4 클럭마다 1클럭 펄스
    integer rc;
    always @(posedge clk) begin
        if (rst) begin rc <= 0; clk_remake <= 0; end
        else begin rc <= (rc == 3) ? 0 : rc + 1; clk_remake <= (rc == 3); end
    end

    integer err, v, s, c, slot, n_on;
    reg [7:0] seg [0:15];
    reg [3:0] d_msec1, d_msec10, d_sec1, d_sec10, d_min1, d_min10, d_hour1, d_hour10;
    reg [3:0] g1, g2, g3, g4;   // 보이는 그룹의 네 자리 (ds1..ds4)
    reg       dot, blank_cond;
    reg [3:0] exp_code; reg [7:0] exp_font; reg [3:0] exp_com;
    // 값 세트: 각 자리 0~9 를 다 거치게
    reg [6:0] v_msec [0:9]; reg [5:0] v_sec [0:9]; reg [5:0] v_min [0:9]; reg [5:0] v_hour [0:9];

    initial begin
        seg[0]=8'hC0; seg[1]=8'hF9; seg[2]=8'hA4; seg[3]=8'hB0; seg[4]=8'h99; seg[5]=8'h92; seg[6]=8'h82; seg[7]=8'hF8; seg[8]=8'h80; seg[9]=8'h90;
        seg[13]=8'hFF; seg[14]=8'h7F; seg[15]=8'hFF;
        v_msec[0]=0;  v_sec[0]=0;  v_min[0]=0;  v_hour[0]=0;
        v_msec[1]=99; v_sec[1]=59; v_min[1]=59; v_hour[1]=59;
        v_msec[2]=12; v_sec[2]=34; v_min[2]=56; v_hour[2]=23;
        v_msec[3]=50; v_sec[3]=5;  v_min[3]=10; v_hour[3]=12;
        v_msec[4]=49; v_sec[4]=48; v_min[4]=47; v_hour[4]=46;
        v_msec[5]=78; v_sec[5]=17; v_min[5]=38; v_hour[5]=1;
        v_msec[6]=63; v_sec[6]=26; v_min[6]=29; v_hour[6]=30;
        v_msec[7]=85; v_sec[7]=52; v_min[7]=41; v_hour[7]=9;
        v_msec[8]=7;  v_sec[8]=40; v_min[8]=3;  v_hour[8]=18;
        v_msec[9]=31; v_sec[9]=9;  v_min[9]=22; v_hour[9]=45;
        clk = 0; rst = 1; msec = 0; sec = 0; min = 0; hour = 0; disp = 0; sw0 = 0; sw2 = 0; cursor = 3; err = 0;
        #22 rst = 0;
        // 슬롯 순서 확인: fnd_com 이 1110,1101,1011,0111 순으로 돎 (슬롯 4~7 도 같은 com)
        @(posedge clk_remake); #2;
        for (s = 0; s < 16; s = s + 1) begin
            @(posedge clk_remake); #2;
            exp_com = (dut.w_sel[1:0] == 0) ? 4'b1110 : (dut.w_sel[1:0] == 1) ? 4'b1101 : (dut.w_sel[1:0] == 2) ? 4'b1011 : 4'b0111;
            if (fnd_com !== exp_com) begin err = err + 1; $display("FAIL com %b sel %0d", fnd_com, dut.w_sel); end
            n_on = (fnd_com[0]==0) + (fnd_com[1]==0) + (fnd_com[2]==0) + (fnd_com[3]==0);
            if (n_on !== 1) begin err = err + 1; $display("FAIL com not one-hot %b", fnd_com); end
        end

        // 값 x 스위치 조합 전수: disp(2) x {sw2,sw0}(4) x cursor(4) x 값세트(10) = 320 조합 x 8 슬롯
        for (v = 0; v < 10; v = v + 1) begin
            msec = v_msec[v]; sec = v_sec[v]; min = v_min[v]; hour = v_hour[v];
            d_msec1 = msec % 10; d_msec10 = msec / 10; d_sec1 = sec % 10; d_sec10 = sec / 10;
            d_min1 = min % 10; d_min10 = min / 10; d_hour1 = hour % 10; d_hour10 = hour / 10;
            dot = (msec >= 50);
            for (c = 0; c < 16; c = c + 1) begin
                disp = c[0]; sw0 = c[1]; sw2 = c[2]; cursor = c[3] ? 2'd2 + c[1] : {1'b0, c[2]} ; // cursor 0..3 섞기
                // cursor 를 c 의 비트로 분리해 4 값 모두 거치게
                cursor = c[3:2]; sw2 = c[1]; sw0 = (c[0] & ~disp) ; disp = c[0] ^ c[1];
                blank_cond = (sw2 == 1) && (disp == 1) && (sw0 == 0) && dot;
                if (disp == 0) begin g1 = d_msec1; g2 = d_msec10; g3 = d_sec1; g4 = d_sec10; end
                else begin g1 = d_min1; g2 = d_min10; g3 = d_hour1; g4 = d_hour10; end
                if (blank_cond) begin
                    if (cursor == 0) g1 = 4'hd; else if (cursor == 1) g2 = 4'hd; else if (cursor == 2) g3 = 4'hd;
                end
                // 8 슬롯을 한 바퀴 (슬롯 0 부터 맞추기)
                @(posedge clk_remake); #2;
                while (dut.w_sel != 0) begin @(posedge clk_remake); #2; end
                for (slot = 0; slot < 8; slot = slot + 1) begin
                    case (slot)
                        0: exp_code = g1; 1: exp_code = g2; 2: exp_code = g3; 3: exp_code = g4;
                        6: exp_code = dot ? 4'hf : 4'he;   // dot 모듈: msec >= 50 이면 1 = 점 OFF (수업 판과 같음)
                        default: exp_code = 4'hf;
                    endcase
                    exp_font = seg[exp_code];
                    exp_com = (slot[1:0] == 0) ? 4'b1110 : (slot[1:0] == 1) ? 4'b1101 : (slot[1:0] == 2) ? 4'b1011 : 4'b0111;
                    if (fnd_font !== exp_font || fnd_com !== exp_com) begin
                        err = err + 1;
                        $display("FAIL v%0d disp%b sw0%b sw2%b cur%0d slot%0d: font %h com %b (exp %h %b) [%0d:%0d:%0d.%0d]", v, disp, sw0, sw2, cursor, slot, fnd_font, fnd_com, exp_font, exp_com, hour, min, sec, msec);
                    end
                    @(posedge clk_remake); #2;
                end
            end
        end
        // 입력이 바뀌면 같은 슬롯 안에서도 바로 바뀜 (조합 경로)
        disp = 0; sw2 = 0; cursor = 3; msec = 7; #1;
        while (dut.w_sel != 0) begin @(posedge clk_remake); #2; end
        if (fnd_font !== seg[7]) begin err = err + 1; $display("FAIL comb path"); end
        msec = 8; #1;
        if (fnd_font !== seg[8]) begin err = err + 1; $display("FAIL comb path update"); end
        $display("TOTAL MISMATCH = %0d  (160 combos x 8 slots + scan order)", err);
        $finish;
    end
endmodule
