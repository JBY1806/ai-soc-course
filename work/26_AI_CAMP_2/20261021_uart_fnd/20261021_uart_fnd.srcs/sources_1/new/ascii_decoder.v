`timescale 1ns / 1ps

module ascii_decoder (
    input        clk,
    input        rst,
    input        rx_done,
    input  [7:0] rx_data,
    output [3:0] fnd_data
);

    reg [3:0] fnd_data_reg, fnd_data_next;
    assign fnd_data = fnd_data_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            fnd_data_reg <= 4'b0;
        end else begin
            fnd_data_reg <= fnd_data_next;
        end
    end

    always @(*) begin
        fnd_data_next = fnd_data_reg;
        if (rx_done) begin
            if (rx_data >= 8'h30 && rx_data <= 8'h39) begin
                fnd_data_next = rx_data[3:0];
            end else if (rx_data >= 8'h41 && rx_data <= 8'h46) begin
                fnd_data_next = rx_data[3:0] + 9;
            end else if (rx_data >= 8'h61 && rx_data <= 8'h66) begin
                fnd_data_next = rx_data[3:0] + 9;
            end else begin
                fnd_data_next = fnd_data_reg;
            end
        end
    end

endmodule
