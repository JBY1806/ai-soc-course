# -*- coding: utf-8 -*-
"""
결과보고서 PPT 생성기.

교수님이 주신 양식(최종보고서(포맷예시)(포맷자유).pptx)의 6개 장 구성을 따르고,
오늘까지 실측한 수치와 게임 캡처를 채워 넣는다.

실행:
    Lec_python\\집에서_미리해보기\\.venv\\Scripts\\python.exe make_report_ppt.py

만들어지는 것:
    AI_시스템반도체_설계_2기_결과보고서(정보윤).pptx
"""
import os
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR

NAME = '정보윤'
OUT = 'AI_시스템반도체_설계_2기_결과보고서(%s).pptx' % NAME

SHOT = r'C:\Users\kccistc\Pictures\Screenshots\가위바위보'
IMG_GAME = os.path.join(SHOT, 'v3', '스크린샷 2026-09-17 173242.png')
IMG_V3TERM = os.path.join(SHOT, 'v3', '스크린샷 2026-09-17 173724.png')
IMG_V1TERM = os.path.join(SHOT, 'v1', '스크린샷 2026-09-17 173714.png')

# 색
NAVY = RGBColor(0x1F, 0x3B, 0x63)
BLUE = RGBColor(0x2E, 0x6D, 0xB4)
GRAY = RGBColor(0x55, 0x55, 0x55)
RED = RGBColor(0xC0, 0x39, 0x2B)
GREEN = RGBColor(0x1E, 0x8A, 0x4C)
LIGHT = RGBColor(0xEE, 0xF3, 0xF9)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
FONT = '맑은 고딕'

prs = Presentation()
prs.slide_width = Inches(13.333)
prs.slide_height = Inches(7.5)
BLANK = prs.slide_layouts[6]

W = prs.slide_width
H = prs.slide_height


def setfont(run, size=14, bold=False, color=None, font=FONT):
    run.font.name = font
    run.font.size = Pt(size)
    run.font.bold = bold
    if color is not None:
        run.font.color.rgb = color
    # 한글 글꼴을 동아시아 글꼴로도 지정해야 안 깨진다
    rPr = run._r.get_or_add_rPr()
    from pptx.oxml.ns import qn
    ea = rPr.find(qn('a:ea'))
    if ea is None:
        ea = rPr.makeelement(qn('a:ea'), {})
        rPr.append(ea)
    ea.set('typeface', font)


def textbox(slide, x, y, w, h, align=PP_ALIGN.LEFT):
    tb = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = tb.text_frame
    tf.word_wrap = True
    tf.paragraphs[0].alignment = align
    return tf


def para(tf, text, size=14, bold=False, color=None, space_before=4, first=False,
         align=PP_ALIGN.LEFT, indent=0):
    p = tf.paragraphs[0] if first else tf.add_paragraph()
    p.alignment = align
    p.space_before = Pt(space_before)
    p.level = indent
    r = p.add_run()
    r.text = text
    setfont(r, size, bold, color)
    return p


def slide_header(slide, num, title, sub=None):
    """상단 제목 띠."""
    bar = slide.shapes.add_shape(1, 0, 0, W, Inches(1.0))   # 1 = 사각형
    bar.fill.solid()
    bar.fill.fore_color.rgb = NAVY
    bar.line.fill.background()
    tf = bar.text_frame
    tf.margin_left = Inches(0.45)
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    p = tf.paragraphs[0]
    r = p.add_run()
    r.text = ('%s. %s' % (num, title)) if num else title
    setfont(r, 26, True, WHITE)
    if sub:
        p2 = tf.add_paragraph()
        r2 = p2.add_run()
        r2.text = sub
        setfont(r2, 13, False, RGBColor(0xC8, 0xD8, 0xEE))


def conclusion_box(slide, x, y, w, text, color=BLUE, size=15):
    """두괄식 결론 상자."""
    box = slide.shapes.add_shape(1, Inches(x), Inches(y), Inches(w), Inches(0.62))
    box.fill.solid()
    box.fill.fore_color.rgb = LIGHT
    box.line.color.rgb = color
    box.line.width = Pt(1.5)
    tf = box.text_frame
    tf.margin_left = Inches(0.2)
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    tf.word_wrap = True
    r = tf.paragraphs[0].add_run()
    r.text = text
    setfont(r, size, True, NAVY)
    return box


def table(slide, x, y, w, rows, col_w=None, size=12, head_size=12,
          highlight_rows=(), highlight_col=None, row_h=0.32):
    """rows[0] 이 머리글. highlight_rows 는 강조할 행 번호(0부터)."""
    nr, nc = len(rows), len(rows[0])
    shp = slide.shapes.add_table(nr, nc, Inches(x), Inches(y), Inches(w),
                                 Inches(row_h * nr))
    tbl = shp.table
    if col_w:
        total = sum(col_w)
        for i, cw in enumerate(col_w):
            tbl.columns[i].width = Emu(int(Inches(w) * cw / total))
    for i, row in enumerate(rows):
        tbl.rows[i].height = Inches(row_h)
        for j, val in enumerate(row):
            cell = tbl.cell(i, j)
            cell.margin_left = Inches(0.06)
            cell.margin_top = Inches(0.02)
            cell.margin_bottom = Inches(0.02)
            cell.vertical_anchor = MSO_ANCHOR.MIDDLE
            tf = cell.text_frame
            tf.word_wrap = True
            p = tf.paragraphs[0]
            p.alignment = PP_ALIGN.CENTER if j > 0 else PP_ALIGN.LEFT
            r = p.add_run()
            r.text = str(val)
            if i == 0:
                setfont(r, head_size, True, WHITE)
                cell.fill.solid()
                cell.fill.fore_color.rgb = NAVY
            else:
                emph = (i in highlight_rows) or (highlight_col is not None and j == highlight_col)
                setfont(r, size, emph, RED if emph else GRAY)
                cell.fill.solid()
                cell.fill.fore_color.rgb = LIGHT if (i in highlight_rows) else WHITE
    return tbl


def note(slide, x, y, w, text, size=11, color=GRAY):
    tf = textbox(slide, x, y, w, 0.5)
    para(tf, text, size, False, color, first=True)


def picture(slide, path, x, y, h=None, w=None):
    if not os.path.exists(path):
        ph = slide.shapes.add_shape(1, Inches(x), Inches(y),
                                    Inches(w or 4), Inches(h or 2.5))
        ph.fill.solid()
        ph.fill.fore_color.rgb = LIGHT
        ph.line.color.rgb = GRAY
        r = ph.text_frame.paragraphs[0].add_run()
        r.text = '[그림 자리]\n' + os.path.basename(path)
        setfont(r, 11, False, GRAY)
        return ph
    kw = {}
    if h:
        kw['height'] = Inches(h)
    if w:
        kw['width'] = Inches(w)
    return slide.shapes.add_picture(path, Inches(x), Inches(y), **kw)


def caption(slide, x, y, w, text):
    tf = textbox(slide, x, y, w, 0.3, PP_ALIGN.CENTER)
    para(tf, text, 10, True, BLUE, first=True, align=PP_ALIGN.CENTER)


# ═══════════════════════════════════════════════════════════
# 표지
# ═══════════════════════════════════════════════════════════
s = prs.slides.add_slide(BLANK)
bg = s.shapes.add_shape(1, 0, 0, W, H)
bg.fill.solid()
bg.fill.fore_color.rgb = NAVY
bg.line.fill.background()

tf = textbox(s, 1.0, 2.1, 11.3, 1.0)
para(tf, 'AI 시스템반도체 SW개발자 (2기)', 18, False,
     RGBColor(0xA9, 0xC4, 0xE4), first=True)
tf = textbox(s, 1.0, 2.7, 11.3, 1.6)
para(tf, '라즈베리파이 5 + YOLO11n 기반', 30, True, WHITE, first=True)
para(tf, '2인용 가위바위보 게임 On-Device 구현', 40, True, WHITE)

line = s.shapes.add_shape(1, Inches(1.0), Inches(4.75), Inches(3.2), Pt(3))
line.fill.solid()
line.fill.fore_color.rgb = RGBColor(0x5B, 0x9B, 0xD5)
line.line.fill.background()

tf = textbox(s, 1.0, 5.0, 11.3, 1.4)
para(tf, '프로젝트 결과보고서', 20, True, RGBColor(0xC8, 0xD8, 0xEE), first=True)
para(tf, NAME, 18, False, WHITE, space_before=10)
para(tf, '2026. 09. 18.', 14, False, RGBColor(0xA9, 0xC4, 0xE4))

# ═══════════════════════════════════════════════════════════
# 목차
# ═══════════════════════════════════════════════════════════
s = prs.slides.add_slide(BLANK)
slide_header(s, None, '목차')
items = [
    ('1', '주제 및 결과 요약', '무엇을 만들었고 결과가 얼마인가'),
    ('2', '개발 목표 및 개발 결과', '5단계 과제 구현 + 추가로 한 것'),
    ('3', '핵심 기술', '검출 파이프라인 · 모델 경량화 · 데이터셋 도구'),
    ('4', '결과 분석 및 기대 효과', '두 개의 시험지로 드러난 실제 성능'),
    ('5', '향후 연구 과제', '남은 문제와 해결 방향'),
    ('6', '프로젝트 수행 후기', '측정으로 배운 것'),
]
y = 1.5
for n, t, d in items:
    box = s.shapes.add_shape(1, Inches(1.2), Inches(y), Inches(0.62), Inches(0.62))
    box.fill.solid()
    box.fill.fore_color.rgb = BLUE
    box.line.fill.background()
    r = box.text_frame.paragraphs[0].add_run()
    r.text = n
    setfont(r, 20, True, WHITE)
    box.text_frame.paragraphs[0].alignment = PP_ALIGN.CENTER
    tf = textbox(s, 2.1, y - 0.02, 9.5, 0.7)
    para(tf, t, 19, True, NAVY, first=True)
    para(tf, d, 12, False, GRAY, space_before=1)
    y += 0.92

# ═══════════════════════════════════════════════════════════
# 1. 주제 및 결과 요약
# ═══════════════════════════════════════════════════════════
s = prs.slides.add_slide(BLANK)
slide_header(s, '1', '주제 및 결과 요약')

conclusion_box(s, 0.5, 1.2, 12.3,
               '학습 데이터를 82장 → 724장으로 늘려, 실사용 조건 검출 성능 mAP50 0.475 → 0.851 (+79%) 달성',
               size=16)

tf = textbox(s, 0.5, 2.05, 6.0, 2.0)
para(tf, '■ 주제', 15, True, NAVY, first=True)
para(tf, '라즈베리파이 5 단독(On-Device)으로 동작하는 2인용 가위바위보 게임. '
         'YOLO11n이 화면 속 두 손을 찾아 좌/우로 플레이어를 나누고 승패를 판정한다.', 12.5)
para(tf, '■ 목표', 15, True, NAVY, space_before=12)
para(tf, '① 교수님 제시 5단계 과제 전부 구현  ② 보드 단독 실시간 동작  '
         '③ 실제 사용 환경에서 쓸 수 있는 인식 정확도 확보', 12.5)

rows = [
    ['결과 항목', '수치', '조건'],
    ['실사용 검출 성능', 'mAP50 0.475 → 0.851 (+79%)', '새 사진 160장 · 박스 218개'],
    ['승패 판정 정확도', '9가지 조합 중 3/9 → 9/9', '보드 실측'],
    ['처리 속도', '68.1 FPS', '320×320 INT8 · CPU 4스레드 · MJPG'],
    ['모델 크기', '10.1 MB → 2.9 MB (3.5배 축소)', 'PTQ INT8 (입출력 float32)'],
    ['학습 데이터', '82장 → 724장 (8.8배)', '박스 100개 → 987개'],
]
table(s, 6.75, 2.05, 6.1, rows, col_w=[2.0, 2.6, 2.4], size=11, head_size=11,
      highlight_rows=(1, 2), row_h=0.42)

note(s, 6.75, 5.0, 6.1,
     '※ 학습 설정(모델·epoch·증강)은 한 글자도 바꾸지 않고 데이터만 늘렸다.\n'
     '   개선의 원인을 데이터 하나로 특정할 수 있게 하기 위함.')

picture(s, IMG_GAME, 0.5, 4.2, h=2.6)
caption(s, 0.5, 6.85, 4.7, '▲ 그림 1. 게임 실행 화면 (P1 보 vs P2 바위 → P1 승, 68.1 FPS)')

# ═══════════════════════════════════════════════════════════
# 2-1. 개발 목표 : 5단계
# ═══════════════════════════════════════════════════════════
s = prs.slides.add_slide(BLANK)
slide_header(s, '2', '개발 목표 및 개발 결과', '2-1. 교수님 제시 5단계 과제 — 전부 구현 완료')

conclusion_box(s, 0.5, 1.25, 12.3, '5단계 전 과제 구현 완료. 각 단계의 근거 코드와 실행 화면을 아래에 명시')

rows = [
    ['단계', '구현 과제', '구현', '근거 (RPS_Game.py)'],
    ['1단계', 'Bounding Box X좌표로 P1(좌)/P2(우) 나누기', '완료',
     'split_players() — 상자 중심 x 기준 정렬'],
    ['2단계', 'P1 Class vs P2 Class 비교해 승/무/패 출력', '완료',
     'BEATS = {0:2, 1:0, 2:1} 표 기반 judge()'],
    ['3단계', '손이 2개가 아닐 때 예외 메시지', '완료',
     'len(boxes) 분기 → 화면 하단 안내 문구'],
    ['4단계', '3-2-1 카운트다운 후 판정 순간 Freeze', '완료',
     '상태 기계 + frozen = frame.copy()'],
    ['5단계', '스코어보드 · 승패 효과음 · 재시작 키', '완료',
     'draw_scoreboard() / play() / SPACE·r·q'],
]
table(s, 0.5, 2.1, 12.3, rows, col_w=[1.0, 4.4, 0.9, 5.0], size=11.5, row_h=0.45)

tf = textbox(s, 0.5, 4.9, 12.3, 2.2)
para(tf, '■ 4단계 상태 기계 — 실패하던 판정을 고친 부분', 14, True, NAVY, first=True)
para(tf, 'READY  ─SPACE→  COUNT(3초)  ─0초→  JUDGING(유예 2초)  ─손 2개→  RESULT(2.5초)  →  READY',
     13, True, BLUE, space_before=8)
para(tf, '처음에는 카운트가 0이 되는 "한 프레임"에서만 판정했다. 그러나 보드는 초당 11장을 처리하므로 '
         '그 순간에 두 손이 정확히 잡힐 확률이 낮아 거의 매번 판정이 취소되었다. '
         'JUDGING 유예 구간(2초)을 두어 "0이 된 뒤 두 손이 처음 잡히는 프레임"으로 판정하도록 바꿔 해결했다.',
     12, space_before=8)
para(tf, '→ 유예 안에 두 손을 못 찾으면 Cancelled 안내 후 READY로 복귀 (3단계 예외 처리와 연결)',
     12, True, GREEN, space_before=6)

# ═══════════════════════════════════════════════════════════
# 2-2. 5단계 밖으로 더 한 것
# ═══════════════════════════════════════════════════════════
s = prs.slides.add_slide(BLANK)
slide_header(s, '2', '개발 목표 및 개발 결과', '2-2. 과제 범위 밖에서 스스로 발견하고 해결한 것')

conclusion_box(s, 0.5, 1.25, 12.3,
               '"동작한다"에서 멈추지 않고, 측정 → 원인 규명 → 도구 제작 → 재검증의 순서로 진행')

rows = [
    ['발견한 문제', '왜 문제인가', '만든 것 / 결과'],
    ['성능이 느린데 어디가 느린지 모름',
     '"느리다"는 인상만으로는 고칠 수 없음',
     'trace_util.py — Chrome Trace 형식 타임라인 직접 구현'],
    ['한 프레임 60.5 ms 중 추론 밖이 70%',
     '모델만 줄여서는 빨라지지 않음',
     '파이프라인 4단계 최적화 → 60.54 ms → 23.19 ms'],
    ['mAP 0.995인데 어두운 옷 앞에서 실패',
     '검증 점수가 실사용 성능을 대변하지 못함',
     '학습 데이터 104장 픽셀 직접 측정 → 원인 규명'],
    ['교수님 데이터가 xml이라 재학습 불가',
     'YOLO는 txt만 읽음. 형식 오류는 조용히 실패함',
     'make_dataset.py — 변환·병합·전수 검사 자동화'],
    ['라벨링 실수가 조용히 학습을 망침',
     '클래스 번호가 밀려도 오류가 나지 않음',
     'check_labels.py — 폴더명과 라벨을 기계 대조'],
    ['혼자서 데이터 촬영이 불가능',
     '키를 60번 누르며 손을 내밀 수 없음',
     'EX_01_Auto_Capture.py — 자동 촬영 + 중복 제거'],
]
table(s, 0.5, 2.1, 12.3, rows, col_w=[3.3, 4.0, 5.0], size=11, row_h=0.52)

note(s, 0.5, 6.3, 12.3,
     '※ 직접 작성한 파일 10종을 제출물에 포함. 모두 교수님 원본 예제를 수정하지 않고 사본으로 작업.')

# ═══════════════════════════════════════════════════════════
# 3-1. 핵심 기술 : 검출 파이프라인
# ═══════════════════════════════════════════════════════════
s = prs.slides.add_slide(BLANK)
slide_header(s, '3', '핵심 기술', '3-1. 분류(Classification)에서 검출(Detection)로 — 게임이 성립한 이유')

conclusion_box(s, 0.5, 1.25, 12.3,
               '검출 모델은 "무엇인가"와 "어디인가"를 함께 출력한다. 두 손을 동시에 다룰 수 있게 된 결정적 차이')

rows = [
    ['', '이전 실습 (MobileNetV2 분류)', '본 프로젝트 (YOLO11n 검출)'],
    ['모델 입력', 'MediaPipe가 손만 잘라낸 조각', '사진 전체 (320×320)'],
    ['출력', '클래스 1개 (화면 전체에 하나의 답)', '박스 2,100개 후보 → 필터 → 최종 박스들'],
    ['손 2개 처리', '불가능', '가능 — 게임이 성립하는 이유'],
    ['손 위치', '알 수 없음', 'x 좌표로 P1/P2 구분 가능'],
    ['후처리', '없음 (argmax 한 줄)', '약 40줄 (신뢰도 필터 → NMS → 좌표 복원)'],
]
table(s, 0.5, 2.1, 12.3, rows, col_w=[2.0, 5.0, 5.3], size=11.5,
      highlight_rows=(3,), row_h=0.42)

tf = textbox(s, 0.5, 4.9, 12.3, 2.2)
para(tf, '■ 후처리 3단계 (직접 구현)', 14, True, NAVY, first=True)
para(tf, '① 신뢰도 필터 : 2,100개 후보 중 conf ≥ 0.4 만 남긴다', 12.5, space_before=6)
para(tf, '② NMS : 같은 손에 겹쳐 잡힌 박스를 하나로 정리 (cv2.dnn.NMSBoxesBatched, IoU 0.45)', 12.5)
para(tf, '③ 좌표 복원 : letterbox(비율 유지 + 회색 114 여백)로 줄인 좌표를 원본 해상도로 되돌린다', 12.5)
para(tf, '측정 결과 후처리 전체가 한 프레임당 0.36 ms — 코드 길이가 실행 시간을 뜻하지 않음을 확인',
     12, True, GREEN, space_before=8)

# ═══════════════════════════════════════════════════════════
# 3-2. 핵심 기술 : 경량화 + 파이프라인
# ═══════════════════════════════════════════════════════════
s = prs.slides.add_slide(BLANK)
slide_header(s, '3', '핵심 기술', '3-2. 모델 경량화(PTQ)와 파이프라인 최적화')

conclusion_box(s, 0.5, 1.25, 6.0, '모델 3.5배 축소, 정확도 손실 없음', size=14)
conclusion_box(s, 6.8, 1.25, 6.0, '파이프라인 60.54 ms → 23.19 ms (2.6배)', size=14)

tf = textbox(s, 0.5, 2.0, 6.0, 0.4)
para(tf, '■ PTQ 양자화 결과', 14, True, NAVY, first=True)
rows = [
    ['모델', '크기', '방식'],
    ['best.tflite', '10.1 MB', 'float32 (기준)'],
    ['best_int8.tflite', '2.9 MB', 'PTQ INT8 (보정 데이터 필요)'],
    ['best_w8a32.tflite', '2.8 MB', 'Dynamic Range (보정 불필요)'],
]
table(s, 0.5, 2.45, 6.0, rows, col_w=[2.2, 1.3, 2.5], size=11, row_h=0.38)
note(s, 0.5, 4.1, 6.0,
     '세 모델 모두 입출력은 float32로 유지된다. 그래서 보드 코드에서 scale/zero 환산 없이\n'
     '모델 파일 이름만 바꿔 교체할 수 있다.')

tf = textbox(s, 6.8, 2.0, 6.0, 0.4)
para(tf, '■ 파이프라인 4단계 최적화 (측정 기반)', 14, True, NAVY, first=True)
rows = [
    ['단계', '조치', '한 프레임'],
    ['기준', '원본 코드', '60.54 ms'],
    ['1', 'waitKey(10) → waitKey(1)', '48.3 ms'],
    ['2', '카메라 읽기를 별도 스레드로', '34.9 ms'],
    ['3', '검출 주기 2프레임마다', '27.1 ms'],
    ['4', '인터프리터 스레드 4개', '23.19 ms'],
]
table(s, 6.8, 2.45, 6.0, rows, col_w=[0.9, 3.4, 1.7], size=11,
      highlight_rows=(5,), row_h=0.38)

tf = textbox(s, 0.5, 4.75, 12.3, 2.4)
para(tf, '■ 측정이 뒤집은 예측 — 추측으로는 알 수 없었던 것', 14, True, NAVY, first=True)
para(tf, '· cv2.imshow가 느릴 것으로 예상 → 실측 0.10 ms. 실제로는 waitKey가 11.98 ms였다. '
         'imshow는 비동기라 화면 전송이 waitKey 안에서 일어나기 때문.', 12.5, space_before=6)
para(tf, '· 후처리 40줄이 무거울 것으로 예상 → 실측 0.36 ms. 추론이 전체의 84%를 차지.', 12.5)
para(tf, '· 카메라 형식을 MJPG로 바꾸자 초당 처리 장수의 상한이 18.5장에서 해소되었다 (실측 68.1 FPS).',
     12.5)
para(tf, '→ 성능 개선은 추측이 아니라 측정에서 시작해야 한다는 것을 수치로 확인했다.',
     12.5, True, GREEN, space_before=6)

# ═══════════════════════════════════════════════════════════
# 3-3. 핵심 기술 : 데이터셋 구축·검증
# ═══════════════════════════════════════════════════════════
s = prs.slides.add_slide(BLANK)
slide_header(s, '3', '핵심 기술', '3-3. 데이터셋 구축 자동화와 전수 검증')

conclusion_box(s, 0.5, 1.25, 12.3,
               '라벨 오류는 오류 메시지 없이 학습을 망친다. 그래서 "사람이 확인"이 아니라 "기계가 대조"하도록 만들었다')

tf = textbox(s, 0.5, 2.0, 6.0, 3.0)
para(tf, '■ 문제 : 같은 이름의 데이터셋 zip이 두 개', 14, True, NAVY, first=True)
para(tf, '· A : 라벨이 txt — YOLO 정식 구조, 학습 가능', 12.5, space_before=6)
para(tf, '· B : 라벨이 xml — LabelImg 원본, 학습 불가', 12.5)
para(tf, 'LabelImg의 기본 저장 형식이 xml이므로, 새로 라벨링하면 학습이 안 되는 쪽이 만들어진다. '
         '게다가 Ultralytics는 라벨을 0개로 인식해도 오류 없이 학습을 진행한다.',
     12, space_before=4)
para(tf, '■ 해결 : make_dataset.py', 14, True, NAVY, space_before=12)
para(tf, 'xml→txt 변환 · 팀원 라벨 병합 · train/test 분할 · data.yaml 생성 · '
         '전수 검사 · zip 묶기를 한 번에 수행', 12.5, space_before=4)

tf = textbox(s, 6.8, 2.0, 6.0, 3.0)
para(tf, '■ 변환기 검증 (직접 대조)', 14, True, NAVY, first=True)
rows = [
    ['대조 항목', '결과'],
    ['대조한 박스 수', '132개'],
    ['클래스 번호 불일치', '0개'],
    ['좌표 최대 차이', '0.00064 픽셀'],
]
table(s, 6.8, 2.45, 6.0, rows, col_w=[3.6, 2.4], size=11.5,
      highlight_rows=(3,), row_h=0.38)
note(s, 6.8, 4.05, 6.0,
     '내 변환기 출력과 교수님이 제공한 정답 txt를 1:1 대조.\n'
     '차이는 전부 소수점 6자리 반올림 방식 차이였다.')

para(textbox(s, 6.8, 4.75, 6.0, 1.6),
     '■ check_labels.py — 라벨 전수 검사', 14, True, NAVY, first=True)

tf = textbox(s, 0.5, 5.35, 12.3, 1.8)
para(tf, '검사 원리 : 나눠 받은 사진의 폴더 이름이 곧 정답이다 (예: paper_rock 폴더 → 보 1개 + 바위 1개). '
         '따라서 txt에 적힌 클래스 번호가 폴더 이름과 맞는지 기계가 대조할 수 있다.',
     12.5, first=True)
para(tf, '잡아낸 실제 오류 : 클래스명 오타로 생긴 4번째 클래스, 파일명이 깨진 라벨 4건, '
         '보 대신 가위로 잘못 친 라벨 2건, 사진이 없는 라벨',
     12.5, space_before=6)
para(tf, '→ 팀원 3명의 라벨 306개를 전수 대조하여 병합 전에 검증 (불일치 0건 확인 후 병합)',
     12.5, True, GREEN, space_before=6)

# ═══════════════════════════════════════════════════════════
# 4-1. 결과 분석 : 핵심 표
# ═══════════════════════════════════════════════════════════
s = prs.slides.add_slide(BLANK)
slide_header(s, '4', '결과 분석 및 기대 효과', '4-1. 시험지를 두 개로 나누어 실제 성능을 드러냄')

conclusion_box(s, 0.5, 1.22, 12.3,
               '교수님 시험지에서는 세 모델이 모두 mAP50 0.995로 동일. 새 시험지에서만 0.475 → 0.851 (+79%)의 차이가 드러남',
               size=15)

rows = [
    ['모델', '학습 장수', '쉬운 시험 mAP50', '쉬운 시험 mAP50-95',
     '어려운 시험 mAP50', '어려운 시험 mAP50-95'],
    ['v1', '82장 (교수님 원본)', '0.995', '0.862', '0.475', '0.184'],
    ['v2', '327장 (+팀 245장)', '0.995', '0.849', '0.650', '0.383'],
    ['v3', '724장 (+497장)', '0.995', '0.827', '0.851', '0.472'],
    ['v1 → v3', '8.8배', '± 0', '−0.035', '+0.376 (+79%)', '+0.288 (2.6배)'],
]
table(s, 0.5, 2.05, 12.3, rows, col_w=[1.1, 2.4, 2.1, 2.2, 2.2, 2.3], size=11.5,
      highlight_rows=(3, 4), row_h=0.42)

note(s, 0.5, 4.3, 12.3,
     '· 쉬운 시험 = 교수님 원본 test 22장(박스 32개). 세 판 모두 학습에 한 장도 넣지 않고 그대로 보존해 비교 가능하게 했다.\n'
     '· 어려운 시험 = 직접 구성한 160장(박스 218개). 전부 손이 2개이고 출처·조명이 다양하다.')

tf = textbox(s, 0.5, 5.0, 12.3, 2.1)
para(tf, '■ 이 표에서 읽어야 할 것', 14, True, NAVY, first=True)
para(tf, '결론 : 교수님 데이터만으로 학습한 v1은 실사용 조건에서 절반도 맞히지 못하고 있었으나(0.475), '
         '교수님 시험지로는 0.995였기 때문에 그 사실을 알 수 없었다.', 12.5, space_before=6)
para(tf, '고찰 ① : mAP50(+79%)에 비해 mAP50-95(+0.288)의 상대 개선폭이 작다. '
         '손을 찾아내는 능력은 크게 늘었으나 박스 위치의 정밀도는 덜 늘었다는 뜻이다. '
         '게임은 좌/우 구분과 클래스만 맞으면 판정되므로 실사용에는 영향이 없다.', 12, space_before=6)
para(tf, '고찰 ② : 쉬운 시험의 mAP50-95가 0.862 → 0.827로 낮아졌으나, 학습 중 epoch 간 변동폭이 0.08에 달해 '
         '이 차이는 통계적 잡음과 구분되지 않는다. 표본이 32박스뿐이기 때문이며, '
         '218박스로 측정한 어려운 시험의 +0.288이 신뢰할 수 있는 값이다.', 12)

# ═══════════════════════════════════════════════════════════
# 4-2. 원인 분석 : 바위
# ═══════════════════════════════════════════════════════════
s = prs.slides.add_slide(BLANK)
slide_header(s, '4', '결과 분석 및 기대 효과',
             '4-2. 성능이 낮았던 원인 분석 — "바위를 못 잡는다"의 진짜 이유')

conclusion_box(s, 0.5, 1.22, 12.3,
               '부족했던 것은 데이터의 "개수"가 아니라 "크기의 다양성"이었다', size=15)

tf = textbox(s, 0.5, 1.98, 6.1, 0.4)
para(tf, '① 현상 — 보드 실측 (9가지 조합 각 1회)', 13.5, True, NAVY, first=True)
rows = [
    ['모델', 'P1 승', '무승부', 'P2 승', '판정 정확도'],
    ['정답', '3', '3', '3', '—'],
    ['v1', '2', '6', '1', '3 / 9'],
    ['v3', '3', '3', '3', '9 / 9'],
]
table(s, 0.5, 2.4, 6.1, rows, col_w=[1.3, 1.1, 1.2, 1.1, 1.4], size=11,
      highlight_rows=(3,), row_h=0.36)
note(s, 0.5, 3.9, 6.1,
     'v1은 바위를 다른 모양으로 잘못 읽어 "거짓 무승부"가 6회 발생했다.')

tf = textbox(s, 6.75, 1.98, 6.1, 0.4)
para(tf, '② 원인 — 학습 데이터의 바위 박스 크기', 13.5, True, NAVY, first=True)
rows = [
    ['학습 데이터', '바위 개수', '면적 평균', '면적 최대'],
    ['v1 (82장)', '33개', '9.9%', '15.5%'],
    ['v3 (724장)', '294개', '12.1%', '40.4%'],
]
table(s, 6.75, 2.4, 6.1, rows, col_w=[1.8, 1.4, 1.4, 1.5], size=11,
      highlight_rows=(2,), row_h=0.36)
note(s, 6.75, 3.65, 6.1,
     'v1의 학습 데이터에는 화면의 15.5%를 넘는 바위가 한 장도 없었다.\n'
     '게임에서 손을 카메라 가까이 내밀면 20~40%가 되므로, v1에게는 처음 보는 크기였다.\n'
     '클래스별 개수는 34/33/33으로 균형이 맞았다 — 개수의 문제가 아니었다.')

tf = textbox(s, 0.5, 4.55, 12.3, 1.3)
para(tf, '③ 검증 — 평가 지표가 같은 이야기를 한다', 13.5, True, NAVY, first=True)
rows = [
    ['모델', '바위 Precision', '바위 Recall', '바위 mAP50', '해석'],
    ['v1', '0.918', '0.352', '0.514', '"바위다"라고 말할 땐 거의 맞지만, 바위를 보고도 지나치는 일이 많다'],
    ['v3', '0.930', '0.775', '0.908', '놓치는 비율이 절반 이하로 감소'],
]
table(s, 0.5, 5.0, 12.3, rows, col_w=[1.0, 1.7, 1.6, 1.6, 6.4], size=11,
      highlight_rows=(2,), row_h=0.42)

note(s, 0.5, 6.35, 12.3,
     '④ 적용 결과 : 바위 Recall 0.352 → 0.775 (2.2배), 보드 판정 정확도 3/9 → 9/9. '
     '세 모양 중 주먹이 면적이 가장 작아(평균 9.9%, 가위 14.2%·보 18.5%) 검출이 가장 어려웠고, '
     '학습 데이터의 크기 범위마저 가장 좁았던 것이 원인이었다.')

# ═══════════════════════════════════════════════════════════
# 4-3. 보드 실측 + 기대 효과
# ═══════════════════════════════════════════════════════════
s = prs.slides.add_slide(BLANK)
slide_header(s, '4', '결과 분석 및 기대 효과', '4-3. 보드 실측 화면과 기대 효과')

picture(s, IMG_V1TERM, 0.5, 1.35, w=6.0)
caption(s, 0.5, 2.15, 6.0, '▲ 그림 2. v1 (82장 학습) — P1 2 / 무승부 6 / P2 1 → 3판만 정답')
picture(s, IMG_V3TERM, 6.8, 1.35, w=6.0)
caption(s, 6.8, 2.15, 6.0, '▲ 그림 3. v3 (724장 학습) — P1 3 / 무승부 3 / P2 3 → 9판 전부 정답')

tf = textbox(s, 0.5, 2.6, 12.3, 1.0)
para(tf, '■ 목표 달성 여부', 14, True, NAVY, first=True)
rows = [
    ['항목', '목표', '결과', '달성'],
    ['5단계 과제 구현', '전부', '전부 구현', 'O'],
    ['보드 단독 실시간 동작', '10 FPS 이상', '68.1 FPS (INT8 · MJPG)', 'O'],
    ['승패 판정 정확도', '9가지 조합 전부', '9 / 9', 'O'],
    ['실사용 인식 성능', '—', 'mAP50 0.851 (v1 0.475)', 'O'],
]
table(s, 0.5, 3.05, 12.3, rows, col_w=[3.0, 2.6, 4.7, 1.0], size=11.5, row_h=0.38)

tf = textbox(s, 0.5, 5.15, 12.3, 2.0)
para(tf, '■ 기대 효과', 14, True, NAVY, first=True)
para(tf, '· 정해진 손 모양을 판별하는 장치 — 무인 키오스크 제스처 입력, 재활 훈련 동작 확인, '
         '비접촉 조작 패널 등에 그대로 이전할 수 있다.', 12.5, space_before=6)
para(tf, '· 값싼 보드 한 대에서 검출·판정·표시가 모두 끝나므로 네트워크가 필요 없다. '
         '카메라 영상이 기기 밖으로 나가지 않아 개인정보 측면에서도 유리하다.', 12.5)
para(tf, '· 본 프로젝트의 데이터셋 구축·검증 도구(make_dataset.py, check_labels.py)는 '
         '클래스만 바꾸면 다른 검출 과제에 그대로 재사용할 수 있다.', 12.5)

# ═══════════════════════════════════════════════════════════
# 5. 향후 연구 과제
# ═══════════════════════════════════════════════════════════
s = prs.slides.add_slide(BLANK)
slide_header(s, '5', '향후 연구 과제')

conclusion_box(s, 0.5, 1.25, 12.3,
               '남은 문제는 모두 원인까지 규명되어 있으며, 해결 방향이 수치로 특정되어 있다')

rows = [
    ['과제', '현재 상태 (수치)', '원인', '해결 방향'],
    ['얼굴을 손으로 오검출',
     '학습 데이터의 background 사진 2장 / 724장 (0.3%)',
     'YOLO는 박스 밖을 "없음"으로 학습하는데, 여백에 얼굴이 한 번도 없었다',
     '손이 없는 사진을 라벨 없이 전체의 10%(약 70장) 추가'],
    ['박스 위치 정밀도',
     'mAP50-95 0.472 (mAP50 0.851 대비 낮음)',
     '라벨링하는 사람마다 박스 기준이 미세하게 다름',
     '라벨링 기준 문서화 후 재라벨링, 또는 더 큰 모델(YOLO11s)'],
    ['어두운 배경 대응',
     '학습 데이터 배경 밝기 V 131~176, V<120인 사진 0장',
     '촬영 장소가 한 곳(밝은 무채색 벽)뿐이었다',
     '배경 × 클래스를 격자로 채워 촬영 (bg_check.py로 조건 수치화)'],
    ['팀 라벨 43장 미완',
     'rock_scissor 33장 등 미라벨 상태로 제외됨',
     '팀원 작업 진행 중',
     '수령 즉시 make_dataset.py 재실행 (자동 병합·검증)'],
]
table(s, 0.5, 2.1, 12.3, rows, col_w=[2.2, 3.0, 3.6, 3.5], size=10.5, row_h=0.78)

note(s, 0.5, 5.6, 12.3,
     '※ "얼굴 오검출"은 임시 방편(신뢰도 상위 2개만 사용, USE_TOP2 옵션)을 구현해 두었으나, '
     '이를 켜면 3단계 예외 처리가 화면에 나타나지 않으므로 과제 시연에는 사용하지 않았다. '
     '근본 해결은 데이터 추가이며, 그 방법과 필요 수량까지 확인해 두었다.')

# ═══════════════════════════════════════════════════════════
# 6. 후기
# ═══════════════════════════════════════════════════════════
s = prs.slides.add_slide(BLANK)
slide_header(s, '6', '프로젝트 수행 후기')

conclusion_box(s, 0.5, 1.25, 12.3, '이번 프로젝트에서 가장 크게 배운 것은 "측정하지 않으면 모른다"는 것이다')

tf = textbox(s, 0.5, 2.1, 12.3, 4.8)
para(tf, '■ 추측이 틀렸던 순간들', 15, True, NAVY, first=True)
para(tf, '후처리 코드가 40줄이라 무거울 것이라 예상했으나 실측 0.36 ms였다. 반대로 한 줄짜리 '
         'cv2.imshow가 느릴 것이라 생각했는데 0.10 ms였고, 실제로는 waitKey가 11.98 ms를 쓰고 있었다. '
         'imshow가 비동기라 화면 전송이 waitKey 안에서 일어나기 때문이었다. '
         '코드의 길이와 실행 시간은 아무 관계가 없다는 것을 숫자로 배웠다.', 12.5, space_before=6)

para(tf, '■ 높은 점수를 의심하게 된 일', 15, True, NAVY, space_before=14)
para(tf, 'mAP 0.995를 보고 완성되었다고 생각했으나, 어두운 옷 앞에서는 인식이 되지 않았다. '
         '학습 데이터 104장의 픽셀을 직접 재 보고서야 배경 밝기가 V 131~176 한 구간에만 몰려 있고 '
         '어두운 배경이 단 한 장도 없다는 것을 알았다. 시험지와 문제집이 같은 책이었던 것이다. '
         '이후 시험지를 두 개로 나누어 관리했고, 그 덕분에 v1이 실사용 조건에서 0.475에 불과하다는 '
         '사실을 발견할 수 있었다. 높은 점수일수록 그 점수가 무엇을 재고 있는지 물어야 한다.',
     12.5, space_before=6)

para(tf, '■ 어려웠던 점과 극복', 15, True, NAVY, space_before=14)
para(tf, '가장 곤란했던 것은 오류 없이 조용히 실패하는 문제들이었다. 라벨 형식이 xml이면 학습이 '
         '헛돌고, 클래스 번호가 밀리면 가위를 바위로 배우는데 경고 한 줄 나오지 않는다. '
         '사람이 눈으로 확인하는 방식으로는 막을 수 없다고 판단해, 폴더 이름과 라벨을 기계가 '
         '대조하는 검사기를 만들었다. 실제로 오타 클래스와 파일명 손상 4건, 잘못 친 라벨 2건을 '
         '병합 전에 잡아냈다.', 12.5, space_before=6)

para(tf, '■ 마무리하며', 15, True, NAVY, space_before=14)
para(tf, '대학원 산학 프로젝트에서 NPU SDK가 만들어 주던 성능 타임라인을 이번에는 직접 구현해 보면서, '
         '그때 보던 그림이 무엇이었는지 비로소 이해하게 되었다. 모델을 바꾸는 것보다 데이터를 바꾸는 쪽이 '
         '효과가 컸다는 점, 그리고 그것을 확인하려면 비교 가능한 실험 설계가 먼저라는 점을 남은 과정에서도 '
         '이어 가고자 한다.', 12.5, space_before=6)

prs.save(OUT)
print('생성 완료 :', os.path.abspath(OUT))
print('슬라이드 %d장' % len(prs.slides.__iter__.__self__._sldIdLst))
