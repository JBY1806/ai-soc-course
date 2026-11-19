`timescale 1ns / 1ps
//=============================================================================
//  tb_fifo_sv.sv  :  FIFO 를 검증하는 클래스 기반 테스트벤치 (SystemVerilog)
//
//  [이 파일이 하는 일]
//    DUT(Design Under Test, 검증 대상 설계) = fifo_sv
//    이 TB 는 DUT 에 push / pop 자극을 무작위로 넣고, DUT 가 내놓은 결과가
//    "내가 따로 계산해 둔 정답" 과 같은지 자동으로 비교한다.
//    손으로 파형을 눈으로 보고 맞다/틀리다 판단하던 Verilog TB 와 달리,
//    판정을 코드가 한다. 그래서 자극 100 번을 돌려도 사람이 볼 일이 없다.
//
//  [전체 구조 — 자극이 흘러가는 순서]
//
//      generator  --(mailbox gen2drv_mbox)-->  driver  --> [ interface ] --> DUT
//          ^                                                     |
//          |                                                     v
//      (event gen_next_evt)                                   monitor
//          |                                                     |
//          +------ scoreboard <--(mailbox mon2scb_mbox)----------+
//
//      generator  : 무작위 자극(transaction)을 만든다
//      driver     : 그 자극을 실제 신호(wire 값)로 DUT 핀에 꽂는다
//      interface  : TB 와 DUT 를 잇는 신호 묶음 (Verilog 의 wire 선언 묶음)
//      monitor    : DUT 핀에서 입력·출력 값을 "읽기만" 한다
//      scoreboard : 읽어 온 값으로 정답을 계산해 pass / fail 을 센다
//      event      : scoreboard 가 다 셌다고 generator 에게 알리는 신호
//
//  [Verilog 와 다른 점 — SW 개념 용어 먼저]
//      class     : 변수(값)와 task/function(동작)을 한 덩어리로 묶은 설계도.
//                  module 과 달리 합성되지 않고, 시뮬레이션 중에 new 로
//                  필요할 때마다 몇 개든 만들었다 버린다.
//      object    : class 설계도로 실제로 만들어 낸 한 개. `tr = new;` 의 결과물.
//      handle    : object 를 가리키는 이름표. C 의 포인터와 같은 자리.
//                  `transaction tr;` 의 tr 은 object 가 아니라 handle 이다.
//      this      : "지금 이 object 자신" 을 가리키는 예약어.
//      task      : Verilog 의 task 와 같다. 시간(@, #)을 쓸 수 있다.
//      function  : 시간을 못 쓴다. 즉시 끝난다.
//      mailbox   : 두 클래스 사이에 object 를 주고받는 SV 내장 FIFO.
//                  put() 으로 넣고 get() 으로 꺼낸다. 비었으면 get 이 기다린다.
//      event     : "지금 됐다" 를 알리는 0 폭 신호. -> 로 쏘고 @ 로 기다린다.
//=============================================================================


//-----------------------------------------------------------------------------
//  ① interface  :  TB 와 DUT 를 잇는 신호 묶음
//
//  Verilog TB 였다면 reg clk; reg rst; wire full; ... 를 module 안에 쭉
//  선언하고 포트에 하나씩 연결했다. interface 는 그 선언들을 한 덩어리로
//  묶어서 이름 하나(fifo_if)로 넘길 수 있게 한 것이다.
//  묶어 두면 좋은 이유 : driver / monitor 클래스가 신호를 쓰려면 신호를
//  넘겨받아야 하는데, 8 개를 따로 넘기지 않고 묶음 하나만 넘기면 된다.
//
//  clk 만 input 인 이유 : clk 은 TB 의 module 쪽(727 줄 always #5)에서 만들어
//  주므로 interface 는 받아 쓰기만 한다. 나머지는 interface 가 들고 있는다.
//-----------------------------------------------------------------------------
interface fifo_interface (
    input clk
);
    // logic : reg 와 wire 를 합친 SV 자료형. always 에서도, assign 에서도
    //         쓸 수 있어서 TB 에서는 거의 logic 만 쓴다.
    logic       rst;        // DUT 리셋 (TB 가 만들어 DUT 로 보냄)
    logic [7:0] push_data;  // FIFO 에 넣을 8 비트 데이터 (TB → DUT)
    logic       push;       // 1 이면 이번 클럭에 push_data 를 넣어라 (TB → DUT)
    logic       pop;        // 1 이면 이번 클럭에 한 개 꺼내라        (TB → DUT)
    logic [7:0] pop_data;   // FIFO 가 꺼내 준 데이터 (DUT → TB)
    logic       full;       // FIFO 가 꽉 찼다       (DUT → TB)
    logic       empty;      // FIFO 가 비었다        (DUT → TB)

    //-------------------------------------------------------------------------
    //  reset assertion  :  "리셋 중에는 반드시 이래야 한다" 를 코드로 박아 둔 것
    //
    //  assertion(어서션) = 시뮬레이션이 도는 내내 백그라운드에서 자동으로
    //  계속 검사하는 규칙. scoreboard 처럼 내가 불러서 비교하는 게 아니라,
    //  한 번 써 두면 클럭마다 알아서 검사하고 어기는 순간 메시지를 띄운다.
    //
    //  쓰는 자리가 interface 인 이유 : 여기에 DUT 핀 신호가 다 모여 있어서
    //  rst · full · empty 를 그냥 이름으로 쓸 수 있다.
    //-------------------------------------------------------------------------

    //  ▼ 아래 두 줄 (125 ~ 127) 을 통째로 풀면
    //
    //      property p_rst_full;
    //          @(posedge clk) rst |-> (full === 1'b0);
    //      endproperty
    //
    //    = "clk 이 0→1 로 올라가는 순간마다 본다.
    //       그 순간 rst 가 1 이었다면, 바로 그 같은 순간에 full 은 0 이어야 한다."
    //
    //  조각별로 끊어 보면
    //
    //    property ~ endproperty
    //        검사할 규칙 한 개에 이름을 붙여 두는 틀. 아직 검사는 안 한다.
    //        task 를 써 두기만 하고 아직 부르지 않은 것과 같은 상태다.
    //        실제 검사는 아래 140 줄 assert property 가 시킨다.
    //
    //    @(posedge clk)
    //        이 규칙을 "언제" 볼지 정하는 기준 시각(sampling clock).
    //        매 상승 엣지마다 한 번씩 본다. 이게 없으면 값이 흔들리는
    //        중간 시각에도 검사해 버려서 멀쩡한 설계가 fail 난다.
    //
    //    rst
    //        |-> 의 왼쪽 = 전제(antecedent). "rst 가 1 일 때만 따져 보겠다".
    //        rst 가 0 인 엣지는 이 규칙이 아예 적용되지 않고 그냥 넘어간다
    //        (fail 도 아니고 pass 도 아닌 vacuous = 공허한 통과).
    //
    //    |->
    //        overlapped implication(겹침 함의) 연산자. "왼쪽이 참이면 →
    //        오른쪽도 참이어야 한다" 는 뜻이고, 오른쪽을 '같은 엣지에서'
    //        확인한다. 형제 연산자 |=> 는 '다음 엣지에서' 확인한다.
    //        여기서 |-> 를 쓴 이유 : full 은 rst 가 걸린 그 클럭에 바로
    //        0 이어야 하는 신호지, 한 클럭 뒤에 0 이 되면 안 되기 때문.
    //
    //    (full === 1'b0)
    //        |-> 의 오른쪽 = 결론(consequent). 실제로 확인할 조건.
    //
    //  ▼ == 이 아니라 === 인 이유 (아래 사용자 주석의 답)
    //        ==  는 logical equality  : 한쪽에 x 나 z 가 섞이면 결과가
    //            1 도 0 도 아닌 x 가 된다. x 는 if 에서 거짓 취급이라
    //            "값이 x 라서 모른다" 와 "0 이 아니라서 틀렸다" 가 구분되지 않는다.
    //        === 는 case equality(4-state 비교) : 0·1·x·z 를 글자 그대로
    //            맞춰 본다. full 이 x 면 (full === 1'b0) 은 깔끔하게 0(거짓)이
    //            되어 assertion 이 제대로 fail 난다.
    //        리셋 직후에는 DUT 출력이 x 로 떠 있을 수 있다. 바로 그 x 를
    //        잡아내려고 쓰는 검사이므로 x 를 x 로 볼 수 있는 === 이어야 한다.
    property p_rst_full;
        @(posedge clk) rst |-> (full === 1'b0); // ==이 아닌 ===으로 한 이유. 진짜 이런 사소한 것들 하나하나 이유를 다 알아야 함. case compare, include x, z. 기준 설정 근거.
    endproperty
    //  위와 같은 규칙, 보는 신호만 empty 로 바뀐 것.
    //  리셋 중이면 FIFO 안에 든 게 없어야 하므로 empty 는 1 이어야 한다.
    property p_rst_empty;
        @(posedge clk) rst |-> (empty === 1'b1); // ==이 아닌 ===으로 한 이유. 진짜 이런 사소한 것들 하나하나 이유를 다 알아야 함. case compare, include x, z. 기준 설정 근거.
    endproperty

    //  assert property  :  위에서 '이름만 붙여 둔' 규칙을 실제로 켠다.
    //  a_rst_full :     앞의 이름표(label). 어떤 assertion 이 깨졌는지
    //                   Vivado 메시지와 파형 창에서 이 이름으로 찾는다.
    //  else $display(...) :  규칙을 어겼을 때만 실행되는 부분(action block).
    //                   안 쓰면 Vivado 기본 메시지만 뜨고 그때 값은 안 보인다.
    //                   %t = 시각, $time = 지금 시뮬 시각, full = 그 순간 값.
    a_rst_full :
    assert property (p_rst_full)
    else $display(" %t : [assert] error full = %d", $time, full);

    a_rst_empty :
    assert property (p_rst_empty)
    else $display(" %t : [assert] error empty = %d", $time, empty);


endinterface


//-----------------------------------------------------------------------------
//  ② transaction  :  자극 한 번 / 관측 한 번을 담는 그릇
//
//  "한 클럭에 오간 값 전부" 를 변수 하나로 묶은 것이다.
//  generator 가 이걸 만들어 driver 에게 주고, monitor 가 이걸 채워
//  scoreboard 에게 준다. 즉 TB 안을 돌아다니는 데이터의 단위다.
//-----------------------------------------------------------------------------
class transaction;
    // bit  : 0/1 만 갖는 2-state 자료형 (x·z 없음). 내가 만들어 넣는 자극은
    //        x 일 일이 없으므로 bit 로 둔다. 메모리·속도에도 유리하다.
    // rand : 이 변수는 randomize() 를 부를 때 무작위로 채워라, 는 표시.
    //        rand 가 안 붙은 변수는 randomize() 해도 값이 그대로다.
    bit            rst;        // 리셋 값 (무작위로 흔들면 안 되므로 rand 없음)
    rand bit [7:0] push_data;  // 넣을 데이터 : 0 ~ 255 아무 값
    rand bit       push;       // 이번에 push 할지 말지
    rand bit       pop;        // 이번에 pop 할지 말지

    // logic : 아래 셋은 DUT 가 내놓은 값을 monitor 가 받아 적는 칸이다.
    //         DUT 출력은 x 일 수 있으므로 4-state 인 logic 이어야 한다.
    logic    [7:0] pop_data;
    logic          full;
    logic          empty;

    int            scenario;   // 지금 몇 번 시나리오인지 (1·2·3). 아래 제약이 본다.

    //-------------------------------------------------------------------------
    //  constraint  :  randomize() 가 지켜야 하는 조건. "제약"
    //  randomize() 는 이 블록을 읽고, 조건을 만족하는 값만 골라서 채운다.
    //  Verilog 의 $random 은 아무 값이나 뱉지만, 여기서는 "지금 push 전용
    //  시나리오면 push 는 반드시 1" 처럼 내가 원하는 쪽으로 몰 수 있다.
    //
    //  dist  :  distribution(분포). 값마다 뽑힐 가중치를 준다.
    //           `0 :/ 0, 1 :/ 10` = 0 이 나올 가중치 0, 1 이 나올 가중치 10
    //           → 0 은 절대 안 나오고 항상 1 이 나온다.
    //           :/ 는 "범위 전체에 이 가중치를 나눠 준다", := 는 "범위 안
    //           값 하나하나에 각각 이 가중치" 라는 차이가 있다. 값이 하나뿐일
    //           때는 둘이 같다.
    //-------------------------------------------------------------------------
    constraint test_scenario {
        if (scenario == 1) {
            // push only  :  넣기만 한다 → FIFO 를 꽉 채워서 full 을 보려는 것
            push dist {
                0 :/ 0,
                1 :/ 10
            };
            pop dist {
                0 :/ 10,
                1 :/ 0
            };
        } else
        if (scenario == 2) {
            // pop only  :  빼기만 한다 → FIFO 를 비워서 empty 를 보려는 것
            push dist {
                0 :/ 10,
                1 :/ 0
            };
            pop dist {
                0 :/ 0,
                1 :/ 10
            };
        }
        // scenario == 3 은 조건에 안 걸린다 → 제약 없음 → push·pop 둘 다
        // 완전 무작위. 동시 push+pop 같은 섞인 경우를 여기서 때린다.
    }

    //  function void  :  돌려주는 값이 없는 함수(void = 없음).
    //  시간 지연이 없으므로 task 가 아니라 function 으로 둔 것이다.
    //  string name : 누가 찍은 로그인지 구분하려고 받는 이름 ("GEN"·"DRV"…).
    //  같은 transaction 이 GEN → DRV → MON → SCB 로 흘러가므로, 로그만 보고
    //  어디까지 갔는지 추적할 수 있다.
    function void debug_print(string name);
        $display(
            "%t : [%s] rst = %d, push_data = %d, push = %d, pop = %d, pop_data = %d, full = %d, empty = %d",
            $time, name, rst, push_data, push, pop, pop_data, full, empty);
    endfunction

endclass


//-----------------------------------------------------------------------------
//  ③ generator  :  자극을 만들어 내는 쪽
//
//  "어떤 값을 넣을지" 만 정한다. 실제로 핀에 꽂는 일은 driver 가 한다.
//  둘을 나눠 둔 이유 : 자극의 내용(무엇을)과 신호 타이밍(언제·어떻게)은
//  바뀌는 이유가 다르다. 시나리오를 바꿀 때 driver 를 안 건드려도 된다.
//-----------------------------------------------------------------------------
class generator;
    transaction tr;                          // 지금 만들고 있는 자극의 handle
    mailbox #(transaction) gen2drv_mbox;     // driver 로 보내는 통로
                                             // #(transaction) = 이 mailbox 에는
                                             // transaction 만 넣는다는 타입 지정
    event gen_next_evt;                      // scoreboard 가 "다 처리했다" 고
                                             // 알려 주는 신호를 받을 자리

    //  function new  :  생성자(constructor). `gen = new(...)` 할 때 자동으로
    //  한 번 불린다. 바깥에서 만든 mailbox·event 를 받아서 내 멤버에 연결한다.
    //  this.gen2drv_mbox = gen2drv_mbox;  에서
    //      왼쪽 this.~  = 이 클래스가 들고 있는 멤버 변수
    //      오른쪽 ~     = 방금 인자로 받은 것
    //  이름이 같아서 this. 로 구분해 준 것이다.
    //  ※ mailbox·event 는 handle 이므로 복사해도 같은 실체를 가리킨다.
    //    그래서 generator 와 driver 가 같은 mailbox 하나를 공유하게 된다.
    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_evt);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_evt = gen_next_evt;
    endfunction

    //  run  :  시나리오 1 → 2 → 3 순서로 각각 run_count 번씩 자극을 만든다.
    task run(int run_count);
        int push_only_count = 10, pop_only_count = 10;   // 지금은 안 쓰는 변수

        // ── 시나리오 1 : push 만 ────────────────────────────────────────────
        $display(" push only test num = %d", run_count);
        repeat (run_count) begin
            tr = new;                 // 자극 object 를 새로 하나 만든다.
                                      // 매번 new 하는 이유 : 같은 object 를
                                      // 재활용하면 mailbox 로 넘긴 뒤에 내가
                                      // 값을 덮어써 버려서, 받는 쪽이 엉뚱한
                                      // 값을 보게 된다 (handle 은 실체를
                                      // 가리키기만 하므로 사본이 아니다).
            tr.scenario = 1;          // 제약이 볼 시나리오 번호를 먼저 정하고
            tr.randomize();           // 그 다음 무작위 → push=1, pop=0 으로 나온다
            tr.rst = 0;               // 자극 중에는 리셋을 걸지 않는다
            gen2drv_mbox.put(tr);     // driver 에게 보낸다
            tr.debug_print("GEN");
            @(gen_next_evt);          // scoreboard 가 이번 건을 다 셀 때까지 대기.
                                      // 이게 없으면 generator 가 혼자 앞서 달려서
                                      // mailbox 에 자극이 쌓이고 순서가 꼬인다.
                                      // = 한 건씩 주고받는 handshake(악수)
        end

        // ── 시나리오 2 : pop 만 ─────────────────────────────────────────────
        //    시나리오 1 이 끝난 직후라 FIFO 가 차 있는 상태에서 시작한다.
        $display(" pop only test num = %d", run_count);

        repeat (run_count) begin
            tr = new;
            tr.scenario = 2;
            tr.randomize();
            tr.rst = 0;
            gen2drv_mbox.put(tr);
            tr.debug_print("GEN");
            @(gen_next_evt);
        end

        // ── 시나리오 3 : push·pop 무작위 ────────────────────────────────────
        //    제약에 scenario 3 조건이 없으므로 push·pop 이 자유롭게 나온다.
        //    동시에 1,1 이 되는 경우(= 같은 클럭에 넣고 빼기)를 노린 것.
        $display(" push pop only test num = %d", run_count);
        repeat (run_count) begin
            tr = new;
            tr.scenario = 3;
            tr.randomize();
            tr.rst = 0;
            gen2drv_mbox.put(tr);
            tr.debug_print("GEN");
            @(gen_next_evt);
        end
    endtask

endclass


//-----------------------------------------------------------------------------
//  ④ driver  :  자극을 실제 신호로 DUT 핀에 꽂는 쪽
//-----------------------------------------------------------------------------
class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;     // generator 에게서 받는 통로

    //  virtual interface  :  interface 를 가리키는 handle.
    //  interface 자체(fifo_if)는 module 안에 실체로 하나 만들어져 있고,
    //  클래스는 합성 대상이 아니라 실체를 직접 들 수 없다. 그래서 "그 실체를
    //  가리키는 이름" 인 virtual 을 들고 간접으로 쓴다.
    //  virtual 이 없으면 class 안에서 fifo_vif.push 같은 접근이 컴파일 안 된다.
    virtual fifo_interface fifo_vif;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual fifo_interface fifo_vif);
        this.gen2drv_mbox = gen2drv_mbox;
        this.fifo_vif     = fifo_vif;
    endfunction

    //-------------------------------------------------------------------------
    //  preset  :  본 시험 전에 DUT 를 리셋해서 알려진 상태로 만든다.
    //  이 구간이 바로 위 interface 의 assertion(140·144 줄)이 실제로 검사되는
    //  유일한 구간이다. rst 가 1 인 동안만 |-> 의 전제가 성립하기 때문.
    //-------------------------------------------------------------------------
    task preset();
        fifo_vif.rst = 1;                        // 리셋 걸기
        fifo_vif.push = 0;                       // 리셋 중에 엉뚱한 동작이
        fifo_vif.push_data = 0;                  // 들어가지 않도록 입력을
        fifo_vif.pop = 0;                        // 전부 0 으로 눕혀 둔다
        repeat (2) @(posedge fifo_vif.clk);      // 상승 엣지 2 번 동안 리셋 유지.
                                                 // 2 번인 이유 : assertion 이
                                                 // posedge 기준이라 최소 한 번은
                                                 // 리셋 상태로 검사받아야 한다.
        @(negedge fifo_vif.clk);                 // 하강 엣지까지 기다렸다가
        fifo_vif.rst = 0;                        // 리셋을 뗀다.
                                                 // 하강 엣지에서 떼는 이유 :
                                                 // DUT 는 상승 엣지에서 값을
                                                 // 읽으므로, 상승 엣지와 겹치게
                                                 // 바꾸면 그 순간 0 인지 1 인지
                                                 // 경쟁(race)이 난다. 반 클럭
                                                 // 비켜서 바꾸면 그 경쟁이 없다.
    endtask


    //-------------------------------------------------------------------------
    //  run  :  mailbox 에 자극이 올 때마다 핀에 꽂기를 영원히 반복
    //-------------------------------------------------------------------------
    task run();
        forever begin                            // forever = 시뮬이 끝날 때까지 반복
            @(posedge fifo_vif.clk);             // 상승 엣지에 맞춰 한 박자 잡고
            gen2drv_mbox.get(tr);                // 자극을 하나 꺼낸다.
                                                 // 비어 있으면 여기서 자동 대기.
            tr.debug_print("DRV");
            #1;  // 1나노 후 드라이버
                 // 상승 엣지 바로 그 시각에 값을 바꾸면 DUT 가 바뀌기 전 값을
                 // 읽을지 바뀐 값을 읽을지 알 수 없다(race). 1ns 뒤로 밀어
                 // 두면 "엣지 지나고 나서 바뀐 값" 으로 확정된다.
                 // 클럭이 10ns 주기(727 줄 always #5)이므로 1ns 는 충분히 안쪽이다.
            fifo_vif.rst = tr.rst;
            fifo_vif.push_data = tr.push_data;
            fifo_vif.push = tr.push;
            fifo_vif.pop = tr.pop;
        end

    endtask

endclass


//-----------------------------------------------------------------------------
//  ⑤ monitor  :  DUT 핀을 읽기만 하는 쪽
//
//  driver 가 쓴 값을 그대로 쓰지 않고 굳이 핀에서 다시 읽는 이유 :
//  driver 의 의도와 DUT 가 실제로 본 값이 다를 수 있기 때문이다. 검증은
//  "내가 넣으려던 값" 이 아니라 "회로에 실제로 들어간 값" 을 기준으로 해야 한다.
//-----------------------------------------------------------------------------
class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;     // scoreboard 로 보내는 통로
    virtual fifo_interface fifo_vif;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual fifo_interface fifo_vif);
        this.mon2scb_mbox = mon2scb_mbox;
        this.fifo_vif     = fifo_vif;
    endfunction

    task run();
        forever begin
            @(negedge fifo_vif.clk);     // 하강 엣지에 읽는 이유 :
                                         // 상승 엣지에서 DUT 가 값을 바꾸므로,
                                         // 반 클럭 뒤면 입력도 출력도 다 안정돼
                                         // 있다. 가장 안전한 관측 시각이다.
            tr = new;                    // 관측 결과를 담을 그릇을 새로 만든다
            tr.rst = fifo_vif.rst;       // 입력 쪽 (scoreboard 가 정답 계산에 씀)
            tr.push_data = fifo_vif.push_data;
            tr.push = fifo_vif.push;
            tr.pop = fifo_vif.pop;
            tr.pop_data = fifo_vif.pop_data;   // 출력 쪽 (정답과 비교당할 값)
            tr.full = fifo_vif.full;
            tr.empty = fifo_vif.empty;
            tr.debug_print("MON");
            mon2scb_mbox.put(tr);        // scoreboard 로 넘긴다
        end

    endtask


endclass


//-----------------------------------------------------------------------------
//  ⑥ scoreboard  :  정답을 따로 계산해서 DUT 결과와 맞춰 보는 쪽
//
//  검증의 핵심이 여기다. "DUT 와 똑같이 동작하는 아주 단순한 모델" 을
//  소프트웨어로 하나 더 만들어 두고(= expect_fifo 큐), 둘의 출력이 같은지 본다.
//  모델을 RTL 과 다른 방식(큐)으로 짜야 같은 실수를 반복하지 않는다.
//-----------------------------------------------------------------------------
class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_evt;                  // 다 셌다고 generator 에게 알릴 신호

    //  queue(큐)  :  크기가 늘었다 줄었다 하는 배열. SV 내장 자료형.
    //      [$]    = 크기 제한 없는 큐
    //      [$:3]  = 최대 인덱스가 3 → 칸 4 개짜리 큐. DUT FIFO 깊이와 맞춘 것.
    //      push_back(x) : 뒤에 넣기,  pop_front() : 앞에서 빼기 → 먼저 넣은
    //      것이 먼저 나오므로 FIFO 그 자체다.
    logic [7:0] expect_fifo[$:3]; // logic으로 만드는 이유? 아직 안들어왔을 때 x니까.
                                  //  → bit 로 두면 안 들어온 칸이 0 으로 보여서
                                  //    "진짜 0" 과 "아직 모름" 이 구분되지 않는다.
                                  //    logic 이면 x 로 남아 바로 눈에 띈다.

    bit expect_full = 0, expect_empty = 1;   // 내 모델이 예상하는 full·empty.
                                             // 시작값은 "비었고 안 찼다".
    int total_count = 0, pass_count = 0, fail_count = 0;   // pop_data 비교 집계
    int fifo_size = 0;                       // 내 모델에 지금 몇 개 들었나

    //-------------------------------------------------------------------------
    //  covergroup  :  커버리지(coverage) = "시험을 어디까지 해 봤나" 를 세는 자
    //
    //  pass/fail 이 "맞았냐" 를 본다면, 커버리지는 "안 해 본 경우가 남았냐" 를
    //  본다. 100 번 돌려 전부 pass 여도 full 상태를 한 번도 안 만들어 봤다면
    //  그 시험은 믿을 수 없다. 그걸 숫자로 잡아 주는 장치다.
    //
    //    coverpoint : 관찰할 값 하나
    //    bins       : 그 값을 어떤 칸으로 나눠 셀지
    //    cross      : 두 coverpoint 의 조합까지 셀지
    //-------------------------------------------------------------------------
    covergroup cg_fifo;
        option.per_instance = 1;   // 이 covergroup object 별로 따로 집계해서
                                   // 보고서에 찍어라. 안 켜면 타입 전체로 합쳐
                                   // 나와서 이 인스턴스 결과를 못 본다.

        //fifo push data
        //  iff (tr.push) : push 가 1 일 때만 센다. push 가 0 인 클럭의
        //  push_data 는 FIFO 에 안 들어가므로 세면 숫자가 부풀려진다.
        //  bins full[] = {[0:255]} : [] 를 붙이면 값마다 칸을 따로 만든다
        //  → 256 칸. 0 ~ 255 를 전부 한 번씩 넣어 봐야 100% 가 된다.
        cp_push_data: coverpoint tr.push_data iff (tr.push) {
            bins full[] = {[0 : 255]};
        }

        // fifo push, pop : op
        //  { tr.push, tr.pop } : 두 신호를 이어 붙여 2 비트로 본다(concatenation).
        //  네 가지 조작을 다 해 봤는지 세는 것.
        cp_push_pop: coverpoint {
            tr.push, tr.pop
        } {
            bins idle = {2'b00};        // 아무것도 안 함
            bins push_only = {2'b10};   // 넣기만
            bins pop_only = {2'b01};    // 빼기만
            bins push_pop = {2'b11};    // 동시에 넣고 빼기 ← 가장 잘 깨지는 경우
        }

        // fifo full, empty : state
        //  FIFO 가 처해 본 상태를 세는 것.
        cp_full_empty: coverpoint {
            tr.full, tr.empty
        } {
            bins normal = {2'b00}; bins full = {2'b10}; bins empty = {2'b01};
        //            bins full_empty = {2'b11}; // never have this case
        //            → 꽉 찬 동시에 비는 상태는 설계상 나올 수 없다.
        //              칸을 만들어 두면 영원히 0 이라 커버리지가 100% 가 못 된다.
        }

        //  깊이 0·1·2·3·4 를 다 겪어 봤는지. 가장자리(0 과 4)가 버그가 나는 곳이다.
        cp_fifo_size: coverpoint fifo_size {bins size[] = {[0 : 4]};}

        //  cross  :  조합 커버리지. 각각은 해 봤어도 "꽉 찬 상태에서 push" 같은
        //  조합은 안 해 봤을 수 있다. 그 구멍을 잡는다.
        cx_op_st: cross cp_push_pop, cp_full_empty;      // 조작 × 상태
        cx_op_depth: cross cp_push_pop, cp_fifo_size;    // 조작 × 깊이

    endgroup

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_evt);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_evt = gen_next_evt;
        cg_fifo = new();     // covergroup 도 object 라 따로 new 해야 집계가 시작된다
    endfunction


    //  full·empty 신호 자체가 맞았는지 따로 세는 칸
    int
        full_pass_count = 0,
        full_fail_count = 0,
        empty_pass_count = 0,
        empty_fail_count = 0;

    task run();
        forever begin
            mon2scb_mbox.get(tr);     // monitor 가 관측한 결과를 하나 받는다
            tr.debug_print("SCB");
            total_count++;

            if (!tr.rst) begin        // 리셋 중인 샘플은 채점하지 않는다.
                                      // 리셋 구간은 위 interface 의 assertion 이
                                      // 따로 보고 있으므로 여기서 또 볼 필요가 없고,
                                      // 내 모델(expect_fifo)과 상태가 어긋난다.

                // ── 1) 내 모델 기준으로 지금 full·empty 가 어때야 하는지 계산 ──
                fifo_size = expect_fifo.size();   // 큐에 지금 몇 개 들었나
                if (fifo_size == 4) begin
                    expect_full = 1;              // 4 개면 꽉 찬 것
                end else expect_full = 0;
                if (fifo_size == 0) begin
                    expect_empty = 1;             // 0 개면 빈 것
                end else expect_empty = 0;

                //full pass/fail
                //  내 예상과 DUT 의 full 핀이 같은가
                if (expect_full == tr.full) begin
                    $display("pass : fifo full signal");
                    full_pass_count++;
                end else begin
                    $display("fail : fifo full signal");
                    full_fail_count++;
                end

                //empty pass/fail
                if (expect_empty == tr.empty) begin
                    $display("pass : fifo empty signal");
                    empty_pass_count++;
                end else begin
                    $display("fail : fifo empty signal");
                    empty_fail_count++;
                end


                // ── 2) 내 모델도 DUT 와 똑같이 움직여 준다 ────────────────────
                //  꽉 찼는데 push 가 들어오면 DUT 는 무시한다. 모델도 무시해야
                //  둘이 계속 같은 상태로 간다. 그래서 !expect_full 조건이 붙는다.
                if (!expect_full & tr.push) begin
                    expect_fifo.push_back(tr.push_data);
                end

                if(!expect_empty & tr.pop) begin // else, else if가 아닌 if로 하는 이유? 동시에 push, pop이 들어올 수 있어서.
                    //  → else if 로 묶으면 push 가 1 일 때 pop 검사를 건너뛴다.
                    //    시나리오 3 에서 push=1, pop=1 이 같이 오는데 그걸 놓친다.
                    //    둘은 서로 배타가 아니므로 독립된 if 두 개여야 한다.

                    // pass/fail
                    //  pop_front() : 큐 맨 앞을 꺼내면서 큐에서도 지운다.
                    //  그 값이 DUT 가 내놓은 pop_data 와 같아야 한다.
                    //  = FIFO 가 "먼저 넣은 것을 먼저" 내놓았는지 확인하는 것.
                    if (expect_fifo.pop_front() == tr.pop_data) begin
                        pass_count++;
                        $display("pass");
                    end else begin
                        fail_count++;
                        $display("fail");
                    end
                end

                // coverage updata
                //  sample()  :  지금 tr 과 fifo_size 값을 커버리지에 한 번 기록.
                //  부르지 않으면 covergroup 이 있어도 아무것도 세지 않는다.
                //  판정이 다 끝난 뒤에 부르는 이유 : fifo_size 가 이 시점의
                //  값으로 확정돼 있어야 깊이 커버리지가 맞다.
                cg_fifo.sample();
            end

            ->gen_next_evt;   // "이번 건 다 처리했다" → generator 의 @(gen_next_evt)
                              // 가 풀리고 다음 자극이 만들어진다.
                              // rst 샘플일 때도 쏴 줘야 generator 가 안 멈춘다.
        end
    endtask

    //  report  :  시험이 끝난 뒤 집계를 한 번에 찍는다.
    //  get_coverage()  :  그 coverpoint 의 달성률을 % 로 돌려주는 내장 함수.
    //  %% 는 $display 에서 % 글자 하나를 찍기 위한 표기다(% 는 서식 시작 문자라서).
    task report();
        $display("*****************************************");
        $display("*******  fifo verification test   *******");
        $display("*****************************************");
        $display("*******  total test num = %5d *******", total_count);
        $display("*******  pass test num  = %5d *******", pass_count);
        $display("*******  fail test num  = %5d *******", fail_count);
        $display("**  full pass test num  = %5d *******", full_pass_count);
        $display("**  full fail test num  = %5d *******", full_fail_count);
        $display("**  empty pass test num = %5d *******", empty_pass_count);
        $display("**  empty fail test num = %5d *******", empty_fail_count);
        $display("*****************************************");
        $display("***    fifo test coverage    ***");
        $display("***    coverage push data = %4.2f %%    ***",
                 cg_fifo.cp_push_data.get_coverage());
        $display("*** coverage push, pop, op = %4.2f %% ***",
                 cg_fifo.cp_push_pop.get_coverage());
        $display("***    coverage full, empty st = %4.2f %%    ***",
                 cg_fifo.cp_full_empty.get_coverage());
        $display("***    coverage fifo depth = %4.2f %%    ***",
                 cg_fifo.cp_fifo_size.get_coverage());
        $display("***    coverage cx_op_st = %4.2f %%    ***",
                 cg_fifo.cx_op_st.get_coverage());
        $display("***    coverage cx_op_depth = %4.2f %%    ***",
                 cg_fifo.cx_op_depth.get_coverage());

        $display("*****************************************");
    endtask

endclass


//-----------------------------------------------------------------------------
//  ⑦ environment  :  위 네 개를 한 상자에 담아 한꺼번에 만들고 돌리는 쪽
//
//  module 쪽에서 gen·drv·mon·scb·mailbox 를 전부 따로 new 하고 연결하면
//  module 이 지저분해지고 실수하기 쉽다. 연결 배선을 여기 한곳에 모았다.
//-----------------------------------------------------------------------------
class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    mailbox #(transaction) gen2drv_mbox;   // generator → driver
    mailbox #(transaction) mon2scb_mbox;   // monitor   → scoreboard
    event gen_next_evt;                    // scoreboard → generator

    function new(virtual fifo_interface fifo_vif);
        this.gen2drv_mbox = new;    // mailbox 실체를 여기서 하나씩 만들고
        this.mon2scb_mbox = new;
        //  같은 handle 을 양쪽에 넘겨서 둘이 같은 통로를 쓰게 만든다.
        //  gen 과 drv 에 gen2drv_mbox 를 똑같이 준 것이 곧 '연결' 이다.
        gen               = new(gen2drv_mbox, gen_next_evt);
        drv               = new(gen2drv_mbox, fifo_vif);
        mon               = new(mon2scb_mbox, fifo_vif);
        scb               = new(mon2scb_mbox, gen_next_evt);
    endfunction

    task run(int run_count);
        drv.preset();        // 먼저 리셋을 끝내 놓고 (여기서 assertion 이 검사됨)

        //  fork ~ join_any  :  안의 네 task 를 동시에 출발시킨다.
        //      join      : 넷이 다 끝나야 다음 줄로 간다
        //      join_any  : 하나만 끝나도 다음 줄로 간다  ← 이걸 쓴 이유
        //      join_none : 기다리지 않고 바로 다음 줄로 간다
        //  drv·mon·scb 는 forever 라 영영 안 끝난다. gen.run() 만 정해진
        //  횟수를 돌고 끝나므로, join_any 면 "자극을 다 넣은 순간" 다음 줄로
        //  넘어가 보고서를 찍을 수 있다. join 이었다면 영원히 멈춰 선다.
        fork
            gen.run(run_count);
            drv.run();
            mon.run();
            scb.run();

        join_any
        #1;  // #10 하는 이유? 꼭 필요한가? 왜?
             //  → gen 이 마지막 자극을 put 하고 끝난 그 시각에는 mon·scb 가
             //    아직 그 건을 처리하지 못했을 수 있다. 잠깐 시간을 줘서
             //    마지막 한 건까지 집계에 들어가게 하려는 것이다.
             //    #1 로 충분한지는 마지막 샘플이 negedge(monitor) 를 지났는지에
             //    달려 있다. 안전하게 하려면 "scb 가 total_count 를 다 셀
             //    때까지" 를 조건으로 기다리는 쪽이 정확하다. (확인 안 해 봄)
        scb.report();
        $display("end fifo test test !!");
    endtask
endclass


//-----------------------------------------------------------------------------
//  ⑧ top module  :  합성 대상이 아닌 시뮬레이션 최상위. 여기만 module 이다.
//
//  클래스는 스스로 시작하지 못한다. 반드시 module 의 initial 안에서
//  new 로 만들어 주고 task 를 불러 줘야 돌아간다.
//-----------------------------------------------------------------------------
module tb_fifo_sv ();
    logic clk;

    //  interface 실체를 여기서 하나 만든다. 괄호의 clk 이 interface 의
    //  input clk 에 연결된다. 이 fifo_if 를 environment 에 넘기면 그 안의
    //  driver·monitor 가 virtual handle 로 같은 신호를 쓰게 된다.
    fifo_interface fifo_if (clk);

    environment env;

    //  DUT 연결. 이름으로 연결(.포트(신호))해서 순서가 바뀌어도 안전하게 한다.
    //  fifo_if.rst 처럼 점으로 꺼내 쓰면 interface 안의 신호에 바로 붙는다.
    fifo_sv dut (
        .clk      (clk),
        .rst      (fifo_if.rst),
        .push_data(fifo_if.push_data),
        .push     (fifo_if.push),
        .pop      (fifo_if.pop),
        .pop_data (fifo_if.pop_data),
        .full     (fifo_if.full),
        .empty    (fifo_if.empty)
    );

    //  5ns 마다 반전 → 주기 10ns = 100MHz 클럭
    always #5 clk = ~clk;

    initial begin
        clk = 0;              // x 로 시작하면 ~x 가 계속 x 라 클럭이 안 뛴다.
                              // 반드시 0 이나 1 로 초기화해야 한다.
        env = new(fifo_if);   // 검증 환경을 만들면서 interface 를 넘겨 준다
        env.run(1000);        // 커버리지 100 % 확인판 : 시나리오마다 1000 번씩 → 총 3000 건
        $finish;              // 시뮬레이션 종료
    end

endmodule
