`timescale 1ns / 1ps

module tb_dht11 ();

    reg         clk, rst, btnR;
    reg         sensor_io;          // TB 가 센서 흉내로 낼 값
    wire        dht11_io;           // FPGA 와 센서가 같이 쓰는 한 가닥 (force 로 잡음)
    wire [3:0]  fnd_com;
    wire [7:0]  fnd_font;
    wire [15:0] led;

    integer     i;
    reg  [39:0] sensor_data;        // 센서가 보낼 40 비트 {습 정수, 습 소수, 온 정수, 온 소수, 체크섬}

    top_dht11 dut (
        .clk     (clk),
        .rst     (rst),
        .btnR    (btnR),
        .fnd_com (fnd_com),
        .fnd_font(fnd_font),
        .led     (led),
        .dht11_io(dht11_io)
    );

    always #5 clk = ~clk;

    initial begin
        clk  = 0;
        rst  = 1;
        btnR = 1'b0;
        // 예 : 습도 45 %, 온도 25 ℃ → 체크섬 = 45 + 0 + 25 + 0 = 70 (화면엔 이 줄이 안 보여 채운 값)
        sensor_data = {8'd45, 8'd0, 8'd25, 8'd0, 8'd70};
        #10;
        rst = 0;

        #10;
        btnR = 1;
        #10_000;
        btnR = 0;

        // start signal
        // 화면은 @(negedge dht11_io); @(posedge dht11_io); — 버튼 디바운서가 8 us 만에 START 를 시작해서
        // 버튼을 놓는 10 us 시점엔 선이 이미 0 → negedge 를 놓침 (SR04 tb 와 같은 경주). 그래서 wait 로 :
        wait (dht11_io === 1'b0);    // START : FPGA 가 0 으로 끌고 있는 중 (이미 0 이면 바로 통과)
        wait (dht11_io !== 1'b0);    // 19 ms 뒤 FPGA 가 선을 놓음 (0 → Z)

        #(20_000);  // 20usec wait
        //
        force dht11_io = sensor_io;
        // sensor io pattern
        // sync, repose sensor
        sensor_io = 1'b0;
        #(80_000);  // 80usec low
        sensor_io = 1'b1;
        #(80_000);  // 80usec high

        for (i = 0; i < 40; i = i + 1) begin
            // data sync 50usec
            sensor_io = 1'b0;
            #(50_000);
            if (sensor_data[39-i]) begin
                sensor_io = 1'b1;
                #(70_000);      // "1" = High 70 us

            end else begin

                sensor_io = 1'b1;
                #(30_000);      // "0" = High 26 ~ 28 us

            end

        end

        // 마지막 비트 뒤 센서가 50 us 동안 0 (데이터시트 · 판서 STOP) — 화면엔 아직 없음, 이게 있어야 마지막 비트가 끝남
        sensor_io = 1'b0;
        #(50_000);

        release dht11_io;

        #(200_000);
        $stop;
    end
endmodule
