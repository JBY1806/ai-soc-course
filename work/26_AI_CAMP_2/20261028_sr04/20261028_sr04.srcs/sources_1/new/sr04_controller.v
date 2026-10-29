`timescale 1ns / 1ps

module sr04_controller #(
    parameter TRIG_US = 11,
    CM_US = 58,
    MAX_CM = 400,
    parameter STOP_US = 10000,
    TIMEOUT_US = 30000
) (
    input        clk,
    input        rst,
    input        i_start,
    input        i_us_tick,
    input        i_echo,
    output       o_trig,
    output [8:0] o_distance,
    output       o_done,
    output       o_busy,
    output       o_tick_en,
    output       o_tick_clr
);
    localparam IDLE = 3'd0, START = 3'd1, WAIT = 3'd2, DIST = 3'd3, STOP = 3'd4;
    // ① 레지스터 · next 선언 : c_state/n_state(3) · c_cnt_tick_us/n_cnt_tick_us(16) · c_cnt_cm/n_cnt_cm(9) · c_distance/n_distance(9) · c_done/n_done · c_echo_sync1 · c_echo_sync2    
    reg [2:0] c_state, n_state;
    reg [15:0] c_cnt_tick_us, n_cnt_tick_us;
    reg [8:0] c_cnt_cm, n_cnt_cm;
    reg [8:0] c_distance, n_distance;
    reg c_done, n_done;
    reg c_echo_sync1, c_echo_sync2;

    // ② 출력 assign 6 줄 : trig = START · busy = IDLE 아님 · tick_en = IDLE 아님 · tick_clr = IDLE · distance = c_distance · done = c_done
    assign o_trig = (c_state == START);
    assign o_busy = (c_state != IDLE);
    assign o_tick_en = (c_state != IDLE);
    assign o_tick_clr = (c_state == IDLE);
    assign o_distance = c_distance;
    assign o_done = c_done;

    // ③ seq always : rst → 0 (state 는 IDLE) / 아니면 c_x <= n_x + 싱크로나이저 2 줄
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state       <= IDLE;
            c_cnt_tick_us <= 0;
            c_cnt_cm      <= 0;
            c_distance    <= 0;
            c_done        <= 0;
            c_echo_sync1  <= 0;
            c_echo_sync2  <= 0;
        end else begin
            c_state       <= n_state;
            c_cnt_tick_us <= n_cnt_tick_us;
            c_cnt_cm      <= n_cnt_cm;
            c_distance    <= n_distance;
            c_done        <= n_done;
            c_echo_sync1  <= i_echo;
            c_echo_sync2  <= c_echo_sync1;
        end
    end

    // ④ comb always : 기본값 n_x = c_x, n_done = 0 → case (c_state) 로 2 단계 표 (ASM 블록 하나 = case 항목 하나)
    always @(*) begin
        n_state       = c_state;
        n_cnt_tick_us = c_cnt_tick_us;
        n_cnt_cm      = c_cnt_cm;
        n_distance    = c_distance;
        n_done        = c_done;

        case (c_state)
            IDLE: begin
                if (i_start) begin
                    n_cnt_tick_us = 0;
                    n_state = START;
                end
            end
            START: begin
                if (i_us_tick) begin
                    if (c_cnt_tick_us == TRIG_US-1) begin
                    n_cnt_tick_us = 0;
                    n_state = WAIT;
                    end else begin
                        n_cnt_tick_us = c_cnt_tick_us + 1;
                    end
                end 
            end
            WAIT: begin
                if (c_echo_sync2 == 1) begin
                    n_cnt_tick_us = 0;
                    n_cnt_cm = 0;
                    n_state = DIST;
                end else if (i_us_tick) begin
                    if (c_cnt_tick_us==TIMEOUT_US-1) begin
                        n_distance=0;
                        n_done=1;
                        n_cnt_tick_us=0;
                        n_state = STOP;
                    end else begin
                        n_cnt_tick_us = c_cnt_tick_us + 1;
                        n_state = WAIT;
                    end
                end
            end
            DIST: begin
                if (!c_echo_sync2) begin
                    n_distance = c_cnt_cm;
                    n_done = 1;
                    n_cnt_tick_us = 0;
                    n_state = STOP;
                end else if (c_cnt_cm> MAX_CM) begin
                        n_distance=0;
                        n_done=1;
                        n_cnt_tick_us=0;
                        n_state = STOP;
                end esle if (i_us_tick) begin
                    if (c_cnt_tick_us == CM_US-1) begin
                        n_cnt_tick_us=0;
                        n_cnt_cm=c_cnt_cm+1;
                        n_state = DIST;
                    end else begin
                        n_cnt_tick_us = c_cnt_tick_us+1;
                        n_state = DIST;
                    end
                end
                    
                end else begin
                    n_distance = c_cnt_cm;
                    n_done = 1;
                    n_cnt_tick_us = 0;
                end
            end
            STOP:
            default: n_state = IDLE;

        endcase


    end
endmodule
