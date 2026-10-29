`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/27 11:55:18
// Design Name: 
// Module Name: uart_fifo_loopback
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module uart_fifo_loopback(
    input clk,
    input rst,
    input rx,
    output tx
    );

    wire [7:0] w_rx_data, w_fifo_rx_pop_data, w_fifo_tx_pop_data;
    wire w_rx_done, w_fifo_rx_empty, w_fifo_tx_full, w_fifo_tx_empty, w_tx_busy;
    wire w_b_tick;

    
    
endmodule
