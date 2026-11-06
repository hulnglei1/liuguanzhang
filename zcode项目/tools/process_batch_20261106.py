"""批量处理 2026-11-06 批次的原始出图：
  抠图 → 按关羽的包围盒对齐 → 落到 assets/（同款兵种自动复制成多个 id）。
"""
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(r"D:\huanglei\deepseek\game")
PROJ = ROOT / "zcode项目"
BATCH = ROOT / "美术资产处理中心" / "3_原始出图_raw" / "batch_20261106"
PY = sys.executable

UNITS = [
    ("华雄", ["huaxiong"]),
    ("吕布", ["lubu"]),
    ("许褚", ["xuchu"]),
    ("臧霸", ["zangba"]),
    ("昌豨", ["changxi"]),
    ("武安国", ["wuanguo"]),
    ("公孙瓒", ["gongsunzan"]),
    ("乡勇义军", ["yi_bing_1", "yi_bing_2"]),
    ("董卓军刀兵", ["dao_bing_1", "dao_bing_2"]),
    ("董卓军弓兵", ["gong_bing_1", "gong_bing_2"]),
    ("董卓军骑兵", ["li_bu_fu_1", "li_bu_fu_2"]),
    ("黄巾乱兵", ["luan_bing_1", "luan_bing_2", "luan_bing_3"]),
    ("泰山贼兵", ["taishan_1", "taishan_2", "taishan_3"]),
    ("西凉铁骑", ["xiliang_cavalry_1", "xiliang_cavalry_2"]),
    ("西凉伏兵弓手", ["xiliang_archer_1", "xiliang_archer_2"]),
    ("曹操", ["caocao"]),
    ("典韦", ["dianwei"]),
    ("徐荣", ["xurong"]),
]

PORTRAITS = [
    ("华雄", "huaxiong"),
    ("吕布", "lubu"),
    ("许褚", "xuchu"),
    ("臧霸", "zangba"),
    ("昌豨", "changxi"),
    ("武安国", "wuanguo"),
    ("公孙瓒", "gongsunzan"),
]


def newest(keyword: str, prefix: str) -> Path | None:
    cands = [p for p in BATCH.glob("*.png") if p.name.startswith(prefix) and keyword in p.name]
    return max(cands, key=lambda p: p.stat().st_mtime) if cands else None


def run(src: Path, ref: Path, out: Path, extra: list):
    cmd = [PY, str(PROJ / "tools" / "normalize_to_reference.py"),
           "--src", str(src), "--ref", str(ref), "--out", str(out)] + extra
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    ok = r.returncode == 0 and out.exists()
    print(("  [OK] " if ok else "  [FAIL] ") + out.name)
    if not ok:
        print("     " + (r.stderr or r.stdout)[-300:])


print("=== 战场单位 ===")
for kw, ids in UNITS:
    src = newest(kw, "Q版")
    if src is None:
        print("  [MISS] " + kw)
        continue
    first = PROJ / "assets" / "units" / (ids[0] + ".png")
    run(src, PROJ / "assets/units/guanyu.png", first,
        ["--crop-bottom", "70", "--crop-right", "70", "--policy", "height"])
    for other in ids[1:]:
        shutil.copyfile(first, PROJ / "assets" / "units" / (other + ".png"))
    if len(ids) > 1:
        print("     复制为: " + ", ".join(ids[1:]))

print("\n=== 武将立绘 ===")
for kw, uid in PORTRAITS:
    src = newest(kw, "中国风水墨")
    if src is None:
        print("  [MISS] " + kw)
        continue
    run(src, PROJ / "assets/portraits/guanyu_normal.png",
        PROJ / "assets" / "portraits" / (uid + "_normal.png"),
        ["--crop-bottom", "250", "--crop-right", "80", "--policy", "height"])

print("\n完成")
