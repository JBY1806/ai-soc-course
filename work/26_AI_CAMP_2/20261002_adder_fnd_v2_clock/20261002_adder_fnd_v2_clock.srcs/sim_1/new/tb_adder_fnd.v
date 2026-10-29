`timescale 1ns / 1ps

module tb_adder_fnd ();
    reg [7:0] a, b;
    reg  [1:0] ds_sel;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;

    adder_fnd DUT (
        .a(a),
        .b(b),
        .ds_sel(ds_sel),
        .fnd_com(fnd_com),
        .fnd_font(fnd_font)
    );


    integer i, j, k;
    integer err;
    reg [8:0] exp_sum;
    reg [3:0] exp_digit;
    reg [3:0] exp_com;
    reg [7:0] exp_font;

    initial begin
        err = 0;
        a = 8'd0;
        b = 8'd0;
        ds_sel = 2'd0;

        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                for (k = 0; k < 4; k = k + 1) begin
                    a = i;
                    b = j;
                    ds_sel = k;

                    exp_sum = i + j;
 if (k == 0) exp_digit = exp_sum % 10;
                    else if (k == 1) exp_digit = (exp_sum / 10) % 10;
                    else if (k == 2) exp_digit = (exp_sum / 100) % 10;
                    else exp_digit = 0;

                    if (k == 0) exp_com = 4'b1110;
                    else if (k == 1) exp_com = 4'b1101;
                    else if (k == 2) exp_com = 4'b1011;
                    else exp_com = 4'b0111;

                    case (exp_digit)
                        4'b0000: exp_font = 8'hc0;
                        4'b0001: exp_font = 8'hf9;
                        4'b0010: exp_font = 8'ha4;
                        4'b0011: exp_font = 8'hb0;
                        4'b0100: exp_font = 8'h99;
                        4'b0101: exp_font = 8'h92;
                        4'b0110: exp_font = 8'h82;
                        4'b0111: exp_font = 8'hf8;
                        4'b1000: exp_font = 8'h80;
                        4'b1001: exp_font = 8'h90;
                        default: exp_font = 8'hff;
                    endcase

                    #10;

                    if ({fnd_com, fnd_font} !== {exp_com, exp_font}) begin  // 출력 결과 판정을 #10 뒤에 하는 이유는 출력 결과 반영 시간이 필요하기 때문.
                        err = err + 1;
                        $display(
                            "FAIL: %0d + %0d sel=%0d -> com=%b font=%h (expect %b %h)",
                            i, j, k, fnd_com, fnd_font, exp_com, exp_font);
                    end
                end
            end
        end
        $display("TOTAL 262144, MISMATCH = %0d", err);
        $finish;
    end

endmodule
