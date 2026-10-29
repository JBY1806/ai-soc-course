`timescale 1ns / 1ps

module uart (
    input  clk,
    input  rst,
    input  btnR,
    output led,   // tx_busy
    output tx
);

    wire w_b_tick, w_tx_start;

    btn_debounce U_BD_TX_START (
        .clk  (clk),
        .reset(rst),
        .i_btn(btnR),
        .o_btn(w_tx_start)
    );

    uart_tx U_UART_TX (
        .clk     (clk),
        .rst     (rst),
        .tx_start(w_tx_start),
        .tx_data (8'h30),
        .b_tick  (w_b_tick),
        .tx      (tx),
        .tx_busy (led)
    );

    baud_tick_gen U_BAUD_TICK_GEN (
        .clk   (clk),
        .rst   (rst),
        .b_tick(w_b_tick)
    );

endmodule

module uart_tx (
    input        clk,
    input        rst,
    input        tx_start,
    input  [7:0] tx_data,
    input        b_tick,
    output       tx,
    output       tx_busy
);
    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3, WAIT = 4;

    reg [2:0] c_state, n_state;
    reg [2:0] bit_count_reg, bit_count_next;
    reg [7:0] data_reg, data_next;
    reg tx_reg, tx_next;
    reg tx_busy_reg, tx_busy_next;

    //output 
    assign tx = tx_reg;
    assign tx_busy = tx_busy_reg;

    // state SL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state       <= IDLE;
            tx_reg        <= 1'b1;
            tx_busy_reg   <= 1'b0;  // no busy
            bit_count_reg <= 0;
            data_reg      <= 0;
        end else begin
            c_state <= n_state;
            bit_count_reg <= bit_count_next;
            data_reg <= data_next;
            tx_reg <= tx_next;
            tx_busy_reg <= tx_busy_next;
        end
    end

    // next , output
    always @(*) begin
        n_state = c_state;
        bit_count_next = bit_count_reg;
        data_next = data_reg;
        tx_next = tx_reg;
        tx_busy_next = tx_busy_reg;
        case (c_state)
            IDLE: begin
                tx_next = 1'b1;
                if (tx_start) begin
                    data_next = tx_data;
                    n_state = WAIT;
                end
            end
            WAIT: begin
                if (b_tick) begin
                    n_state = START;
                end
            end
            START: begin
                tx_busy_next = 1'b1;
                tx_next = 1'b0;
                if (b_tick) begin
                    bit_count_next = 3'b0;
                    n_state = DATA;
                end
            end
            DATA: begin
                tx_next = data_reg[0];
                if (b_tick) begin
                    //data_next=data_reg>>1;
                    data_next = {1'b0, data_reg[7:1]};
                    if (bit_count_reg == 7) begin
                        n_state = STOP;
                    end else begin
                        bit_count_next = bit_count_reg + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1;
                if (b_tick) begin
                    n_state      = IDLE;
                    tx_busy_next = 1'b0;
                end
            end

        endcase
    end

endmodule



module baud_tick_gen (
    input      clk,
    input      rst,
    output reg b_tick
);
    // 100Mhz -> 9600hz
    parameter F_COUNT = 100_000_000 / 9600;
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick      <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                b_tick      <= 1'b1;
            end else begin
                b_tick <= 1'b0;
            end
        end
    end
endmodule
