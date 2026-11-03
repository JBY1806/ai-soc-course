# [] 변이(mutation) 테스트: 설계에 bug 를 하나씩 심고 3가지 검증(단위 TB · Top 지시형 TB · SV 랜덤)이 잡는지
# 사용: python run_mutation.py   (merged_v3/verif 에서)   결과: log/mutation_results.md
import os, shutil, subprocess, sys, re, time
from concurrent.futures import ThreadPoolExecutor
sys.stdout.reconfigure(encoding='utf-8')
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '..', 'src')
MUT = os.path.join(HERE, 'mut')
X = r'C:\Xilinx\Vivado\2022.2\bin'
os.makedirs(MUT, exist_ok=True)

MUTANTS = [
 ('M01', 'watch_control_unit.v', "n_state = SET_MIN_1;  // 설정 들어가면 항상 분 일의 자리(맨 오른쪽)부터", "n_state = SET_HOUR;  // 설정 들어가면 항상 분 일의 자리(맨 오른쪽)부터", '설정 진입을 시 자리로'),
 ('M02', 'watch_control_unit.v', "o_down = btn_down & ~btn_up;", "o_down = btn_down;", 'U+D 동시에 둘 다 1'),
 ('M03', 'watch_control_unit.v', "            SET_MIN_1: begin\n                cursor = CUR_MIN_1;\n                if (sw_set == 1'b0) begin\n                    n_state = NORMAL;\n                end else if (btn_left == 1'b1) begin\n                    n_state = SET_MIN_10;",
                                  "            SET_MIN_1: begin\n                cursor = CUR_MIN_1;\n                if (btn_left == 1'b1) begin\n                    n_state = SET_MIN_10;\n                end else if (sw_set == 1'b0) begin\n                    n_state = NORMAL;", 'sw_set=0 보다 L 우선(분 일 자리)'),
 ('M04', 'watch_datapath.v', "            if (i_tick) begin\n                // tick 우선", "            if (i_tick && !i_up && !i_down) begin\n                // tick 우선", 'tick 과 버튼 동시면 버튼 우선'),
 ('M05', 'watch_datapath.v', "assign w_step = (i_step10) ? 4'd10 : 4'd1;", "assign w_step = 4'd1;", '분 십의 자리 +10 무시'),
 ('M06', 'watch_datapath.v', "if (counter_reg + w_step >= TIMES) begin", "if (counter_reg + w_step > TIMES) begin", '+step 돌기 경계(>=) 틀림'),
 ('M07', 'stopwatch_control_unit.v', "            RUN: begin\n                if (btn_run_stop)\n                    n_state = STOP;", "            RUN: begin\n                if (1'b0)\n                    n_state = STOP;", 'RUN 에서 정지 불가'),
 ('M08', 'stopwatch_datapath.v', "assign w_tick_10ms = i_tick_10ms & run_stop;", "assign w_tick_10ms = i_tick_10ms;", '정지 중에도 셈'),
 ('M09', 'stopwatch_datapath.v', "                    if (counter_reg == 0) begin\n                        counter_reg <= TIMES - 1;", "                    if (counter_reg == 0) begin\n                        counter_reg <= TIMES - 2;", '다운 돌기 값 틀림'),
 ('M10', 'lap_controller.v', "assign disp_msec = lap_enable ? save_msec : msec;", "assign disp_msec = msec;", '랩 중 msec 고정 안 됨'),
 ('M11', 'timer_datapath.v', "assign w_over = (min_sum >= 60);", "assign w_over = (min_sum > 60);", '타이머 상한 경계 틀림'),
 ('M12', 'timer_datapath.v', "                        sec_reg <= 59;", "                        sec_reg <= 58;", '타이머 초 빌림 값 틀림'),
 ('M13', 'timer_control_unit.v', "if (btn_left | btn_right | btn_up | btn_down) begin", "if (btn_left) begin", '알람 끄기 L 만'),
 ('M14', 'timer_control_unit.v', "if (i_zero == 1'b0) begin", "if (1'b1) begin", '0 에서도 시작'),
 ('M15', 'hour_12_24.v', "            o_hour = 12;            // 자정 00시 -> 오전 12시", "            o_hour = 0;            // 자정 00시 -> 오전 12시", '12시간 표시 0시 -> 0'),
 ('M16', 'SW2_ANODE_CHOICE.v', "if({i_sw_2,i_sw_1,i_sw_0}==3'b110)begin", "if({i_sw_2,i_sw_1,i_sw_0}==3'b111)begin", '점멸 조건 스위치 틀림'),
 ('M17', 'dot.v', "assign o_dot_onoff = (i_msec >=50) ? 1:0;", "assign o_dot_onoff = 1;", '점 항상 꺼짐(점멸 없음)'),
 ('M18', 'fnd_decoder.v', "4'h5: o_fnd_data = 8'h92;", "4'h5: o_fnd_data = 8'h93;", '숫자 5 세그먼트 틀림'),
 ('M19', 'stopwatch_watch.v', "assign w_sel_sw = ~sw_timer & sw_mode;", "assign w_sel_sw = sw_mode;", '타이머 화면에서 스톱워치도 버튼 받음'),
 ('M20', 'stopwatch_watch.v', "(w_sel_wt & ~sw_24h & w_pm);  // 오후", "(w_sel_wt & w_pm);  // 오후", '24시간 표시에서도 PM LED'),
 ('M21', 'btn_debounce.v', "assign o_btn = ~debounce_reg&debounce;", "assign o_btn = debounce;", '디바운서 출력이 펄스 아닌 레벨'),
 ('M22', 'clock_tick_generator.v', "if(r_counter == FCOUNT -1)begin", "if(r_counter == FCOUNT)begin", '4 kHz 분주 1클럭 느림'),
 ('M23', 'tick_gen_100hz.v', "if (counter_reg == F_COUNT - 1) begin", "if (counter_reg == F_COUNT - 2) begin", '100 Hz tick 1클럭 빠름'),
 ('M24', 'stopwatch_watch.v', "assign w_disp_mode = sw_timer | sw_display_mode;", "assign w_disp_mode = sw_display_mode;", '타이머 화면 분.초 고정 안 됨'),
 ('M25', 'watch_datapath.v', "        .INIT(12)", "        .INIT(0)", '시계 시작 00시'),
 ('M26', 'timer_datapath.v', "min_sum = min_reg + ((amount == 2'd1) ? 7'd1 : (amount == 2'd2) ? 7'd10 : 7'd0) + carry;", "min_sum = min_reg + ((amount == 2'd1) ? 7'd1 : (amount == 2'd2) ? 7'd10 : 7'd0);", '초 -> 분 올림 누락'),
]
UNIT = {   # 파일 -> (단위 TB 이름, TB 파일, 소스 목록)
 'watch_control_unit.v': [('watch_cu', 'tb_watch_cu_unit.v', ['watch_control_unit.v'])],
 'watch_datapath.v': [('watch_cnt', 'tb_watch_tick_counter.v', ['watch_datapath.v']), ('watch_dp', 'tb_watch_dp_unit.v', ['watch_datapath.v'])],
 'stopwatch_control_unit.v': [('sw_cu', 'tb_stopwatch_cu_unit.v', ['stopwatch_control_unit.v'])],
 'stopwatch_datapath.v': [('sw_dp', 'tb_stopwatch_dp_unit.v', ['stopwatch_datapath.v', 'lap_controller.v'])],
 'lap_controller.v': [('lap', 'tb_lap_unit.v', ['lap_controller.v']), ('sw_dp', 'tb_stopwatch_dp_unit.v', ['stopwatch_datapath.v', 'lap_controller.v'])],
 'timer_datapath.v': [('timer', 'tb_timer_unit.v', ['timer_control_unit.v', 'timer_datapath.v'])],
 'timer_control_unit.v': [('timer', 'tb_timer_unit.v', ['timer_control_unit.v', 'timer_datapath.v'])],
 'hour_12_24.v': [('hour1224', 'tb_hour_12_24_unit.v', ['hour_12_24.v'])],
 'SW2_ANODE_CHOICE.v': [('fnd', 'tb_fnd_unit.v', ['SW2_FND_CONTROLLER.v', 'SW2_ANODE_CHOICE.v', 'counter8.v', 'decoder_2x4.v', 'digit_splitter.v', 'dot.v', 'fnd_decoder.v', 'mux_8x1.v'])],
 'dot.v': [('fnd', 'tb_fnd_unit.v', ['SW2_FND_CONTROLLER.v', 'SW2_ANODE_CHOICE.v', 'counter8.v', 'decoder_2x4.v', 'digit_splitter.v', 'dot.v', 'fnd_decoder.v', 'mux_8x1.v'])],
 'fnd_decoder.v': [('fnd', 'tb_fnd_unit.v', ['SW2_FND_CONTROLLER.v', 'SW2_ANODE_CHOICE.v', 'counter8.v', 'decoder_2x4.v', 'digit_splitter.v', 'dot.v', 'fnd_decoder.v', 'mux_8x1.v'])],
 'btn_debounce.v': [('debounce', 'tb_btn_debounce_unit.v', ['btn_debounce.v', 'clock_tick_generator.v'])],
 'clock_tick_generator.v': [('debounce', 'tb_btn_debounce_unit.v', ['btn_debounce.v', 'clock_tick_generator.v']), ('tickgens', 'tb_tickgens_unit.v', ['tick_gen_100hz.v', 'clock_tick_generator.v'])],
 'tick_gen_100hz.v': [('tickgens', 'tb_tickgens_unit.v', ['tick_gen_100hz.v', 'clock_tick_generator.v'])],
 'stopwatch_watch.v': [],
}

def sh(cmd, cwd, timeout):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=timeout, shell=True)
        return r.stdout + r.stderr
    except subprocess.TimeoutExpired:
        return 'TIMEOUT(driver)'

def verdict(log):
    m = re.search(r'TOTAL MISMATCH = (\d+)', log)
    if 'TIMEOUT' in log or 'COMPILE' in log: return 'CAUGHT(timeout/compile)'
    if m is None: return 'NO-RESULT'
    return 'CAUGHT' if int(m.group(1)) != 0 else 'missed'

def run_mutant(m):
    mid, fname, a, b, desc = m
    d = os.path.join(MUT, mid); s = os.path.join(d, 'src')
    shutil.rmtree(d, ignore_errors=True); shutil.copytree(SRC, s)
    p = os.path.join(s, fname); t = open(p, encoding='utf-8').read()
    assert t.count(a) == 1, (mid, a[:50])
    open(p, 'w', encoding='utf-8').write(t.replace(a, b))
    res = {'id': mid, 'file': fname, 'desc': desc}
    # 단위 TB
    units = []
    for (un, tb, srcs) in UNIT.get(fname, []):
        srcp = ' '.join('"%s"' % os.path.join(s, x) for x in srcs)
        out = sh('iverilog -g2005 -o %s.vvp "%s" %s && timeout 1200 vvp -n %s.vvp' % (un, os.path.join(HERE, 'v', tb), srcp, un), d, 1500)
        units.append('%s:%s' % (un, verdict(out)))
        open(os.path.join(d, 'unit_%s.log' % un), 'w', encoding='utf-8').write(out)
    res['unit'] = ' '.join(units) if units else '-'
    # Top 지시형 (iverilog)
    allsrc = ' '.join('"%s"' % os.path.join(s, x) for x in sorted(os.listdir(s)) if x.endswith('.v'))   # cmd.exe 는 *.v 를 안 풀어 줌
    out = sh('iverilog -g2005 -o dir.vvp "%s" %s && timeout 1200 vvp -n dir.vvp' % (os.path.join(HERE, 'v', 'tb_top_directed.v'), allsrc), d, 1500)
    open(os.path.join(d, 'directed.log'), 'w', encoding='utf-8').write(out)
    res['directed'] = verdict(out)
    # SV 랜덤 (xsim, seed 1)
    xd = os.path.join(d, 'xsim'); os.makedirs(xd, exist_ok=True)
    open(os.path.join(xd, 'run.tcl'), 'w').write('run all\nquit\n')
    out = sh('"%s\\xvlog.bat" -sv "%s" %s && "%s\\xelab.bat" tb_top_random -s snap -timescale 1ns/1ps && "%s\\xsim.bat" snap --tclbatch run.tcl --sv_seed 1' % (X, os.path.join(HERE, 'sv', 'tb_top_random.sv'), allsrc, X, X), xd, 1500)
    open(os.path.join(d, 'sv_random.log'), 'w', encoding='utf-8').write(out)
    res['sv'] = verdict(out)
    print('%s %-28s unit[%s] directed[%s] sv[%s]' % (mid, desc, res['unit'], res['directed'], res['sv']), flush=True)
    return res

if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser(); ap.add_argument('--ids', default=''); ap.add_argument('--out', default='mutation_results.md'); ap.add_argument('--workers', type=int, default=3)
    args = ap.parse_args()
    sel = [m for m in MUTANTS if (not args.ids or m[0] in args.ids.split(','))]
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        results = list(ex.map(run_mutant, sel))
    lines = ['# 변이 테스트 결과 (merged_v3, %s)' % time.strftime('%Y-%m-%d %H:%M'), '',
             '| ID | 파일 | 심은 bug | 단위 TB | Top 지시형 (Verilog) | SV 랜덤 (seed 1, 20 ms) |', '|---|---|---|---|---|---|']
    for r in results:
        lines.append('| %s | %s | %s | %s | %s | %s |' % (r['id'], r['file'], r['desc'], r['unit'], r['directed'], r['sv']))
    n = len(results)
    cu = sum(1 for r in results if 'CAUGHT' in r['unit']); cd = sum(1 for r in results if 'CAUGHT' in r['directed']); cs = sum(1 for r in results if 'CAUGHT' in r['sv'])
    ca = sum(1 for r in results if 'CAUGHT' in (r['unit'] + r['directed'] + r['sv']))
    lines += ['', '- 잡힘: 단위 %d/%d, 지시형 %d/%d, SV 랜덤 %d/%d, 셋 중 하나라도 %d/%d' % (cu, n, cd, n, cs, n, ca, n), '- 소요 %.0f 분' % ((time.time() - t0) / 60)]
    open(os.path.join(HERE, 'log', args.out), 'w', encoding='utf-8').write('\n'.join(lines))
    print('\n'.join(lines[-2:]))
