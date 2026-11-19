`timescale 1ns / 1ps  // # 숫자의 단위 1 ns, 정밀도 1 ps (%t 는 ps 로 찍힘)

// =====================================================================
// RAM (64 칸 x 8 비트) 검증 TB — 과제판 (방법 A : gen2scb_mbox · 매 cycle 판독) + skip · 합 계산 report
//   흐름 : generator → (mailbox 1) → driver → interface → DUT → interface → monitor → (mailbox 2) → scoreboard
//          generator → (mailbox 3) → scoreboard           : 정답 (기대값) 을 scoreboard 에 직접 보냄
//          scoreboard 판정 끝 → (event gen_next_evt) → generator 다음 객체
//          driver 쓰기 끝   → (event mon_next_evt) → monitor 읽기 시작
//   driver 는 하강 엣지에 <= 로 쓰고, monitor 는 그다음 하강 엣지 (10 ns 뒤) 에 = 로 읽음 → 쓰기 객체도 쓰기 후 값을 읽어 비교
//   주석만 정리한 판 (코드 · 동작은 20261112_ram_sv_hw 프로젝트 tb_ram_sv.sv 와 같음)
// =====================================================================

// ---------------------------------------------------------------------
// interface : DUT 포트에 연결할 신호 묶음 (class 는 DUT 포트에 직접 못 닿으므로 이걸 거쳐 씀)
// ---------------------------------------------------------------------
interface ram_interface (
    input logic clk  // clk 는 module 이 만들어 포트로 넣어 줌
);
    // DUT 입력 쪽
    logic [5:0] addr;  // 번지 0 ~ 63 (2^6 = 64 칸)
    logic [7:0] wdata;  // 쓸 값
    logic       we;  // 1 = 쓰기, 0 = 읽기만
    // DUT 출력 쪽
    logic [7:0] rdata;  // addr 번지에 들어 있는 값
endinterface

// ---------------------------------------------------------------------
// transaction : 값 한 묶음의 형식 (클래스 정의 = 틀. 객체는 new 할 때 생김)
// ---------------------------------------------------------------------
class transaction;
    // 멤버 변수 : rand = randomize() 가 랜덤 값을 넣는 변수
    rand bit [5:0] addr;  // 0 ~ 63
    rand bit [7:0] wdata;  // 0 ~ 255
    rand bit we;  // 0 · 1 (constraint 가 없어 반반 확률)
    logic    [7:0] rdata;  // DUT 출력 (monitor 가 채움) — logic 이라 x 도 담음

    // 멤버 함수 : 로그 한 줄 출력 (시간을 안 쓰므로 function)
    function void debug_print(
        string name
    );  // name = 로그 앞 이름 (GEN · DRV · MON · SCB)
        $display("%t : [%s] addr = %d, wdata = %d, we = %d, rdata = %d", $time,
                 name, addr, wdata, we, rdata);
    endfunction

endclass


// ---------------------------------------------------------------------
// generator : 랜덤 객체를 만들어 driver 에게 보내고, 같은 값의 복사본을 scoreboard 에 정답으로 보냄
// ---------------------------------------------------------------------
class generator;
    // 멤버 변수 선언
    transaction tr;                       // transaction 핸들 (객체는 run 안의 new 에서 생김)
    transaction tr_scb;                   // scoreboard 로 보낼 복사본 핸들 (정답)
    mailbox #(transaction) gen2drv_mbox;  // mailbox 1 핸들 (객체는 environment 가 만들어 넘겨줌)
    mailbox #(transaction) gen2scb_mbox;  // mailbox 3 핸들 : generator → scoreboard (정답)
    event gen_next_evt;  // scoreboard 가 "판정 끝, 다음" 을 알릴 event

    // 생성자 (constructor) : environment 의 gen = new(…) 때 한 번 실행
    //   인자로 받은 mailbox · event 를 멤버에 저장 (this. = 이 객체의 멤버)
    function new(mailbox#(transaction) gen2drv_mbox,
                 mailbox#(transaction) gen2scb_mbox, event gen_next_evt);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen2scb_mbox = gen2scb_mbox;        
        this.gen_next_evt = gen_next_evt;
    endfunction

    // 실행 task : run_count 번 반복 (시간을 쓰는 줄 @ 가 있어서 function 이 아니라 task)
    task run(int run_count);
        repeat (run_count) begin
            tr = new;  // 객체 생성
            tr_scb = new;    // 복사본 객체를 따로 생성
            tr.randomize();  // addr · wdata · we 에 랜덤 값
            // tr 값을 tr_scb 로 하나씩 복사 — 같은 핸들을 두 mailbox 에 넣으면 driver · scoreboard 가 객체 하나를 같이 보게 됨
            tr_scb.addr = tr.addr;
            tr_scb.wdata = tr.wdata;
            tr_scb.we = tr.we;
            tr_scb.rdata = tr.rdata;
            gen2drv_mbox.put(tr);  // mailbox 1 에 넣음 → driver 가 꺼냄
            gen2scb_mbox.put(tr_scb);  // mailbox 3 에 넣음 → scoreboard 가 정답으로 꺼냄
            tr.debug_print("GEN");
            tr_scb.debug_print("GEN");  // 복사본도 출력 (위 줄과 같은 값이어야 함)
            @(gen_next_evt);        // scoreboard 판정이 끝날 때까지 기다림 → 한 번에 객체 하나
        end
    endtask

endclass


// ---------------------------------------------------------------------
// driver : mailbox 1 에서 꺼낸 값을 interface (→ DUT 입력) 에 씀
// ---------------------------------------------------------------------
class driver;
    // 멤버 변수 선언
    transaction tr;  // 꺼낸 객체를 가리킬 핸들
    mailbox #(transaction) gen2drv_mbox;  // mailbox 1 핸들 (generator 와 같은 mailbox)
    event mon_next_evt;  // monitor 에게 "값을 넣었다" 알릴 event
    virtual ram_interface ram_vif;        // interface 를 가리키는 핸들 (virtual interface)

    // 생성자 : environment 가 넘긴 mailbox · event · interface 를 멤버에 저장
    function new(mailbox#(transaction) gen2drv_mbox, event mon_next_evt,
                 virtual ram_interface ram_vif);
        this.gen2drv_mbox = gen2drv_mbox;
        this.mon_next_evt = mon_next_evt;
        this.ram_vif = ram_vif;
    endfunction

    // 실행 task : 끝없이 반복 (forever)
    task run();
        forever begin
            @(negedge ram_vif.clk);     // 하강 엣지까지 기다림 (10 · 20 · 30 … ns)
                                        //   DUT 가 값을 받는 상승 엣지와 5 ns 떨어뜨려 같은 시각에 바뀌지 않게
            gen2drv_mbox.get(
                tr);       // mailbox 1 에서 꺼냄 (비었으면 여기서 기다림)
            ram_vif.addr <= tr.addr;     // interface → DUT 입력에 씀 (논블로킹 <= : 이 시각 맨 끝 NBA 영역에서 바뀜
                                         //   → 같은 하강 엣지에 블로킹으로 읽는 monitor 는 항상 앞 객체 값을 읽음)
            ram_vif.wdata <= tr.wdata;
            ram_vif.we <= tr.we;
            tr.debug_print("DRV");
            ->>mon_next_evt;  // monitor 에게 알림 (->> 논블로킹 : 이 시각의 NBA 영역에서 발생)

        end
    endtask

endclass


// ---------------------------------------------------------------------
// monitor : interface (DUT 입력 · 출력) 값을 읽어 scoreboard 로 보냄
// ---------------------------------------------------------------------
class monitor;
    // 멤버 변수 선언
    transaction tr;  // 읽은 값을 담을 객체 핸들
    mailbox #(transaction) mon2scb_mbox;  // mailbox 2 핸들 (scoreboard 와 같은 mailbox)
    event mon_next_evt;  // driver 와 같은 event
    virtual ram_interface ram_vif;  // interface 를 가리키는 핸들

    // 생성자 : environment 가 넘긴 mailbox · event · interface 를 멤버에 저장
    function new(mailbox#(transaction) mon2scb_mbox, event mon_next_evt,
                 virtual ram_interface ram_vif);
        this.mon2scb_mbox = mon2scb_mbox;
        this.mon_next_evt = mon_next_evt;
        this.ram_vif = ram_vif;
    endfunction

    // 실행 task : 끝없이 반복 (forever)
    task run();
        forever begin
            wait (mon_next_evt.triggered);  // 이 시각에 driver 알림이 이미 왔거나 오면 통과 (@ 와 달리 먼저 온 알림도 봄)
            //@(posedge ram_vif.clk);         // (수업 판) 그다음 상승 엣지 — 쓰기와 같은 엣지라 쓰기 전 값을 읽었음
            @(negedge ram_vif.clk);         // driver 가 쓴 그다음 하강 엣지 (10 ns 뒤) — 사이 상승 엣지에 RAM 쓰기가 끝남
            tr = new;  // 읽은 값을 담을 새 객체
            tr.addr = ram_vif.addr;  // DUT 입력 3 개 읽음
            tr.wdata = ram_vif.wdata;
            tr.we = ram_vif.we;
            tr.rdata = ram_vif.rdata;       // DUT 출력 읽음 — 쓰기 "후" 라 쓰기 객체면 방금 쓴 값
            mon2scb_mbox.put(
                tr);  // mailbox 2 에 넣음 → scoreboard 가 꺼냄
            tr.debug_print("MON");
        end
    endtask
endclass


// ---------------------------------------------------------------------
// scoreboard : generator 의 정답 (mailbox 3) 과 monitor 의 실제 값 (mailbox 2) 을 같은 순번끼리 꺼내 매 객체 비교
// ---------------------------------------------------------------------
class scoreboard;
    // 멤버 변수 선언
    transaction            tr;  // monitor 에서 온 객체 핸들
    transaction tr_gen;                    // generator 에서 온 정답 객체 핸들
    mailbox #(transaction) mon2scb_mbox;  // mailbox 2 핸들
    mailbox #(transaction) gen2scb_mbox;  // mailbox 3 핸들    
    event                  gen_next_evt;  // generator 와 같은 event

    // 생성자 : environment 가 넘긴 mailbox · event 를 멤버에 저장
    function new(mailbox#(transaction) mon2scb_mbox, mailbox#(transaction) gen2scb_mbox,  event gen_next_evt);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen2scb_mbox = gen2scb_mbox;
        this.gen_next_evt = gen_next_evt;
    endfunction

    logic [7:0] expected_buf[0:63];  // 정답 사본 (RAM 과 같은 64 칸) — logic 이라 시작이 x (안 쓴 번지 = x)
    int
        total_count = 0,
        pass_count = 0,
        fail_count = 0,
        skip_count = 0;  // 받은 객체 수 · 맞음 · 틀림 · 판정 안 함
    int
        write_count = 0,  // 쓰기 객체 (we = 1) 수
        new_addr_count = 0,   // 처음 쓰는 번지 (새 칸) 에 쓴 수 = 한 번이라도 써진 칸 수
        overwrite_count = 0,  // 이미 쓴 번지에 다시 쓴 수
        read_count = 0;  // 읽기 객체 (we = 0) 수

    // 실행 task : 끝없이 반복 (forever)
    task run();
        forever begin
            gen2scb_mbox.get(tr_gen);   // mailbox 3 에서 이번 정답을 꺼냄 (비었으면 기다림)
            mon2scb_mbox.get(
                tr);  // mailbox 2 에서 꺼냄 (비었으면 기다림)
            tr.debug_print("SCB");
            total_count++;  // 받은 객체마다 1 (= 쓰기 + 읽기)
            if (tr_gen.we) begin        // 정답 쪽 we 로 쓰기 / 읽기를 나눔
                // we = 1 (쓰기) : 정답 사본에 저장한 뒤 바로 비교
                //   (monitor 가 쓰기 후 하강 엣지에 읽었으므로 rdata 는 방금 쓴 값이어야 함)
                write_count++;
                if (expected_buf[tr_gen.addr] === 8'bx) begin  // 저장하기 전에 판단 : 아직 x = 처음 쓰는 칸
                    new_addr_count++;
                end else begin  // 값이 있음 = 덮어쓰기
                    overwrite_count++;
                end
                expected_buf[tr_gen.addr] = tr_gen.wdata;          // DUT 와 같은 번지에 같은 값 저장
                if (expected_buf[tr_gen.addr] === tr.rdata) begin  // 방금 쓴 값이 rdata 로 나왔나
                    $display("Pass (write)");
                    pass_count++;
                end else begin
                    $display("Fail (write)");
                    fail_count++;
                end
            end else begin
                // we = 0 (읽기) : 그 번지 정답과 DUT rdata 비교
                read_count++;
                $display("expected = %d", expected_buf[tr.addr]);
                if (expected_buf[tr_gen.addr] === 8'bx) begin
                    // 한 번도 안 쓴 번지 = 정답 없음 → 판정 안 함 (x === x 로 Pass 가 되는 것을 막음)
                    $display("Skip (not written yet)");
                    skip_count++;
                end else if (expected_buf[tr_gen.addr] === tr.rdata) begin
                    // === (case equality) : x · z 까지 글자 그대로 비교 (== 는 x 가 섞이면 결과가 x)
                    $display("Pass");
                    pass_count++;
                end else begin
                    $display("Fail");
                    fail_count++;
                end
            end
            ->gen_next_evt
                ;  // generator 를 깨워 다음 객체 (블로킹 ->)
        end
    endtask

    // 결과 출력 task (environment run 끝에서 부름)
    //   %d = int 최대 글자 수 (11 칸) 를 잡아 앞에 공백, %0d = 공백 없이 숫자만
    task report();
        $display("***********************************");
        $display("** ram size 64 write / read test **");
        $display("***********************************");
        $display("** ram total test num = %d **", total_count);
        $display("** ram pass test num = %d **", pass_count);
        $display("** ram fail test num = %d **", fail_count);
        $display("** ram skip test num = %d **", skip_count);
        $display("***********************************");
        // 합해서 total 이 되는지 보이게 (compared = pass + fail : 비교하면 반드시 둘 중 하나로 셈)
        $display("** total = write + read : %0d = %0d + %0d", total_count,
                 write_count, read_count);
        $display("** write = new addr + overwrite : %0d = %0d + %0d",
                 write_count, new_addr_count, overwrite_count);
        // (쓰기도 비교하므로 read = compared + skip 은 안 맞음 → total 기준으로 바꿈)
        //$display("** read = compared + skip : %0d = %0d + %0d", read_count,
        //         pass_count + fail_count, skip_count);
        $display("** total = compared + skip : %0d = %0d + %0d", total_count,
                 pass_count + fail_count, skip_count);
        $display("** compared = pass + fail : %0d = %0d + %0d",
                 pass_count + fail_count, pass_count, fail_count);
        $display("** skip = read of never-written address (expected x)");
        $display("** written address : %0d / 64",
                 new_addr_count);  // 64 칸 중 써진 칸
        $display("***********************************");



    endtask

endclass


// ---------------------------------------------------------------------
// environment : 컴포넌트 4 개 · mailbox 3 개 · event 2 개를 만들고 이어 줌
// ---------------------------------------------------------------------
class environment;
    // 핸들 선언 (클래스 타입 변수 — 아직 null, 객체는 아래 new 에서)
    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    // mailbox 핸들 선언 (아직 null)
    mailbox #(transaction) gen2drv_mbox;  // mailbox 1 : generator → driver
    mailbox #(transaction) gen2scb_mbox;  // mailbox 3 : generator → scoreboard (정답)
    mailbox #(transaction) mon2scb_mbox;  // mailbox 2 : monitor → scoreboard

    // event 선언 (new 없이 선언만으로 씀 — 같은 event 를 양쪽에 넘겨 줌)
    event gen_next_evt;  // scoreboard → generator
    event mon_next_evt;  // driver → monitor

    // 생성자 : module 의 env = new(ram_if) 때 한 번 실행 (인자 = interface)
    function new(virtual ram_interface ram_vif);
        // mailbox 객체 생성
        gen2drv_mbox = new;
        gen2scb_mbox = new;
        mon2scb_mbox = new;
        // 객체 생성 (인스턴스 생성) + 연결 : 괄호 안 = 각 생성자에 넘기는 mailbox · event · interface
        gen = new(gen2drv_mbox, gen2scb_mbox, gen_next_evt);
        drv = new(gen2drv_mbox, mon_next_evt, ram_vif);
        mon = new(mon2scb_mbox, mon_next_evt, ram_vif);
        scb = new(mon2scb_mbox, gen2scb_mbox, gen_next_evt);
    endfunction

    // 시험 진행 task
    task run(int run_count);
        fork  // 아래 4 개 run 을 동시에 시작
            gen.run(run_count);  // run_count 번 뒤 끝남
            drv.run();  // forever (안 끝남)
            mon.run();  // forever
            scb.run();  // forever
        join_any                  // 하나라도 끝나면 (= generator) 다음 줄로. 나머지 셋은 계속 살아 있음
        #10;  // 마지막 판정이 끝날 시간
        scb.report();  // 결과 출력
    endtask
endclass



// ---------------------------------------------------------------------
// module (top) : 시뮬레이터가 맨 처음 만드는 것 — clk · interface · DUT · environment
// ---------------------------------------------------------------------
module tb_ram_sv ();
    logic clk = 0;                 // clk 신호 + 시작값 0 (없으면 x 를 뒤집어도 x 라 엣지가 안 생김)
    ram_interface ram_if (
        clk
    );  // interface 인스턴스 (clk 를 포트로 넣음)

    environment env;  // environment 핸들 선언 (아직 null)

    // DUT 인스턴스 : clk 는 module 의 clk, 나머지 4 개는 interface 신호에 연결
    ram_ip_sv dut (
        .clk(clk),
        .addr(ram_if.addr),
        .wdata(ram_if.wdata),
        .we(ram_if.we),
        .rdata(ram_if.rdata)
    );

    always #5
        clk = ~clk;  // 10 ns 주기 : 상승 5 · 15 …, 하강 10 · 20 …
    initial begin
        env = new(ram_if);  // environment 객체 생성 + interface 넘김
        env.run(
            100);              // 객체 100 개 시험 (끝날 때까지 여기서 기다림)
        $finish;  // 시뮬레이션 끝 (forever 셋도 같이 끝)
    end


endmodule
