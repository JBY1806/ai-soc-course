`timescale 1ns / 1ps

module tb_adder_fnd_scan ();
    reg clk;
    reg rst;
    reg [7:0] a, b;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;

    adder_fnd DUT (
        .clk(clk),
        .rst(rst),
        .a(a),
        .b(b),
        .fnd_com(fnd_com),
        .fnd_font(fnd_font)
    );

    always #5 clk = ~clk;

    integer i, k;
    integer err;
    reg [8:0] exp_sum;
    reg [3:0] exp_digit;
    reg [3:0] exp_com;
    reg [7:0] exp_font;

    initial begin
        clk = 0;
        rst = 1;
        err = 0;
        a = 0;
        b = 0;
        #20 rst = 0;
        #327680;

        for (i = 0; i < 5; i = i + 1) begin
            if (i == 0) begin a = 0;   b = 0;   end
            else if (i == 1) begin a = 9;   b = 1;   end
            else if (i == 2) begin a = 99;  b = 1;   end
            else if (i == 3) begin a = 255; b = 1;   end
            else begin a = 255; b = 255; end
            exp_sum = a + b;

            for (k = 0; k < 4; k = k + 1) begin
                if (k == 0) exp_digit = exp_sum % 10;
                else if (k == 1) exp_digit = (exp_sum / 10) % 10;
                else if (k == 2) exp_digit = (exp_sum / 100) % 10;
                else exp_digit = 0;

                if (k == 0) exp_com = 4'b1110;
                else if (k == 1) exp_com = 4'b1101;
                else if (k == 2) exp_com = 4'b1011;
                else exp_com = 4'b0111;

                case (exp_digit)
                    4'd0: exp_font = 8'hc0;
                    4'd1: exp_font = 8'hf9;
                    4'd2: exp_font = 8'ha4;
                    4'd3: exp_font = 8'hb0;
                    4'd4: exp_font = 8'h99;
                    4'd5: exp_font = 8'h92;
                    4'd6: exp_font = 8'h82;
                    4'd7: exp_font = 8'hf8;
                    4'd8: exp_font = 8'h80;
                    4'd9: exp_font = 8'h90;
                    default: exp_font = 8'hff;
                endcase

                #10;
                if ({fnd_com, fnd_font} !== {exp_com, exp_font}) begin
                    err = err + 1;
                    $display("FAIL t=%0d ns: %0d + %0d digit=%0d -> com=%b font=%h (expect %b %h)",
                             $time, a, b, k, fnd_com, fnd_font, exp_com, exp_font);
                end
                #655350;
            end
        end
        $display("TOTAL 20, MISMATCH = %0d", err);
        $finish;
    end

endmodule