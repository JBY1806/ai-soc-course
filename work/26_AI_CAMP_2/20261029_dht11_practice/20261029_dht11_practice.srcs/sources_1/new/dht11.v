`timescale 1ns / 1ps

// top_dht11 : 버튼 (btnR) 한 번에 DHT11 을 한 번 읽어 FND 에 습도 · 온도 정수 (예 4525 = 45 % · 25 ℃) 표시
module top_dht11 (
    input        clk,
    input        rst,
    input        btnR,
    output [3:0] fnd_com,
    output [7:0] fnd_font,
    output [15:0] led,           // 습도 정수 (위 8) · 온도 정수 (아래 8) 2 진 — 보드에서 바로 확인용
    inout        dht11_io
);
    wire        w_start, w_us_tick, w_busy, w_done, w_valid;
    wire [15:0] w_hum, w_temp;
    wire [13:0] w_fnd_data = w_hum[15:8] * 7'd100 + w_temp[15:8];   // 습도 정수 × 100 + 온도 정수 (0 ~ 9999)

    btn_debounce U_BD (                 // 버튼 → 1 클럭 펄스 (SR04 프로젝트 것)
        .clk  (clk),
        .reset(rst),
        .i_btn(btnR),
        .o_btn(w_start)
    );

    tick_gen_1us U_TICK (               // 1 us tick (SR04 프로젝트 것, 늘 켜 둠)
        .clk     (clk),
        .rst     (rst),
        .i_enable(1'b1),
        .i_clear (1'b0),
        .o_tick  (w_us_tick)
    );

    dht11_controller U_DHT11_CNTL (
        .clk          (clk),
        .rst          (rst),
        .i_start      (w_start),        // start trigger
        .i_us_tick    (w_us_tick),
        .dht11_io     (dht11_io),       // single wire, for half duplexing
        .o_busy       (w_busy),
        .o_done       (w_done),
        .o_valid      (w_valid),        // check sum ok
        .o_humidity   (w_hum),
        .o_temperature(w_temp)
    );

    fnd_controller U_FND (              // SR04 프로젝트 것 (14 비트 0 ~ 9999)
        .clk     (clk),
        .reset   (rst),
        .fnd_data(w_fnd_data),
        .fnd_com (fnd_com),
        .fnd_font(fnd_font)
    );

    assign led = {w_hum[15:8], w_temp[15:8]};

endmodule


// dht11_controller : 버튼 한 번 (i_start) 에 DHT11 을 한 번 읽어 습도 · 온도 (각 16 비트) 를 내는 FSM.
//   틱 카운트 방식 — 1 us tick 이 올 때마다 싱크로나이저를 거친 선 값을 보고
//   "아직 그대로면 cnt + 1, 바뀌었으면 다음 상태" 로 간다.
module dht11_controller #(
    parameter START_US   = 19000,  // 시작 신호 Low 길이 (us) — 데이터시트 최소 18 ms + 여유
    parameter TIMEOUT_US = 100,    // 기다리는 상태에서 이만큼 안 바뀌면 error
    parameter BIT_TH_US  = 40,     // BIT 에서 센 High 길이가 이보다 크면 "1"
    parameter STOP_US    = 50      // 마지막 비트 뒤 쉬는 시간 (판서 "≥ 50 us")
) (
    input         clk,
    input         rst,
    input         i_start,         // 버튼 디바운서 출력 (1 클럭 펄스) — 측정 시작
    input         i_us_tick,       // 1 us 마다 1 클럭 (tick_gen_1us)
    inout         dht11_io,        // 센서와 한 선 — inout = 읽기 · 쓰기 둘 다 하는 포트
    output        o_busy,          // 측정 중 (IDLE 가 아니면 1)
    output        o_done,          // 측정 끝 (정상이든 error 든) 1 클럭
    output        o_valid,         // 마지막 측정이 체크섬까지 맞았나 (1 = 값 믿어도 됨)
    output [15:0] o_humidity,      // {습도 정수 8, 소수 8}
    output [15:0] o_temperature    // {온도 정수 8, 소수 8}
);
    // ⓪ 상태 8 개 (상태도 이름 그대로) → 3 비트
    localparam IDLE = 3'd0, START = 3'd1, WAIT = 3'd2, SYNC_L = 3'd3,
               SYNC_H = 3'd4, DATA_SYNC = 3'd5, BIT = 3'd6, STOP = 3'd7;

    // 레지스터 (c_ = 지금 FF 값, n_ = 다음 값)
    reg [2:0]  c_state, n_state;
    reg [14:0] c_cnt_us, n_cnt_us;     // 지금 상태에서 tick 몇 번 셌나 (최대 19,000 → 15 비트)
    reg [5:0]  c_bit_cnt, n_bit_cnt;   // 받은 비트 수 0 ~ 39
    reg [39:0] c_data, n_data;         // 받은 40 비트 (습 정수 · 습 소수 · 온 정수 · 온 소수 · 체크섬)
    reg        c_err, n_err;           // error 났나 (timeout)
    reg        c_done, n_done;         // 끝 펄스
    reg        c_valid, n_valid;       // 값 믿을 만한가
    reg [15:0] c_hum, n_hum, c_temp, n_temp;   // 출력 (체크섬 맞을 때만 새 값)
    reg        c_io_sync1, c_io_sync2; // ② 싱크로나이저 FF 2 개

    // ⑥ 체크섬 합 — 앞 4 바이트 합의 아래 8 비트 (8 비트 wire 라 넘친 윗자리는 버려짐)
    wire [7:0] w_sum = c_data[39:32] + c_data[31:24] + c_data[23:16] + c_data[15:8];

    // ① 3 상태 버퍼 — START 동안만 선을 0 으로, 나머지는 놓기 (1'bz = High-Z, 풀업이 1 로 올림)
    assign dht11_io      = (c_state == START) ? 1'b0 : 1'bz;

    // ③ 출력
    assign o_busy        = (c_state != IDLE);
    assign o_done        = c_done;
    assign o_valid       = c_valid;
    assign o_humidity    = c_hum;
    assign o_temperature = c_temp;

    // ④ 레지스터 갱신 + 싱크로나이저
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state    <= IDLE;
            c_cnt_us   <= 0;
            c_bit_cnt  <= 0;
            c_data     <= 0;
            c_err      <= 0;
            c_done     <= 0;
            c_valid    <= 0;
            c_hum      <= 0;
            c_temp     <= 0;
            c_io_sync1 <= 1'b1;            // 선은 쉴 때 1
            c_io_sync2 <= 1'b1;
        end else begin
            c_state    <= n_state;
            c_cnt_us   <= n_cnt_us;
            c_bit_cnt  <= n_bit_cnt;
            c_data     <= n_data;
            c_err      <= n_err;
            c_done     <= n_done;
            c_valid    <= n_valid;
            c_hum      <= n_hum;
            c_temp     <= n_temp;
            c_io_sync1 <= dht11_io;        // ② 바깥 선 → FF 1 → FF 2
            c_io_sync2 <= c_io_sync1;
        end
    end

    // ⑤ 다음 값 계산 (ASM 그대로) — 모든 판정은 i_us_tick 이 올 때만 (틱 카운트)
    always @(*) begin
        n_state   = c_state;
        n_cnt_us  = c_cnt_us;
        n_bit_cnt = c_bit_cnt;
        n_data    = c_data;
        n_err     = c_err;
        n_done    = 1'b0;                  // done 은 1 클럭 펄스
        n_valid   = c_valid;
        n_hum     = c_hum;
        n_temp    = c_temp;
        case (c_state)
            IDLE: begin
                if (i_start) begin
                    n_cnt_us = 0;
                    n_data   = 0;
                    n_err    = 1'b0;
                    n_state  = START;
                end
            end
            START: begin                   // 선 0 으로 19 ms
                if (i_us_tick) begin
                    if (c_cnt_us == START_US - 1) begin
                        n_cnt_us = 0;
                        n_state  = WAIT;
                    end else begin
                        n_cnt_us = c_cnt_us + 1;
                    end
                end
            end
            WAIT: begin                    // 선 놓고 센서가 0 으로 끌길 기다림
                if (i_us_tick) begin
                    if (c_io_sync2 == 1'b0) begin
                        n_cnt_us = 0;
                        n_state  = SYNC_L;
                    end else if (c_cnt_us == TIMEOUT_US - 1) begin
                        n_err = 1'b1; n_cnt_us = 0; n_state = STOP;
                    end else begin
                        n_cnt_us = c_cnt_us + 1;
                    end
                end
            end
            SYNC_L: begin                  // 응답 0 (약 80 us) → 1 을 기다림
                if (i_us_tick) begin
                    if (c_io_sync2 == 1'b1) begin
                        n_cnt_us = 0;
                        n_state  = SYNC_H;
                    end else if (c_cnt_us == TIMEOUT_US - 1) begin
                        n_err = 1'b1; n_cnt_us = 0; n_state = STOP;
                    end else begin
                        n_cnt_us = c_cnt_us + 1;
                    end
                end
            end
            SYNC_H: begin                  // 응답 1 (약 80 us) → 0 을 기다림 (데이터 시작)
                if (i_us_tick) begin
                    if (c_io_sync2 == 1'b0) begin
                        n_cnt_us  = 0;
                        n_bit_cnt = 0;
                        n_state   = DATA_SYNC;
                    end else if (c_cnt_us == TIMEOUT_US - 1) begin
                        n_err = 1'b1; n_cnt_us = 0; n_state = STOP;
                    end else begin
                        n_cnt_us = c_cnt_us + 1;
                    end
                end
            end
            DATA_SYNC: begin               // 비트 앞 0 (약 50 us) → 1 을 기다림
                if (i_us_tick) begin
                    if (c_io_sync2 == 1'b1) begin
                        n_cnt_us = 0;
                        n_state  = BIT;
                    end else if (c_cnt_us == TIMEOUT_US - 1) begin
                        n_err = 1'b1; n_cnt_us = 0; n_state = STOP;
                    end else begin
                        n_cnt_us = c_cnt_us + 1;
                    end
                end
            end
            BIT: begin                     // 1 길이를 셈 → 0 이 되면 "0" / "1" 판정
                if (i_us_tick) begin
                    if (c_io_sync2 == 1'b0) begin
                        n_data   = {c_data[38:0], (c_cnt_us > BIT_TH_US)};   // 왼쪽으로 밀고 새 비트
                        n_cnt_us = 0;
                        if (c_bit_cnt == 39) begin
                            n_state = STOP;
                        end else begin
                            n_bit_cnt = c_bit_cnt + 1;
                            n_state   = DATA_SYNC;
                        end
                    end else if (c_cnt_us == TIMEOUT_US - 1) begin
                        n_err = 1'b1; n_cnt_us = 0; n_state = STOP;
                    end else begin
                        n_cnt_us = c_cnt_us + 1;
                    end
                end
            end
            STOP: begin                    // 50 us 쉬고 체크섬 비교 → IDLE
                if (i_us_tick) begin
                    if (c_cnt_us == STOP_US - 1) begin
                        n_done   = 1'b1;
                        n_cnt_us = 0;
                        n_state  = IDLE;
                        if (!c_err && (w_sum == c_data[7:0])) begin
                            n_valid = 1'b1;
                            n_hum   = c_data[39:24];
                            n_temp  = c_data[23:8];
                        end else begin
                            n_valid = 1'b0;
                        end
                    end else begin
                        n_cnt_us = c_cnt_us + 1;
                    end
                end
            end
            default: n_state = IDLE;
        endcase
    end
endmodule
