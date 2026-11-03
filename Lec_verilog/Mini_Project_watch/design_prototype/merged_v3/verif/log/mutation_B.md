# 변이 테스트 결과 (merged_v3, 2026-10-16 12:44)

| ID | 파일 | 심은 bug | 단위 TB | Top 지시형 (Verilog) | SV 랜덤 (seed 1, 20 ms) |
|---|---|---|---|---|---|
| M16 | SW2_ANODE_CHOICE.v | 점멸 조건 스위치 틀림 | fnd:CAUGHT | CAUGHT | CAUGHT |
| M17 | dot.v | 점 항상 꺼짐(점멸 없음) | fnd:CAUGHT | CAUGHT | CAUGHT |
| M18 | fnd_decoder.v | 숫자 5 세그먼트 틀림 | fnd:CAUGHT | CAUGHT | CAUGHT |
| M19 | stopwatch_watch.v | 타이머 화면에서 스톱워치도 버튼 받음 | - | CAUGHT | CAUGHT |
| M20 | stopwatch_watch.v | 24시간 표시에서도 PM LED | - | CAUGHT | CAUGHT |
| M21 | btn_debounce.v | 디바운서 출력이 펄스 아닌 레벨 | debounce:CAUGHT | CAUGHT(timeout/compile) | missed |
| M22 | clock_tick_generator.v | 4 kHz 분주 1클럭 느림 | debounce:missed tickgens:CAUGHT | missed | missed |
| M23 | tick_gen_100hz.v | 100 Hz tick 1클럭 빠름 | tickgens:CAUGHT | CAUGHT | missed |
| M24 | stopwatch_watch.v | 타이머 화면 분.초 고정 안 됨 | - | CAUGHT | CAUGHT |
| M25 | watch_datapath.v | 시계 시작 00시 | watch_cnt:missed watch_dp:CAUGHT | CAUGHT(timeout/compile) | CAUGHT |
| M26 | timer_datapath.v | 초 -> 분 올림 누락 | timer:CAUGHT | CAUGHT | missed |

- 잡힘: 단위 8/11, 지시형 10/11, SV 랜덤 7/11, 셋 중 하나라도 11/11
- 소요 11 분