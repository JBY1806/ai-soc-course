# -*- coding: utf-8 -*-
"""
내가 찍은 사진을 강사님 데이터셋에 합쳐서 학습용 데이터셋을 만든다.  (PC에서 실행)

■ 왜 이 파일이 필요한가 — 같은 이름의 zip이 두 개인데 속이 다르다

    Lec_python/2/On-DeviceAI…/01.examples(COLAB)/files/RPS_Dataset_YOLO.zip
        → 라벨이 txt 104개. images/ 와 labels/ 가 나란히 있는 YOLO 정식 구조.
          EX_02 노트북이 쓰는 것이 이것이고, 그래서 바로 학습이 됐다.

    Lec_python/2/Deep_Learning(축약)…/02.DL(CNN)_Files/RPS_Dataset_YOLO.zip
        → 라벨이 xml 104개. jpg 옆에 xml이 같이 들어 있다.
          LabelImg가 뱉은 Pascal VOC 원본이다. YOLO는 이 형식을 못 읽는다.

    강사님이 "xml이라 조심하라"고 하신 것이 이 이야기다.
    LabelImg로 새로 라벨링하면 기본이 xml(PascalVOC)이므로 **반드시 txt로 바꿔야** 한다.

■ 변환 공식 (강사님 데이터로 검증 완료: 박스 132개 대조, 좌표 최대 차이 0.00064픽셀)

    xml :  scissors  xmin 236  ymin 138  xmax 415  ymax 409   (size 640x480, 픽셀 단위)
    txt :  0 0.508594 0.569792 0.279688 0.564583              (0~1로 정규화)

        클래스번호  cx=(xmin+xmax)/2/W   cy=(ymin+ymax)/2/H   w=(xmax-xmin)/W   h=(ymax-ymin)/H
        클래스번호 : scissors=0, rock=1, paper=2   ← data.yaml 의 순서 그대로

■ 시험지를 두 개로 나눈다 (중요)

    강사님 test 22장은 **손대지 않고 그대로 val로 쓴다.**
      → 재학습 전후의 mAP를 같은 시험지로 비교할 수 있다. 숫자가 비교 가능해진다.
    새로 찍은 어려운 사진 일부는 **test_hard** 라는 별도 시험지로 뺀다.
      → "실사용 조건에서는 몇 점인가"를 따로 잰다.

    그래서 결과를 이렇게 두 줄로 쓸 수 있다.
        쉬운 시험(강사님 22장)  : 0.995 → 0.99x   (떨어지지 않았다)
        어려운 시험(내가 찍은)  :   —   → 0.8xx   (새로 생긴 능력)
    한 줄짜리 0.995보다 훨씬 설명하기 좋다.

■ 쓰는 법
    1) 보드에서 EX_01_Auto_Capture.py 로 사진을 찍는다
    2) 사진을 PC로 가져와 LabelImg 로 라벨링한다 (형식은 PascalVOC = xml)
       - 손이 없는 배경 사진은 라벨을 만들지 않는다. 그것이 background 역할이다.
    3) 이 파일의 NEW_DIR 을 그 폴더로 맞추고 실행한다
           python make_dataset.py
    4) 만들어진 RPS_Dataset_YOLO_v2.zip 을 구글 드라이브 files/ 에 올리고,
       EX_02 노트북의 dataset_zip 이름만 바꿔서 학습한다
    5) 학습이 끝나면 어려운 시험지로도 한 번 잰다
           !yolo val model={BEST} data={DATA} split=test
"""
import os
import glob
import hashlib
import random
import shutil
import zipfile
import xml.etree.ElementTree as ET

# ─────────────────────────────────────────────────────────────
#  설정
# ─────────────────────────────────────────────────────────────
HERE = os.path.dirname(os.path.abspath(__file__))

# 강사님의 '학습 가능한' txt판 zip (이쪽을 바탕으로 삼는다)
ORIG_ZIP = os.path.join(
    HERE, '..', 'On-DeviceAI라즈베리파이5_Lab_[64-302-01]',
    '01.examples(COLAB)', 'files', 'RPS_Dataset_YOLO.zip')

# 사진이 있는 곳과, 그 사진의 라벨이 있는 곳.
#   팀으로 나눠 라벨링하면 사진과 라벨이 **다른 폴더**에 있게 된다.
#   (사진은 다 같이 받은 것, 라벨은 각자 만들어 주고받은 것)
#   라벨이 사진 옆에 같이 있으면 라벨 폴더를 None 으로 둔다.
#
# 라벨은 .txt(YOLO) 든 .xml(PascalVOC) 든 다 받는다.
PHOTOS = os.path.join(HERE, '..', '..', 'data', 'data')
TEAM = os.path.join(HERE, '..', '..', '[프로젝트1] 가위바위보_yolov11n', 'Dataset')

# 만들 데이터셋 판 번호. 바꾸면 이전 판을 덮어쓰지 않는다.
#   v2 = 강사님 104 + 우리 팀이 나눠 라벨링한 306
#   v3 = v2 + RPS1(=mpa오류 폴더) 497
VERSION = 'v4'

NEW4 = os.path.join(HERE, '..', '..', 'RPS_Dataset_YOLO (4)', 'RPS_Dataset_YOLO')
MPA = os.path.join(HERE, '..', '..', '[프로젝트1] 가위바위보_yolov11n',
                   'RPS_dataset_YOLO (mpa오류)', 'RPS_dataset_YOLO')

SOURCES = [
    # (사진 폴더, 라벨 폴더 또는 None)
    (os.path.join(PHOTOS, 'paper_paper'),     None),   # 내가 한 것 (라벨이 사진 옆에)
    (os.path.join(PHOTOS, 'paper_rock'),      None),
    (os.path.join(PHOTOS, 'paper_scissor'),   None),
    (os.path.join(PHOTOS, 'scissor_scissor'), os.path.join(TEAM, 'rr_rs_ss_set', '가위_가위')),
    (os.path.join(PHOTOS, 'rock_scissor'),    os.path.join(TEAM, 'rr_rs_ss_set', '주먹_가위')),
    (os.path.join(PHOTOS, 'rock_rock'),       os.path.join(TEAM, 'rr_rs_ss_set', '주먹_주먹')),
    # 내가 보드로 직접 찍은 사진 (있으면)
    (os.path.join(HERE, 'captures'),          None),

    # 팀원이 준 손 1개짜리 (RPS1 과 같은 데이터. 사진과 라벨이 따로 폴더에 있다)
    #   세 번째 값은 파일 이름 앞에 붙일 꼬리표. 안 주면 사진 폴더 이름을 쓴다.
    (os.path.join(MPA, 'images', 'train'), os.path.join(MPA, 'labels', 'train'), 'rps1a'),
    (os.path.join(MPA, 'images', 'test'),  os.path.join(MPA, 'labels', 'test'),  'rps1b'),

    # 팀원이 다시 찍어 공유한 것 (2026-09-17 저녁). 사진 721장 중 434장이 새것이고
    # 287장은 이미 갖고 있는 것이라, 아래 해시 검사로 자동으로 걸러진다.
    (os.path.join(NEW4, 'images', 'train'), os.path.join(NEW4, 'labels', 'train'), 'v4a'),
    (os.path.join(NEW4, 'images', 'test'),  os.path.join(NEW4, 'labels', 'test'),  'v4b'),
]

# 폴더마다 img_0001.jpg 처럼 이름이 겹치므로, 넣을 때 폴더 이름을 앞에 붙인다.
#   data/data/paper_rock/img_0001.jpg  ->  paper_rock__img_0001.jpg

OUT_DIR = os.path.join(HERE, 'RPS_Dataset_YOLO_' + VERSION)
OUT_ZIP = OUT_DIR + '.zip'

HARD_RATIO = 0.2     # 새 사진 중 '어려운 시험지'로 뺄 비율. 나머지는 전부 학습용
SEED = 0             # 같은 결과가 나오게 고정

# data.yaml 과 반드시 같은 순서여야 한다
CLASSES = ['scissors', 'rock', 'paper']
NAME2ID = {n: i for i, n in enumerate(CLASSES)}

SPLITS = ('train', 'test', 'test_hard')


def file_hash(path):
    """파일 내용의 지문. 이름이 달라도 같은 사진이면 같은 값이 나온다."""
    return hashlib.md5(open(path, 'rb').read()).hexdigest()


# ─────────────────────────────────────────────────────────────
#  1. 강사님 데이터 풀기 (train / test 는 손대지 않는다)
# ─────────────────────────────────────────────────────────────
def load_original():
    if os.path.isdir(OUT_DIR):
        shutil.rmtree(OUT_DIR)
    for split in SPLITS:
        os.makedirs(os.path.join(OUT_DIR, 'images', split))
        os.makedirs(os.path.join(OUT_DIR, 'labels', split))

    z = zipfile.ZipFile(ORIG_ZIP)
    names = z.namelist()
    if not [n for n in names if n.endswith('.txt')]:
        raise SystemExit(
            'ORIG_ZIP 안에 txt 라벨이 없습니다. xml판 zip을 가리키고 있는 것 같습니다.\n'
            '  현재: %s' % ORIG_ZIP)

    n_img = n_lab = 0
    for n in names:
        if n.endswith('/'):
            continue
        parts = n.split('/')
        if len(parts) < 4:
            continue
        kind, split, fname = parts[1], parts[2], parts[3]
        if kind not in ('images', 'labels') or split not in ('train', 'test'):
            continue
        with open(os.path.join(OUT_DIR, kind, split, fname), 'wb') as f:
            f.write(z.read(n))
        if kind == 'images':
            n_img += 1
        else:
            n_lab += 1
    print('[원본] 사진 %d장, 라벨 %d개  (test 22장은 그대로 둔다 = 비교용 시험지)'
          % (n_img, n_lab))

    # 이미 들어간 사진의 해시. 뒤에서 같은 사진이 또 들어오는 것을 막는다.
    seen = set()
    for split in SPLITS:
        d = os.path.join(OUT_DIR, 'images', split)
        for f in os.listdir(d):
            seen.add(file_hash(os.path.join(d, f)))
    return seen


# ─────────────────────────────────────────────────────────────
#  2. xml → txt 변환
# ─────────────────────────────────────────────────────────────
def convert_one(xml_path):
    """Pascal VOC xml 한 개를 YOLO txt 줄들로 바꾼다. 문제가 있으면 예외를 낸다."""
    root = ET.parse(xml_path).getroot()
    size = root.find('size')
    W = float(size.find('width').text)
    H = float(size.find('height').text)
    if W <= 0 or H <= 0:
        raise ValueError('size가 이상하다 (%sx%s)' % (W, H))

    lines = []
    for o in root.findall('object'):
        name = o.find('name').text.strip()
        if name not in NAME2ID:
            raise ValueError(
                '모르는 클래스 이름 "%s". %s 중 하나여야 한다 '
                '(대소문자·철자 주의)' % (name, CLASSES))
        b = o.find('bndbox')
        x1 = float(b.find('xmin').text)
        y1 = float(b.find('ymin').text)
        x2 = float(b.find('xmax').text)
        y2 = float(b.find('ymax').text)
        if x2 <= x1 or y2 <= y1:
            raise ValueError('박스가 뒤집혔거나 넓이가 0이다')
        cx, cy = (x1 + x2) / 2 / W, (y1 + y2) / 2 / H
        w, h = (x2 - x1) / W, (y2 - y1) / H
        for v in (cx, cy, w, h):
            if not (0.0 <= v <= 1.0):
                raise ValueError('좌표가 0~1을 벗어난다 (%.4f). '
                                 'xml의 size와 실제 사진 크기가 다른 것 같다' % v)
        lines.append('%d %.6f %.6f %.6f %.6f' % (NAME2ID[name], cx, cy, w, h))
    return lines


def read_txt(path):
    """이미 YOLO 형식인 txt. 내용을 검사만 하고 그대로 쓴다."""
    lines = []
    for ln in open(path):
        parts = ln.split()
        if not parts:
            continue
        if len(parts) != 5:
            raise ValueError('한 줄에 숫자가 5개가 아니다: %s' % ln.strip())
        cid = int(parts[0])
        if not (0 <= cid < len(CLASSES)):
            raise ValueError('클래스 번호 %d (0~%d여야 한다). '
                             'classes.txt 순서가 어긋났을 수 있다'
                             % (cid, len(CLASSES) - 1))
        vals = [float(v) for v in parts[1:]]
        if any(not (0.0 <= v <= 1.0) for v in vals):
            raise ValueError('좌표가 0~1 밖이다: %s' % vals)
        if vals[2] <= 0 or vals[3] <= 0:
            raise ValueError('박스 크기가 0이다')
        lines.append('%d %.6f %.6f %.6f %.6f' % (cid, vals[0], vals[1],
                                                 vals[2], vals[3]))
    return lines


def collect_new(seen):
    """SOURCES 를 훑어 (사진경로, 라벨줄들, 저장할이름) 목록을 만든다.

    라벨 파일이 **아예 없는** 사진은 건너뛴다. 이것이 중요하다 —
    아직 라벨링을 안 한 사진과, 일부러 비워 둔 배경 사진은
    파일만 봐서는 구별이 안 되기 때문이다.

        내용이 있는 txt/xml -> 손이 있다. 그대로 쓴다
        내용이 빈 txt       -> "확인했고 손이 없다" = 배경 사진. 쓴다
        파일이 아예 없음     -> 아직 안 한 것. **빼고 알려 준다**
    """
    items = []
    errors = []
    skipped = []
    n_dup_all = 0
    for src in SOURCES:
        img_dir, lab_dir = src[0], src[1]
        if not os.path.isdir(img_dir):
            continue
        if lab_dir is None:
            lab_dir = img_dir
        # 이름 겹침 방지용 접두어. 세 번째 값이 있으면 그것을, 없으면 폴더 이름을 쓴다
        tag = src[2] if len(src) > 2 else os.path.basename(img_dir.rstrip(os.sep))
        names = []
        for ext in ('*.jpg', '*.jpeg', '*.png'):
            names += glob.glob(os.path.join(glob.escape(img_dir), ext))
        if not names:
            continue
        names.sort()
        n_box = n_bg = n_none = n_dup = 0
        for img in names:
            # 이미 들어간 사진과 내용이 같으면 건너뛴다 (이름이 달라도 잡힌다)
            hh = file_hash(img)
            if hh in seen:
                n_dup += 1
                continue
            seen.add(hh)
            base = os.path.splitext(os.path.basename(img))[0]
            txt = os.path.join(lab_dir, base + '.txt')
            xml = os.path.join(lab_dir, base + '.xml')
            lines = None
            try:
                if os.path.exists(txt):
                    lines = read_txt(txt)          # 빈 파일이면 []
                elif os.path.exists(xml):
                    lines = convert_one(xml)
                else:
                    n_none += 1                    # 라벨 파일 자체가 없다
                    skipped.append('%s/%s' % (tag, base))
                    continue
            except Exception as e:
                errors.append('%s/%s : %s' % (tag, base, e))
                continue
            if lines:
                n_box += len(lines)
            else:
                n_bg += 1
            items.append((img, lines, '%s__%s' % (tag, base)))
        note = ''
        if n_dup:
            note += '   << 중복 %d장 제외' % n_dup
        if n_none:
            note += '   << 라벨 없어 %d장 제외' % n_none
        n_dup_all += n_dup
        print('  %-18s 사진 %3d장  박스 %3d개  배경 %d장%s'
              % (tag, len(names), n_box, n_bg, note))
    if n_dup_all:
        print('  (내용이 같은 사진 %d장을 자동으로 걸렀다)' % n_dup_all)
    return items, errors, skipped


SEEN = set()


def add_new():
    print('[새 사진] 폴더를 훑는다')
    items, errors, skipped = collect_new(SEEN)
    if not items:
        print('  넣을 사진이 없다. 원본만으로 만든다.')
        return

    random.Random(SEED).shuffle(items)
    n_hard = max(1, int(len(items) * HARD_RATIO))

    stat = {'박스있음': 0, '배경(라벨없음)': 0, '박스총개수': 0}
    for i, (img, lines, out_base) in enumerate(items):
        # 앞쪽 일부만 '어려운 시험지'로. 나머지는 전부 학습에 쓴다
        split = 'test_hard' if i < n_hard else 'train'
        shutil.copy2(img, os.path.join(OUT_DIR, 'images', split,
                                       out_base + '.jpg'))
        if lines:
            with open(os.path.join(OUT_DIR, 'labels', split,
                                   out_base + '.txt'), 'w') as f:
                f.write('\n'.join(lines) + '\n')
            stat['박스있음'] += 1
            stat['박스총개수'] += len(lines)
        else:
            # 배경 사진 : txt 파일을 만들지 않는다 (YOLO가 background로 본다)
            stat['배경(라벨없음)'] += 1

    print('  합계 %d장  (학습 %d장 / 어려운 시험지 %d장)'
          % (len(items), len(items) - n_hard, n_hard))
    for k, v in stat.items():
        print('   %-14s %d' % (k, v))
    if skipped:
        print()
        print('  ** 라벨이 없어서 뺀 사진 %d장.' % len(skipped))
        print('     아직 라벨링을 안 한 것이라면, 끝낸 뒤 다시 돌려야 한다.')
        print('     손이 없는 사진이라 뺀 것이라면 mark_background.py 로 표시해 두면')
        print('     배경 사진으로 쓸 수 있다(얼굴 오검출을 줄여 준다).')
        for k in skipped[:10]:
            print('     -', k)
        if len(skipped) > 10:
            print('     ... 외 %d장' % (len(skipped) - 10))
    if errors:
        print()
        print('  !! 아래는 건너뛰었다. 고치고 다시 돌려라:')
        for e in errors[:15]:
            print('     -', e)
        if len(errors) > 15:
            print('     ... 외 %d건' % (len(errors) - 15))


# ─────────────────────────────────────────────────────────────
#  3. data.yaml 쓰고 검사하고 zip으로 묶기
# ─────────────────────────────────────────────────────────────
def write_yaml():
    has_hard = bool(os.listdir(os.path.join(OUT_DIR, 'images', 'test_hard')))
    p = os.path.join(OUT_DIR, 'data.yaml')
    with open(p, 'w') as f:
        f.write('# data.yaml (자동 생성)\n')
        f.write('#   val  = 강사님 원본 시험지 22장. 재학습 전후 비교용이라 건드리지 않는다\n')
        f.write('#   test = 내가 찍은 어려운 사진. 실사용 조건 점수용\n')
        f.write('#          재는 법: yolo val model=best.pt data=data.yaml split=test\n\n')
        f.write('path: /content/%s\n' % os.path.basename(OUT_DIR))
        f.write('train: images/train\n')
        f.write('val: images/test\n')
        if has_hard:
            f.write('test: images/test_hard\n')
        f.write('\nnames:\n')
        for i, c in enumerate(CLASSES):
            f.write('  %d: %s\n' % (i, c))
    print('[yaml] %s' % p)


def verify():
    print()
    print('=' * 66)
    print(' 검사')
    print('-' * 66)
    ok = True
    n_img_all = n_bg_all = 0
    for split in SPLITS:
        idir = os.path.join(OUT_DIR, 'images', split)
        ldir = os.path.join(OUT_DIR, 'labels', split)
        imgs = {os.path.splitext(f)[0] for f in os.listdir(idir)}
        labs = {os.path.splitext(f)[0] for f in os.listdir(ldir)}
        if not imgs:
            continue

        orphan = labs - imgs          # 사진 없는 라벨 = 반드시 오류
        bg = imgs - labs              # 라벨 없는 사진 = background (정상)

        nbox = 0
        per_cls = {c: 0 for c in CLASSES}
        for f in os.listdir(ldir):
            for ln in open(os.path.join(ldir, f)):
                parts = ln.split()
                if not parts:
                    continue
                cid = int(parts[0])
                if not (0 <= cid < len(CLASSES)):
                    print('  [오류] %s : 클래스 번호 %d' % (f, cid))
                    ok = False
                    continue
                vals = [float(v) for v in parts[1:]]
                if len(vals) != 4 or any(not (0 <= v <= 1) for v in vals):
                    print('  [오류] %s : 좌표 이상 %s' % (f, vals))
                    ok = False
                per_cls[CLASSES[cid]] += 1
                nbox += 1

        label = {'train': '학습', 'test': '시험(강사님)',
                 'test_hard': '시험(어려움)'}[split]
        print('  %-14s 사진 %3d장 | 박스 %3d개 | background %d장'
              % (label, len(imgs), nbox, len(bg)))
        print('  %-14s 클래스별 : %s' % ('', per_cls))
        if orphan:
            print('  [오류] 사진이 없는 라벨 %d개: %s'
                  % (len(orphan), sorted(orphan)[:5]))
            ok = False
        n_img_all += len(imgs)
        n_bg_all += len(bg)

    print('-' * 66)
    if n_bg_all == 0:
        print('  [주의] background(라벨 없는) 사진이 0장이다.')
        print('         얼굴을 손으로 잡는 문제가 그대로 남는다.')
        print('         손이 없는 사진을 라벨 없이 %d장쯤 넣는 것을 권한다 (전체의 10%%).'
              % max(8, n_img_all // 10))
    else:
        rate = n_bg_all * 100.0 / n_img_all
        print('  background %d장 (전체 %d장의 %.0f%%). 권장은 10%% 안팎.'
              % (n_bg_all, n_img_all, rate))
        if rate > 40:
            # 라벨링을 아직 안 끝낸 사진은 '라벨 없는 사진'과 구별되지 않는다.
            # 그대로 학습하면 "손이 있는데 없다고" 가르치게 되어 모델이 망가진다.
            # 오류도 경고도 안 나는 사고라서 여기서 막는다.
            ok = False
            print()
            print('  [중단] background 비율이 %.0f%%다. 너무 높다.' % rate)
            print('         라벨 파일이 없는 사진은 YOLO가 "여기엔 아무것도 없다"로 배운다.')
            print('         라벨링을 아직 안 끝낸 사진이라면, 손이 있는데도 없다고')
            print('         가르치게 되어 모델이 망가진다. 오류가 안 나는 사고라 여기서 막는다.')
            print()
            print('         -> check_labels.py 로 진행 상황을 먼저 확인할 것.')
            print('         -> 정말로 손이 없는 배경 사진이 이만큼 맞다면')
            print('            verify() 의 30 이라는 숫자를 올려라.')
    print(' 결과 :', '이상 없음' if ok else '오류 있음 — 위 내용을 고칠 것')
    print('=' * 66)
    return ok


def make_zip():
    if os.path.exists(OUT_ZIP):
        os.remove(OUT_ZIP)
    with zipfile.ZipFile(OUT_ZIP, 'w', zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(OUT_DIR):
            for f in files:
                full = os.path.join(root, f)
                rel = os.path.relpath(full, os.path.dirname(OUT_DIR))
                z.write(full, rel.replace(os.sep, '/'))
    print()
    print('[zip] %s  (%.1f MB)' % (OUT_ZIP, os.path.getsize(OUT_ZIP) / 1e6))
    print()
    print('다음: 이 zip을 구글 드라이브 MyDrive/files/ 에 올리고,')
    print('      EX_02 노트북의 경로 셀에서 두 줄을 바꾼다')
    print("        dataset_zip  = '/content/drive/MyDrive/files/%s'"
          % os.path.basename(OUT_ZIP))
    print("        dataset_root = '/content/%s'" % os.path.basename(OUT_DIR))
    print()
    print('      학습이 끝나면 어려운 시험지로도 한 번 잰다')
    print('        !yolo val model={BEST} data={DATA} split=test')


if __name__ == '__main__':
    print('=' * 66)
    print(' 데이터셋 만들기')
    print('=' * 66)
    SEEN.update(load_original())
    add_new()
    write_yaml()
    if verify():
        make_zip()
    else:
        print('오류가 있어 zip은 만들지 않았다.')
