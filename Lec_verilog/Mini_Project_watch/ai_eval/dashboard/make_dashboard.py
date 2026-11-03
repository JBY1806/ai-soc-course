"""AI 평가 대시보드 생성기.

ai_eval/scores/*.json(설계·검증 세션 결과)과 ai_eval/rubric.md(기준 근거)를 읽어
ai_eval/dashboard/dashboard.html 한 파일을 만든다. 인터넷 없이 더블클릭으로 열린다.

실행:  py -3 make_dashboard.py      (세션 JSON 이 늘어날 때마다 다시 실행)
"""
import json
import re
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent                       # ai_eval
SCORES = ROOT / "scores"
RUBRIC = ROOT / "rubric.md"
OUT = HERE / "dashboard.html"

# 화면 위쪽 "담당 역할" 카드 — 정보윤이 직접 고친다
PROFILE = {
    "project": "Stopwatch · Watch 미니프로젝트 (팀 BEST_Stop_watch_project)",
    "board": "Basys-3 · xc7a35tcpg236-1 · 100 MHz · Vivado 2022.2 xsim",
    "name": "정보윤",
    "role": "시계 상태 머신 · 시계 데이터패스 설계",
    "role_desc": "watch_control_unit (설정 FSM 4상태, 자리 이동, ±1/±10) · "
                 "watch_datapath (12:00 시작, 100 Hz tick, tick 우선)",
    "sessions_required": 3,
}


def parse_rubric(path):
    """rubric.md 표에서 기준 id → {name, weight, basis, rule}."""
    out = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\|\s*([DV]\d)\s*\|(.+)\|\s*$", line)
        if not m:
            continue
        cells = [c.strip() for c in m.group(2).split("|")]
        if len(cells) < 4:
            continue
        out[m.group(1)] = {
            "name": cells[0],
            "weight": cells[1],
            "basis": cells[2],
            "rule": cells[3],
        }
    return out


def load_sessions(folder):
    design, verif = [], []
    for p in sorted(folder.glob("*.json")):
        try:
            d = json.loads(p.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError) as e:
            print(f"[건너뜀] {p.name}: {e}")
            continue
        d["_file"] = str(p)
        if d.get("type") == "design":
            design.append(d)
        elif d.get("type") == "verification":
            verif.append(d)
    design.sort(key=lambda s: s.get("session", 0))
    verif.sort(key=lambda s: s.get("session", 0))
    return design, verif


def main():
    try:
        import sys
        sys.stdout.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass
    design, verif = load_sessions(SCORES)
    data = {
        "profile": PROFILE,
        "rubric": parse_rubric(RUBRIC),
        "design": design,
        "verif": verif,
        "generated": datetime.now().strftime("%Y-%m-%d %H:%M"),
    }
    blob = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    html = (HERE / "template.html").read_text(encoding="utf-8")
    OUT.write_text(html.replace("/*__DATA__*/null", blob), encoding="utf-8")
    print(f"설계 세션 {len(design)}개 · 검증 세션 {len(verif)}개 → {OUT}")


if __name__ == "__main__":
    main()
