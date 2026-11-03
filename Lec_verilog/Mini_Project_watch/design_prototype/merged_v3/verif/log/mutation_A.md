# 변이 테스트 결과 (merged_v3, 2026-10-16 12:42)

| ID | 파일 | 심은 bug | 단위 TB | Top 지시형 (Verilog) | SV 랜덤 (seed 1, 20 ms) |
|---|---|---|---|---|---|
| M05 | watch_datapath.v | 분 십의 자리 +10 무시 | watch_cnt:CAUGHT watch_dp:CAUGHT | CAUGHT(timeout/compile) | missed |
| M07 | stopwatch_control_unit.v | RUN 에서 정지 불가 | sw_cu:CAUGHT | CAUGHT | CAUGHT |
| M08 | stopwatch_datapath.v | 정지 중에도 셈 | sw_dp:CAUGHT | CAUGHT | CAUGHT |
| M09 | stopwatch_datapath.v | 다운 돌기 값 틀림 | sw_dp:CAUGHT | CAUGHT | CAUGHT |
| M10 | lap_controller.v | 랩 중 msec 고정 안 됨 | lap:CAUGHT sw_dp:CAUGHT | CAUGHT | CAUGHT |
| M11 | timer_datapath.v | 타이머 상한 경계 틀림 | timer:CAUGHT | CAUGHT | missed |
| M12 | timer_datapath.v | 타이머 초 빌림 값 틀림 | timer:missed | CAUGHT | CAUGHT |
| M13 | timer_control_unit.v | 알람 끄기 L 만 | timer:CAUGHT | CAUGHT | CAUGHT |
| M14 | timer_control_unit.v | 0 에서도 시작 | timer:CAUGHT | CAUGHT | CAUGHT |
| M15 | hour_12_24.v | 12시간 표시 0시 -> 0 | hour1224:CAUGHT | CAUGHT | missed |

- 잡힘: 단위 9/10, 지시형 10/10, SV 랜덤 7/10, 셋 중 하나라도 10/10
- 소요 9 분