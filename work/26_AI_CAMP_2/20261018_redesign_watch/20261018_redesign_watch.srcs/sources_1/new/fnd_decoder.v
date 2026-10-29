`timescale 1ns / 1ps

module fnd_decoder (
    input      [3:0] i_bcd,
    output reg [7:0] o_fnd_font
);

    always @(i_bcd) begin
        case (i_bcd)
            4'h0: o_fnd_font = 8'hC0;
            4'h1: o_fnd_font = 8'hF9;
            4'h2: o_fnd_font = 8'hA4;
            4'h3: o_fnd_font = 8'hB0;
            4'h4: o_fnd_font = 8'h99;
            4'h5: o_fnd_font = 8'h92;
            4'h6: o_fnd_font = 8'h82;
            4'h7: o_fnd_font = 8'hF8;
            4'h8: o_fnd_font = 8'h80;
            4'h9: o_fnd_font = 8'h90;
            4'ha: o_fnd_font = 8'h88;  // A
            4'hb: o_fnd_font = 8'h83;  // b
            4'hc: o_fnd_font = 8'hC6;  // C
            4'hd:
            o_fnd_font = 8'hA1;  // d   ← 시계 커서 점멸(7-6)을 붙일 때 8'hFF(빈칸)로 바꿈
            4'he: o_fnd_font = 8'h7F;  // 점만 켬
            4'hf: o_fnd_font = 8'hFF;  // 전부 끔
            default:
            o_fnd_font = 8'hFF;  // 잘못된 값 = 전부 끔 (수업 방식)
        endcase
    end

endmodule

module digit_splitter #(
    parameter WIDTH = 7
) (
    input [WIDTH-1:0] i_value,
    output [3:0] o_digit1,
    output [3:0] o_digit10
);

    assign o_digit1  = i_value % 10;
    assign o_digit10 = i_value / 10;

endmodule

module decoder_2x4 (
    input [1:0] i_sel,
    output reg [3:0] o_fnd_com
);

    always @(*) begin
        case (i_sel)
            2'b00:   o_fnd_com = 4'b1110;
            2'b01:   o_fnd_com = 4'b1101;
            2'b10:   o_fnd_com = 4'b1011;
            2'b11:   o_fnd_com = 4'b0111;
            default: o_fnd_com = 4'b1111;
        endcase
    end

endmodule

module clock_tick_generator #(
    parameter CLK_FRQ = 1000
) (
    input i_clk,
    input i_rst,
    output reg o_clk_4khz
);

    parameter FCOUNT = (100_000_000 / CLK_FRQ);
    reg [$clog2(FCOUNT)-1:0] r_counter;

    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            r_counter  <= 0;
            o_clk_4khz <= 0;
        end else begin
            r_counter <= r_counter + 1;
            if (r_counter == FCOUNT - 1) begin
                r_counter  <= 0;
                o_clk_4khz <= 1;
            end else begin
                o_clk_4khz <= 0;
            end
        end
    end

endmodule

module counter8 (
    input i_clk_4khz,
    input i_rst,
    output reg [2:0] o_scan_sel
);

    always @(posedge i_clk_4khz, posedge i_rst) begin
        if (i_rst) begin
            o_scan_sel <= 0;
        end else begin
            o_scan_sel <= o_scan_sel + 1;
        end
    end

endmodule

module mux_8x1 #(
    parameter WIDTH = 4
) (
    input wire [      2:0] i_sel,
    input wire [WIDTH-1:0] i_d0,
    input wire [WIDTH-1:0] i_d1,
    input wire [WIDTH-1:0] i_d2,
    input wire [WIDTH-1:0] i_d3,
    input wire [WIDTH-1:0] i_d4,
    input wire [WIDTH-1:0] i_d5,
    input wire [WIDTH-1:0] i_d6,
    input wire [WIDTH-1:0] i_d7,

    output reg [WIDTH-1:0] o_data
);

    always @(*) begin
        case (i_sel)
            3'b000:  o_data = i_d0;
            3'b001:  o_data = i_d1;
            3'b010:  o_data = i_d2;
            3'b011:  o_data = i_d3;
            3'b100:  o_data = i_d4;
            3'b101:  o_data = i_d5;
            3'b110:  o_data = i_d6;
            3'b111:  o_data = i_d7;
            default: o_data = {WIDTH{1'b0}};
        endcase
    end

endmodule

module dot (
    input [6:0] i_disp_msec,
    output o_blink_off
);
    assign o_blink_off = (i_disp_msec >= 50) ? 1 : 0;

endmodule

module SW2_ANODE_CHOICE (
    input       i_set_sw2,
    input       i_disp_mode,
    input       i_sel_wt,
    input [1:0] i_wt_cursor,
    input       i_blink_off,
    input [3:0] i_an0,
    input [3:0] i_an1,
    input [3:0] i_an2,
    input [3:0] i_an3,

    output [3:0] o_an0,
    output [3:0] o_an1,
    output [3:0] o_an2,
    output [3:0] o_an3
);
    reg [15:0] r_an;
endmodule



module tick_gen_100hz (
    input      i_clk,
    input      i_rst,
    output reg o_tick_10ms
);

    parameter F_COUNT = 100_000_000 / 100;

    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
            counter_reg <= 0;
            o_tick_10ms <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                o_tick_10ms <= 1'b1;
            end else begin
                o_tick_10ms <= 1'b0;
            end
        end
    end

endmodule

module timer_control_unit (
    input i_clk,
    input i_rst,
    input i_tm_btn_R,
    input i_tm_btn_L,
    input i_tm_btn_U,
    input i_tm_btn_D,
    input i_tm_zero,
    output reg o_tm_run,
    output reg o_tm_alarm,
    output reg o_tm_clear,
    output reg o_tm_add,
    output reg [1:0] o_tm_amount
);

    parameter SET = 2'b00, RUN = 2'b01, ALARM = 2'b10;
    reg [1:0] c_state, n_state;

    // 상태 업데이트 
    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            c_state <= SET;
        end else begin
            c_state <= n_state;
        end
    end

    // 다음상태, 출력 로직
    always @(*) begin
        n_state     = c_state;
        o_tm_run    = 0;  //무어
        o_tm_alarm  = 0;  //무어
        o_tm_clear  = 0;  //밀리 
        o_tm_add    = 0;  //밀리
        o_tm_amount = 0;  //밀리
        case (c_state)
            SET: begin
                o_tm_run   = 1'b0;
                o_tm_alarm = 1'b0;
                if (i_tm_btn_L==1'b1) begin
                    if (i_tm_zero == 1'b0) begin
                        n_state = RUN;
                    end
                end else begin
                    if (i_tm_btn_U) begin
                        o_tm_add = 1;
                        o_tm_amount = 0;
                    end else if (i_tm_btn_R) begin
                        o_tm_add = 1;
                        o_tm_amount = 1;
                    end else if (i_tm_btn_D) begin
                        o_tm_add = 1;
                        o_tm_amount = 2;
                    end
                end
            end
            RUN: begin
                o_tm_run   = 1'b1;
                o_tm_alarm = 1'b0;
                if (i_tm_btn_L) begin
                    n_state = SET;
                end else if (i_tm_zero) begin
                    n_state = ALARM;
                end
            end
            ALARM: begin
                o_tm_alarm = 1;
                if (i_tm_btn_U | i_tm_btn_R | i_tm_btn_L | i_tm_btn_D) begin
                    n_state = SET;
                end
            end
        endcase

    end

endmodule
