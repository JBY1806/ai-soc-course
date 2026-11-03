# 모듈별 자원 사용량 (10/19, 배치 실행)

- 소스: `C:\work\BEST_Stop_watch_project\verification_v2\source_file` (최종 코드) 를 `src\` 로 복사
- 도구: Vivado 2022.2, xc7a35tcpg236-1 (Basys-3), 구현(route) 후 `report_utilization -hierarchical`
- `default\` : 기본 합성 (실제 보드에 올라가는 결과). 전체 LUT 384 · FF 228, WNS +3.440 ns
- `keep_hier\` : `-flatten_hierarchy none` (모듈 경계 유지). 전체 LUT 401 · FF 228, WNS +2.097 ns
  - 기본 합성은 모듈 경계를 넘어 논리를 합쳐서, 화면 MUX · FND 디코더 등이 counter8 · 디바운서 쪽에 섞여 보고됨
    → 모듈별로 나눠 볼 때는 keep_hier 숫자를 쓴다 (경계를 유지한 만큼 전체가 17 LUT 많음)
- `no_hour\` : keep_hier 와 같은 조건에서 timer_datapath 의 hour_reg 만 지운 판 (TB 는 안 돌림)

## 기능별 합계 (keep_hier)

| 묶음 | 포함 인스턴스 | LUT | FF |
|---|---|---|---|
| 시계 | WATCH_CONTROL_UNIT 3/2 · WATCH_DATAPATH 59/27 · TICK_GEN_100HZ 25/21 · HOUR_12_24 3/0 | 90 | 50 |
| 스톱워치 | STOPWATCH_CONTROL_UNIT 2/2 · STOPWATCH_DATAPATH 76/52 (랩 26/25 포함) · TICK_GEN_SW 31/21 | 109 | 75 |
| 타이머 (정보윤 담당) | TIMER_CONTROL_UNIT 6/3 · TIMER_DATAPATH 50/24 · TICK_GEN_TM 31/21 | 87 | 48 |
| 공통 | 디바운서 4개 12/36 · 4 kHz 분주 12/16 · FND 컨트롤러 51/3 · Top 직접 논리(게이팅 · 화면 MUX · LED) 42/0 | 117 | 55 |

- 인스턴스 LUT 를 더하면 403, 보고서 전체는 401 (2 차이, 원인 미확인). FF 는 228 로 맞음.

## hour_reg 제거 실험 (no_hour)

| | timer_datapath LUT | FF | 전체 LUT | FF |
|---|---|---|---|---|
| 최종 코드 | 50 | 24 | 401 | 228 |
| hour_reg 제거 | 44 | 19 | 395 | 223 |
