# 미니 프로젝트 (3인) — Basys-3 스톱워치 · 시계 · 타이머

- **과정** : AI 시스템반도체 설계 2기, 2과목 Verilog HDL
- **기간** : 2026-10-13 ~ 10-19 (발표 10/19, 보완 제출 10/24)
- **보드 · 툴** : Digilent Basys-3 (Artix-7 XC7A35T, 100 MHz) · Vivado 2022.2
- **팀 코드 저장소** : [kimsacademy1234-max/BEST_Stop_watch_project](https://github.com/kimsacademy1234-max/BEST_Stop_watch_project) — 이 저장소에는 [`../BEST_Stop_watch_project/`](../BEST_Stop_watch_project/) 로 옮겨 둠 (`PROJECT_MINI_WTS/` · `verification_v2/`)

이 폴더는 팀 저장소에 없는 **제출본 · 발표 자료 · 내 담당 검증 자료**를 모은 곳입니다.

---

## 1. 무엇을 만들었나

스위치로 스톱워치 · 시계 · 타이머를 골라 쓰는 설계. 시뮬레이션은 클럭을 줄이지 않고 실제 시간 (100 MHz) 기준으로 확인.

| 항목 | 결과 |
|---|---|
| 기능 | 스톱워치 (업 · 다운 · 랩), 시계 (자리 단위 시간 설정 · 12/24 시간), 타이머 (최대 59:59, 알람 LED 점멸) |
| 검증 | 팀 SV TB 13 개 · 검사 447 PASS, 타이머 Verilog TB 4 개 불일치 0, 결함 주입 4 종 |
| 자원 · 타이밍 | LUT 384 · FF 228 · WNS +3.440 ns @ 100 MHz (배치 · 배선 후) |
| 트러블슈팅 | ① 100 Hz tick 공유 → 10 초 타이머가 9.998 초 → 스톱워치 · 타이머 전용 tick 으로 10.000 초 ② 버튼 디바운서 시프트 클럭 1 MHz → 4 kHz |

## 2. 내가 맡은 부분

- 시계 (워치) 제어 FSM, 팀 통합판 보드 확인
- 타이머 발표 · 시뮬레이션 검증 (TB 3 개 21 · 41 · 11 검사 PASS, 파형 25 장)
- 타이머 TB 를 수업 Verilog 문법으로 옮김 + 결함 주입 2 개 (59:59 상한 제거 → FAIL 7, RUN 중 U 받기 → FAIL 1)
- tick 공유 / 분리 4 가지 구조의 자원 · 위상 비교 (트러블슈팅 ①)
- 발표 트러블슈팅 · 결론 파트

## 3. 폴더

| 경로 | 내용 |
|---|---|
| [`submit_1019/`](submit_1019/) | **최종 제출본** (10/24) : `1_PPT` 발표 자료 · `2_Simulation` TB 로그 · `3_Code` 설계 + TB · `4_Video` 보드 영상 |
| [`final_present/v2.0/`](final_present/v2.0/) · [`팀원판/`](final_present/팀원판/) | 발표 자료 (우리 판 v2.0 · 팀 발표판 v2.6) |
| [`BEST_stopwatch_presentation_v2.8.pptx`](BEST_stopwatch_presentation_v2.8.pptx) | 발표 당일 팀 최종판 |
| [`timer_present/`](timer_present/) · [`timer_slides/`](timer_slides/) | 타이머 발표 (v0.1 ~ v0.5) · 타이머 시뮬레이션 검증 보고 |
| [`timer_tb_verilog/`](timer_tb_verilog/) · [`timer_capture/`](timer_capture/) | 타이머 Verilog TB · 결함 주입 실행 결과, 타이머 파형 캡처 |
| [`tick_compare/`](tick_compare/) · [`tick공유_트레이드오프.html`](tick공유_트레이드오프.html) · [`PPA_캡처_1016/`](PPA_캡처_1016/) | tick 공유 / 분리 비교 그림 · 정리, 구현 Before / After 보고서 캡처 |
| [`board_video/`](board_video/) | 보드 동작 영상 (스톱워치 · 시계 · 타이머 · 타이머 상한) |
| [`ai_eval/`](ai_eval/) | 담임 교수님 과제 "AI 기반 프로젝트 검증 도구" — 평가 기준 · 사전학습 자료 · 세션 기록 · 점수 · 대시보드 |
| [`ppa_experiments/`](ppa_experiments/) | 발표 · 제출 수치의 근거가 된 자원 · 타이밍 비교 실험 : tick 공유 / 분리 4 구조 (`ppa_v2` ~ `ppa_v4`), 합성 전략 비교 (`ppa_v3`), 모듈별 자원 (`ppa_module`), 공통 분주기 실험 (`ppa_shared`). 각 폴더의 보고서 (`*.rpt`) · 요약 README |
