`timescale 1ns / 1ps                                      // 시간 단위 1 ns · 정밀도 1 ps (#10 = 10 ns, %t 는 ps 로 출력)

interface adder_interface ();                             // interface : DUT 신호 5 개를 한 묶음으로 정의 (class 가 이 묶음으로 DUT 에 접근)
    logic [7:0] a;                                        // DUT 입력 a
    logic [7:0] b;                                        // DUT 입력 b
    logic       mode;                                     // DUT 입력 mode (0 더하기 · 1 빼기)
    logic [7:0] s;                                        // DUT 출력 s (결과 아래 8 비트)
    logic       c;                                        // DUT 출력 c (자리올림 · 빌림 = 결과 9 번째 비트)
endinterface                                              // interface 끝

class transaction;                                        // transaction : 시험 1 번에 쓰는 값 5 개를 담는 객체 형식
    // drive 변수
    rand bit [7:0] a;                                     // rand : randomize() 때 0 ~ 255 랜덤
    rand bit [7:0] b;                                     // rand : 0 ~ 255 랜덤
    rand bit       mode;                                  // rand : 0 · 1 랜덤
    // monitor 변수
    logic    [7:0] s;                                     // rand 없음 → 처음 x, monitor 가 DUT 결과로 채움
    logic          c;                                     // c 도 monitor 가 채움
/*                                                        // constraint (11/04 수업) 는 11/03 과제 범위라 주석 처리 → a · b 전체 범위 랜덤
    constraint adder_limit {
        a > 128;
        b < 64;
    }

    constraint adder_inside {
        a inside {128, 200, 212, 250};
    }

    constraint adder_distribute {
        mode dist {
            0 :/ 80,
            1 :/ 20
        };
    }
*/
    function debug_print(string name);                    // 로그 한 줄 출력 함수 (괄호 = 누가 찍었나 GEN · DRV · MON · SCB)
        $display("%t : [%s] a = %d, b = %d, mode = %d, s = %d, c = %d", $time,  // 시각 · 이름 · 값 5 개 출력
                 name, a, b, mode, s, c);                 // (37 줄 이어짐) 출력할 변수 목록
    endfunction                                           // function 끝
endclass                                                  // class 끝

class generator;                                          // generator : 랜덤 transaction 을 만들어 mailbox 1 에 넣는 역할
    transaction tr;                                       // 핸들 tr (new 전에는 null)
    mailbox #(transaction) gen2drv_mbox;                  // mailbox 1 핸들 (environment 가 만든 것을 받아 저장)

    function new(                                         // new : environment 163 줄이 넘긴 mailbox 1 을 받음
        mailbox#(transaction) gen2drv_mbox_a              // 인자 : transaction 을 담는 mailbox (이름 _a = 멤버 44 줄과 구분)
    );  // 연결되는 거 메일박스 1개
        gen2drv_mbox = gen2drv_mbox_a;                    // 받은 mailbox 1 위치를 멤버 44 줄에 저장 (= 연결)
    endfunction                                           // new 끝

    task run();                                           // run : 부를 때마다 값 1 개 생성
        begin                                             // 순차 블록 시작
            tr = new;                                     // ① 새 객체 동적 할당 (호출마다 new → 이전 값 덮어쓰지 않음)
            tr.randomize();                               // ② rand 변수 a · b · mode 에 랜덤 값
            tr.debug_print("GEN");                        // ③ 로그 [GEN]
            gen2drv_mbox.put(tr);                         // ④ mailbox 1 에 넣기 (put — 크기 제한 없어 안 기다림)
        end                                               // 순차 블록 끝
    endtask                                               // task 끝
endclass                                                  // class 끝

class driver;                                             // driver : mailbox 1 에서 꺼낸 값을 interface 신호로 DUT 에 넣는 역할
    transaction tr;                                       // 핸들 tr (get 으로 받은 객체를 가리킴)
    mailbox #(transaction) gen2drv_mbox;                  // mailbox 1 핸들
    event drv2mon_evt;                                    // event : monitor 에 '다 썼다' 알리는 신호
    virtual adder_interface adder_if_v;                   // virtual interface 핸들 (실제 interface 를 가리킬 변수)

    function new(                                         // new : 3 개를 받음
        mailbox#(transaction) gen2drv_mbox_a, event drv2mon_evt,  // ① mailbox 1 · ② event
        virtual adder_interface adder_if_v_a              // ③ module 의 interface (virtual)
    );  // 연결되는거 3개.
        this.gen2drv_mbox = gen2drv_mbox_a;               // 받은 mailbox 1 → 멤버 64 줄
        this.drv2mon_evt  = drv2mon_evt;                  // 받은 event → 멤버 65 줄
        this.adder_if_v   = adder_if_v_a;                 // 받은 interface → 멤버 66 줄 (이제 class 가 DUT 신호에 접근)
    endfunction                                           // new 끝

    task run();                                           // run
        begin                                             // 순차 블록 시작
            gen2drv_mbox.get(tr);                         // ① mailbox 1 에서 꺼내기 (비어 있으면 기다림)
            tr.debug_print("DRV");                        // ② 로그 [DRV]
            adder_if_v.a    = tr.a;                       // ③ interface 신호에 쓰기 → DUT 입력 a
            adder_if_v.b    = tr.b;                       // DUT 입력 b
            adder_if_v.mode = tr.mode;                    // DUT 입력 mode
            #10;                                          // ④ 10 ns 멈춤 — 이 사이 DUT assign 이 결과 계산
            ->drv2mon_evt;                                // ⑤ event 발생 (monitor 에 알림)
        end                                               // 순차 블록 끝
    endtask                                               // task 끝
endclass                                                  // class 끝

class monitor;                                            // monitor : DUT 신호 5 개를 읽어 새 객체에 담아 mailbox 2 로 보내는 역할
    transaction tr;                                       // 핸들 tr
    mailbox #(transaction) mon2scb_mbox;                  // mailbox 2 핸들
    event drv2mon_evt;                                    // event
    virtual adder_interface adder_if_v;                   // virtual interface 핸들

    function new(mailbox#(transaction) mon2scb_mbox, event drv2mon_evt,  // new : 3 개를 받음 (인자 이름 = 멤버 이름이라 this. 로 구분)
                 virtual adder_interface adder_if_v);  // 연결되는거 3개.
        this.mon2scb_mbox = mon2scb_mbox;                 // this.멤버 = 받은 mailbox 2
        this.drv2mon_evt  = drv2mon_evt;                  // this.멤버 = 받은 event
        this.adder_if_v   = adder_if_v;                   // this.멤버 = 받은 interface
    endfunction                                           // new 끝

    task run();                                           // run
        begin                                             // 순차 블록 시작
            // @(drv2mon_evt);                            // event 기다리기 — 주석 (풀면 이미 지나간 발생을 기다려 멈춤, environment 가 순서를 보장)
            tr      = new;                                // ① 새 객체 (driver 의 객체와 다른 객체)
            tr.a    = adder_if_v.a;                       // ② 신호 읽기 a (새 객체라 a · b · mode 도 읽어야 scoreboard 가 정답 계산 가능)
            tr.b    = adder_if_v.b;                       // b
            tr.mode = adder_if_v.mode;                    // mode
            tr.s    = adder_if_v.s;                       // DUT 결과 s
            tr.c    = adder_if_v.c;                       // DUT 결과 c
            tr.debug_print("MON");                        // ③ 로그 [MON]
            mon2scb_mbox.put(tr);                         // ④ mailbox 2 에 넣기

        end                                               // 순차 블록 끝
    endtask                                               // task 끝

endclass                                                  // class 끝


class scoreboard;                                         // scoreboard : 정답을 직접 계산해 DUT 결과와 비교하는 역할
    transaction tr;                                       // 핸들 tr
    mailbox #(transaction) mon2scb_mbox;                  // mailbox 2 핸들
    function new(mailbox#(transaction) mon2scb_mbox);     // new : mailbox 2 를 받음
        this.mon2scb_mbox = mon2scb_mbox;                 // 받은 mailbox 2 → 멤버
    endfunction                                           // new 끝

    bit [7:0] expected_s;                                 // 정답 s (8 비트)
    bit expected_c;                                       // 정답 c
    int pass_cnt = 0, fail_cnt = 0;                       // pass · fail 개수 (0 부터)
    task run();                                           // run
        mon2scb_mbox.get(tr);                             // ① mailbox 2 에서 꺼내기
        if (tr.mode) begin                                // ② 정답 계산 — mode 1 이면
            {expected_c, expected_s} = tr.a - tr.b;       // 빼기 9 비트 결과를 {c, s} 로 나눠 담음
        end else begin                                    // mode 0 이면
            {expected_c, expected_s} = tr.a + tr.b;       // 더하기 9 비트 결과
        end                                               // if 끝
        if ({expected_c, expected_s} == {tr.c, tr.s}) begin  // ③ 정답 9 비트 == DUT 9 비트 ?
            $display("pass");                             // 같으면 pass 출력
            pass_cnt++;                                   // pass 개수 + 1
        end else begin                                    // 다르면
            $display("fail");                             // fail 출력
            fail_cnt++;                                   // fail 개수 + 1
        end                                               // if 끝
        tr.debug_print("SCB");                            // ④ 로그 [SCB]
    endtask                                               // task 끝
endclass                                                  // class 끝


class environment;                                        // environment : 부품 4 개 · mailbox 2 개 · event 를 만들고 연결 · 순서대로 부르는 역할
    generator gen;                                        // 핸들 gen
    driver drv;                                           // 핸들 drv
    monitor mon;                                          // 핸들 mon
    scoreboard scb;                                       // 핸들 scb
    event drv2mon_evt;                                    // event 1 개 (driver · monitor 가 같이 씀)
    mailbox #(transaction) gen2drv_mbox;                  // mailbox 1 핸들 (gen → drv)
    mailbox #(transaction) mon2scb_mbox;                  // mailbox 2 핸들 (mon → scb)

    function new(                                         // new : module 198 줄이 넘긴 interface 를 받음
        virtual adder_interface adder_if_v                // 인자 : virtual interface (실제 adder_if 위치)
    );  // tb에서 불릴 때 연결하는 거 1개
        gen2drv_mbox = new;                               // mailbox 1 객체 만들기 (gen · drv 보다 먼저 — 아니면 null 을 넘김)
        gen = new(gen2drv_mbox);                          // gen 만들기 + mailbox 1 넘김 → 46 · 49 줄
        drv = new(gen2drv_mbox, drv2mon_evt,              // drv 만들기 + mailbox 1 · event · interface 넘김 → 68 ~ 74 줄
                  adder_if_v);  // drv 부를 때 연결 3개
        mon2scb_mbox = new;                               // mailbox 2 객체 만들기 (mon · scb 보다 먼저)
        mon = new(mon2scb_mbox, drv2mon_evt, adder_if_v);  // mon 만들기 + mailbox 2 · event · interface 넘김 → 96 ~ 100 줄
        scb = new(mon2scb_mbox);                          // scb 만들기 + 같은 mailbox 2 넘김 → 124 · 125 줄
    endfunction                                           // new 끝

    task run(int run_count);                              // run : module 199 줄이 넘긴 횟수 (256) 를 받음
        repeat (run_count) begin                          // 256 회 반복
            gen.run();                                    // ① 값 생성 (0 ns 안)
            drv.run();                                    // ② DUT 에 넣고 10 ns 기다림
            mon.run();                                    // ③ DUT 결과 읽기
            scb.run();                                    // ④ 정답과 비교
        end                                               // repeat 끝
        $display("pass count = %d", scb.pass_cnt);        // pass 개수 출력
        $display("fail count = %d", scb.fail_cnt);        // fail 개수 출력
    endtask                                               // task 끝

endclass                                                  // class 끝

module tb_adder_sv ();                                    // TB 최상위 module (포트 없음)
    adder_interface adder_if ();                          // interface 인스턴스 = 실제 신호 5 개 (class 가 가리킬 실체)

    adder dut (                                           // DUT 인스턴스
        .a(adder_if.a),                                   // 입력 a ← interface
        .b(adder_if.b),                                   // 입력 b ← interface
        .mode(adder_if.mode),                             // 입력 mode ← interface
        .s(adder_if.s),                                   // 출력 s → interface
        .c(adder_if.c)                                    // 출력 c → interface
    );                                                    // 인스턴스 끝

    environment env;                                      // environment 핸들 (null)

    initial begin                                         // 0 ns 에 한 번 실행
        env = new(adder_if);  // env 객체 만들기: adder_if 넘김
        env.run(256);                                     // 256 번 랜덤 검증 (environment 171 줄 run)
        $finish;                                          // 끝나면 시뮬레이션 종료 (2560 ns)
    end                                                   // initial 끝

endmodule                                                 // module 끝
