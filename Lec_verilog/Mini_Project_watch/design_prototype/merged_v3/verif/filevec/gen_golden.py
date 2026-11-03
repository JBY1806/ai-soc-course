# [작성] 입력 파일 · 정답(golden) 파일 생성기 — LeNet 레이어별 파일과 같은 방식
#   단계 1 (hour_12_24)     : in_h1224.hex  -> exp_h1224.hex          (조합회로, 64개 전수)
#   단계 2 (watch_control)  : in_cu.hex     -> exp_cu.hex             (버튼 · 스위치 -> cursor · up · down)
#   단계 3 (watch_datapath) : in_dp.hex     -> exp_dp.hex             (in_dp 의 cursor · up · down = exp_cu 정답 그대로)
# 정답은 RTL 을 돌린 결과가 아니라, 사양을 파이썬으로 따로 옮긴 모델이 만든다.
# 사용: python gen_golden.py [seed]
import random, sys, os

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
rnd = random.Random(seed)
out = os.path.dirname(os.path.abspath(__file__))

def wr(name, rows, width):
    with open(os.path.join(out, name), 'w') as f:
        for r in rows:
            f.write('%0*x\n' % (width, r))

# ---------------- 단계 1: 12/24 시간 표시 (sw_12h = 1 -> 12시간) ----------------
h_in, h_exp = [], []
for sw in (0, 1):
    for h in range(32):                      # 0~23 정상 + 24~31 범위 밖도 그대로 넣음
        if sw == 0:
            oh = h
        elif h == 0:
            oh = 12                          # 자정 = 오전 12시
        elif h > 12:
            oh = (h - 12) & 0x1f             # 13~23 -> 1~11 (범위 밖 값도 5비트로 자름)
        else:
            oh = h
        pm = 1 if h >= 12 else 0
        h_in.append((sw << 5) | h)
        h_exp.append((pm << 5) | oh)
wr('in_h1224.hex', h_in, 2)
wr('exp_h1224.hex', h_exp, 2)

# ---------------- 단계 2: 시계 컨트롤 유닛 모델 ----------------
NORMAL, SET_HOUR, SET_MIN_10, SET_MIN_1 = 0, 1, 2, 3
CUR = {NORMAL: 3, SET_HOUR: 2, SET_MIN_10: 1, SET_MIN_1: 0}

def cu_step(st, sw_set, L, R, U, D):
    """한 클럭: (지금 상태, 이번 입력) -> (출력, 다음 상태). 출력은 이번 클럭 동안의 값."""
    set_mode = 0 if st == NORMAL else 1
    cursor = CUR[st]
    up = down = 0
    if st != NORMAL and sw_set:
        up = U
        down = D & (1 - U)                   # U, D 같이 오면 U 우선
    nst = st
    if st == NORMAL:
        if sw_set: nst = SET_MIN_1           # 설정 진입은 항상 분 일의 자리
    elif not sw_set:
        nst = NORMAL                         # 스위치 내림이 버튼보다 먼저
    elif L:
        nst = {SET_MIN_1: SET_MIN_10, SET_MIN_10: SET_HOUR, SET_HOUR: SET_MIN_1}[st]
    elif R:
        nst = {SET_MIN_1: SET_HOUR, SET_HOUR: SET_MIN_10, SET_MIN_10: SET_MIN_1}[st]
    return (set_mode, cursor, up, down), nst

# ---------------- 단계 3: 시계 데이터패스 모델 (클럭 단위, 리플 1클럭 지연 포함) ----------------
class Cnt:
    def __init__(s, times, init):
        s.times, s.v, s.ot = times, init, 0
    def step(s, tick, up, down, step10):
        st = 10 if step10 else 1
        if tick:
            if s.v == s.times - 1: nv, no = 0, 1
            else:                  nv, no = s.v + 1, 0
        else:
            no = 0
            if up:     nv = (s.v + st) % s.times
            elif down: nv = (s.v - st) % s.times
            else:      nv = s.v
        return nv, no

# ---------------- 자극 만들기: 랜덤 구간 + 경계 구간 ----------------
cu_in = []          # (sw_set, L, R, U, D)
tick_col = []       # 데이터패스 tick (TB 가 직접 줌: 설계 파라미터는 안 건드림)

sw_set = 0
for i in range(3000):                        # 랜덤: 버튼 1클럭 펄스, 가끔 sw_set 전환, tick 은 30 %
    if rnd.random() < 0.01: sw_set ^= 1
    b = [1 if rnd.random() < 0.04 else 0 for _ in range(4)]
    cu_in.append((sw_set, *b)); tick_col.append(1 if rnd.random() < 0.3 else 0)

# 경계: 모델로 상태를 따라가며 23:59 를 만든 뒤 tick 을 매 클럭 줘서 자정 넘김까지
def replay():
    st = NORMAL; c = [Cnt(100, 0), Cnt(60, 0), Cnt(60, 0), Cnt(24, 12)]
    for (s, L, R, U, D), t in zip(cu_in, tick_col):
        (sm, cur, up, dn), st2 = cu_step(st, s, L, R, U, D)
        c, _ = dp_step(c, t, cur, up, dn); st = st2
    return st, c

def dp_step(c, tick, cur, up, dn):
    ms, se, mi, ho = c
    min_up = up and cur in (0, 1); min_dn = dn and cur in (0, 1)
    h_up = up and cur == 2;        h_dn = dn and cur == 2
    r = [ms.step(tick, 0, 0, 0), se.step(ms.ot, 0, 0, 0), mi.step(se.ot, min_up, min_dn, cur == 1), ho.step(mi.ot, h_up, h_dn, 0)]
    for k, (nv, no) in enumerate(r):
        c[k].v, c[k].ot = nv, no
    return c, r

def push(s, L=0, R=0, U=0, D=0, n_idle=3):
    cu_in.append((s, L, R, U, D)); tick_col.append(0)
    for _ in range(n_idle):
        cu_in.append((s, 0, 0, 0, 0)); tick_col.append(0)

push(0); push(1)                             # NORMAL -> SET_MIN_1
st, c = replay()
while st != SET_HOUR: push(1, L=1); st, c = replay()
while c[3].v != 23:   push(1, U=1); st, c = replay()
push(1, R=1)                                 # -> SET_MIN_10
st, c = replay()
while c[2].v // 10 != 5: push(1, U=1); st, c = replay()
push(1, R=1)                                 # -> SET_MIN_1
st, c = replay()
while c[2].v != 59:   push(1, U=1); st, c = replay()
# 코너 1 (랜덤으로는 거의 안 나옴): 설정 중 tick 을 매 클럭 주고, 초가 넘어가는 바로 그 클럭에 D
#   -> 분 카운터에 "tick(+1) 과 버튼(-1)" 이 같은 클럭. 사양: tick 만 반영 (23:59 -> 00:00)
st, c = replay()
for i in range(6100):
    D = 1 if c[1].ot == 1 else 0             # 지금 클럭의 초 o_tick = 분 카운터의 i_tick
    (sm, cur, up, dn), st = cu_step(st, 1, 0, 0, 0, D)
    c, _ = dp_step(c, 1, cur, up, dn)
    cu_in.append((1, 0, 0, 0, D)); tick_col.append(1)
# 코너 2: sw_set 을 내리는 그 클럭에 L, 다시 들어가서 내리는 그 클럭에 U -> 둘 다 무시돼야 함
cu_in.append((0, 1, 0, 0, 0)); tick_col.append(0)
push(0); push(1)
cu_in.append((0, 0, 0, 1, 0)); tick_col.append(0)
push(0)                                      # 설정 끝 -> NORMAL
push(1)                                      # 자정 넘김을 보려고 다시 23:59 로 (이번엔 D 로 내려서)
st, c = replay()
while c[2].v != 59: push(1, D=1); st, c = replay()
push(1, L=1); push(1, L=1)                   # SET_MIN_1 -> SET_MIN_10 -> SET_HOUR
st, c = replay()
while c[3].v != 23: push(1, D=1); st, c = replay()
push(0)
for i in range(12500):                       # tick 매 클럭 -> 23:59:xx 에서 자정 넘김 (초 59 -> 0 두 번)
    U = 1 if (i % 997 == 500) else 0         # 가끔 U (NORMAL 이라 무시돼야 함)
    cu_in.append((0, 0, 0, U, 0)); tick_col.append(1)

# ---------------- 정답 계산 ----------------
st = NORMAL; c = [Cnt(100, 0), Cnt(60, 0), Cnt(60, 0), Cnt(24, 12)]
cu_rows_in, cu_rows_exp, dp_rows_in, dp_rows_exp = [], [], [], []
saw_midnight = False
for (s, L, R, U, D), t in zip(cu_in, tick_col):
    (sm, cur, up, dn), nst = cu_step(st, s, L, R, U, D)
    cu_rows_in.append((s << 4) | (L << 3) | (R << 2) | (U << 1) | D)
    cu_rows_exp.append((sm << 4) | (cur << 2) | (up << 1) | dn)
    # 데이터패스 입력 = 컨트롤 유닛 "정답" 출력 + tick  (LeNet: 레이어2 입력 = 레이어1 정답 출력)
    dp_rows_in.append((t << 4) | (cur << 2) | (up << 1) | dn)
    c, _ = dp_step(c, t, cur, up, dn)
    v = (c[3].v << 19) | (c[2].v << 13) | (c[1].v << 7) | c[0].v
    dp_rows_exp.append(v)
    if c[3].v == 0 and c[2].v == 0 and c[1].v == 0: saw_midnight = True
    st = nst

wr('in_cu.hex', cu_rows_in, 2);  wr('exp_cu.hex', cu_rows_exp, 2)
wr('in_dp.hex', dp_rows_in, 2);  wr('exp_dp.hex', dp_rows_exp, 6)
print('seed %d: h1224 %d vectors, cu/dp %d clocks, midnight reached: %s' % (seed, len(h_in), len(cu_rows_in), saw_midnight))
