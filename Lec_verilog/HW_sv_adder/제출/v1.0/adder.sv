`timescale 1ns / 1ps                                      // 시간 단위 1 ns · 정밀도 1 ps

module adder (                                            // DUT : 8 비트 더하기 · 빼기 (mode 로 선택)
    input  logic [7:0] a,                                 // 입력 a 8 비트
    input  logic [7:0] b,                                 // 입력 b 8 비트
    input  logic       mode,                              // 0 더하기 · 1 빼기
    output logic [7:0] s,                                 // 결과 아래 8 비트
    output logic       c                                  // 결과 9 번째 비트 (더하기 자리올림 · 빼기 빌림)
);

    assign {c, s} = mode ? a - b : a + b;                 // mode 1 → a - b, 0 → a + b 를 9 비트 {c, s} 로 (조합 회로 = RTL_SUB · RTL_ADD · RTL_MUX)

endmodule                                                 // module 끝
