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

    localparam IDLE = 0, START = 1, BIT0 = 2, BIT1 = 3, BIT2 = 4, BIT3 = 5;
    localparam BIT4 = 6, BIT5 = 7, BIT6 = 8, BIT7 = 9, STOP = 10, WAIT = 11;

    reg [3:0] c_state, n_state;
    reg tx_reg, tx_next;
    reg tx_busy_reg, tx_busy_next;

    //output 
    assign tx = tx_reg;
    assign tx_busy = tx_busy_reg;

    // state SL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            tx_reg <= 1'b1;
            tx_busy_reg <= 1'b0;  // no busy
        end else begin
            c_state <= n_state;
            tx_reg <= tx_next;
            tx_busy_reg <= tx_busy_next;
        end
    end

    // next , output
    always @(*) begin
        n_state = c_state;
        tx_next = tx_reg;
        tx_busy_next = tx_busy_reg;
        case (c_state)
            IDLE: begin
                tx_next = 1'b1;
                if (tx_start) begin
                    n_state = WAIT;
                end
            end
            WAIT: begin
                if(b_tick) begin
                    n_state = START;
                end
            end
            START: begin
                tx_busy_next = 1'b1;
                tx_next = 1'b0;
                if (b_tick) begin
                    n_state = BIT0;
                end
            end
            BIT0: begin
                tx_next = tx_data[0];
                if (b_tick) begin
                    n_state = BIT1;
                end
            end
            BIT1: begin
                tx_next = tx_data[1];
                if (b_tick) begin
                    n_state = BIT2;
                end
            end
            BIT2: begin
                tx_next = tx_data[2];
                if (b_tick) begin
                    n_state = BIT3;
                end
            end
            BIT3: begin
                tx_next = tx_data[3];
                if (b_tick) begin
                    n_state = BIT4;
                end
            end
            BIT4: begin
                tx_next = tx_data[4];
                if (b_tick) begin
                    n_state = BIT5;
                end
            end
            BIT5: begin
                tx_next = tx_data[5];
                if (b_tick) begin
                    n_state = BIT6;
                end
            end
            BIT6: begin
                tx_next = tx_data[6];
                if (b_tick) begin
                    n_state = BIT7;
                end
            end
            BIT7: begin
                tx_next = tx_data[7];
                if (b_tick) begin
                    n_state = STOP;
                end
            end
            STOP: begin
                tx_next = 1;
                if (b_tick) begin
                    n_state      = IDLE;
                    tx_busy_next = 1'b0;  // done
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
