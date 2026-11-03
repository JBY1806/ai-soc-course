# ppa_v3 결과 모으기: 판 4개 × 옵션 5개 → LUT · FF · Slice · WNS · WHS · 전력(전체/동적)
#   Fmax 환산 = 1000 / (10 - WNS) MHz  (100 MHz 제약에서 남은 여유로 거꾸로 계산한 근사값, 그 클럭으로 다시 구현한 값 아님)
import os, re
base = os.path.dirname(os.path.abspath(__file__))
VARS = [('class', '① 수업 방식'), ('before', '② 기존 팀 판'), ('after', '③ ② + enable'), ('hybrid', '④ 최종 (기능마다 100 Hz)')]
STRATS = [('', '기본값'), ('A_area_', 'Area 합성'), ('B_area2_', 'Area 합성+구현'), ('C_power_', 'Power'), ('D_perf_', 'Performance')]

def grab(path, pat, grp=1):
    s = open(path, encoding='utf-8', errors='ignore').read()
    m = re.search(pat, s, re.M)
    return m.group(grp) if m else '?'

def row(v, p):
    d = os.path.join(base, v)
    u = os.path.join(d, p + 'util_impl.rpt'); t = os.path.join(d, p + 'timing.rpt'); w = os.path.join(d, p + 'power.rpt')
    if not os.path.exists(u): return None
    lut = int(grab(u, r'^\| Slice LUTs\s+\|\s+(\d+)'))
    ff = int(grab(u, r'^\| Slice Registers\s+\|\s+(\d+)'))
    sl = int(grab(u, r'^\| Slice\s+\|\s+(\d+)'))
    s = open(t, encoding='utf-8', errors='ignore').read()
    i = s.index('WNS(ns)'); nums = s[i:].split('\n')[2].split()
    wns, whs = float(nums[0]), float(nums[4])
    tot = float(grab(w, r'Total On-Chip Power \(W\)\s+\|\s+([\d.]+)'))
    dyn = float(grab(w, r'^\| Dynamic \(W\)\s+\|\s+([\d.]+)'))
    return lut, ff, sl, wns, whs, tot, dyn

print('판 | 옵션 | LUT | FF | Slice | WNS | WHS | Fmax환산 | 전체W | 동적W')
for v, vn in VARS:
    base_r = row(v, '')
    for p, pn in STRATS:
        r = row(v, p)
        if r is None: print(vn, pn, '없음'); continue
        lut, ff, sl, wns, whs, tot, dyn = r
        dl = '' if p == '' else f' ({lut - base_r[0]:+d})'
        print(f'{vn} | {pn} | {lut}{dl} | {ff} | {sl} | {wns:+.3f} | {whs:.3f} | {1000/(10-wns):.0f} MHz | {tot:.3f} | {dyn:.3f}')
