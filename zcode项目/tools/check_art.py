#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""美术资源合规校验（出图后跑一遍，对不上的地方会直接指出来）

用法：
    python tools/check_art.py              # 校验全部
    python tools/check_art.py portraits    # 只校验立绘

校验项：
    1. 文件名是否符合命名规范（决定代码能否加载到）
    2. 画布尺寸是否精确匹配（差 1px 都会导致换人时画面跳动）
    3. 人物脚底是否贴底（决定站位是否浮空/陷地）
    4. 人物是否水平居中（决定站位是否偏移）
    5. 人物高度占比是否在区间内（决定大小是否统一）
    6. 是否存在半透明灰边（抠图残留，会在深色背景上出现白边）
    7. 画布四周安全区是否留白（避免描边/发丝被裁掉）

退出码 0 = 全部合规；1 = 有 FAIL（必须修）；2 = 仅有 WARN（建议修）
"""
import re
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("需要 Pillow：pip install pillow")
    sys.exit(1)

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent  # zcode项目/

SPECS = {
    "portraits": {
        "dir": "assets/portraits",
        "size": (900, 1200),
        "pattern": r"^[a-z][a-z0-9_]*_(normal|angry|happy|sad|shock)\.png$",
        "anchor": "bottom",
        "height_ratio": (0.72, 0.95),
        "bottom_touch": 10,     # 脚底必须落在底部 N 像素内
        "safe_margin": 6,       # 四周至少留 N 像素空白
        "note": "立绘 900x1200，脚底贴底、水平居中",
    },
    "units": {
        "dir": "assets/units",
        "size": (192, 192),
        "pattern": r"^[a-z][a-z0-9_]*\.png$",
        "anchor": "bottom",
        "height_ratio": (0.78, 0.96),
        "bottom_touch": 8,
        "safe_margin": 4,
        "note": "战场单位 192x192，脚底贴底、水平居中",
    },
    "tiles": {
        "dir": "assets/tiles",
        "size": (104, 104),
        "pattern": r"^[a-z][a-z0-9_]*_\d{2}\.png$",
        "anchor": "fill",       # 地块要铺满，不适用贴底
        "height_ratio": None,
        "bottom_touch": 0,
        "safe_margin": 0,
        "note": "地块 104x104，四边可无缝拼接（不透明铺满）",
    },
}

OK, WARN, FAIL = "OK  ", "WARN", "FAIL"


def check_file(path: Path, spec: dict) -> tuple[str, list[str]]:
    msgs: list[str] = []
    level = OK

    if not re.match(spec["pattern"], path.name):
        return FAIL, [f"文件名不合规范（正则 {spec['pattern']}）"]

    img = Image.open(path)
    if img.format != "PNG":
        return FAIL, ["必须是 PNG"]
    if img.mode != "RGBA":
        img = img.convert("RGBA")

    if img.size != spec["size"]:
        level = FAIL
        msgs.append(f"尺寸 {img.size[0]}x{img.size[1]}，规范要求 {spec['size'][0]}x{spec['size'][1]}")

    alpha = img.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return FAIL, ["整张图全透明（空图）"]

    l, t, r, b = bbox
    cw, ch = img.size

    if spec["anchor"] == "bottom":
        gap_bottom = ch - b
        if gap_bottom > spec["bottom_touch"]:
            level = FAIL
            msgs.append(f"脚底离画布底边 {gap_bottom}px（应 ≤{spec['bottom_touch']}px），角色会浮空")
        elif gap_bottom > 0:
            msgs.append(f"脚底离底边 {gap_bottom}px（可接受，越小越稳）")

        # 水平居中
        center_off = abs((l + r) / 2 - cw / 2) / cw
        if center_off > 0.03:
            level = FAIL
            msgs.append(f"水平偏移 {center_off * 100:.1f}%（应 ≤3%），角色会站偏")
        elif center_off > 0.015:
            if level == OK:
                level = WARN
            msgs.append(f"水平偏移 {center_off * 100:.1f}%（建议 ≤1.5%）")

        # 高度占比
        hr = (b - t) / ch
        lo, hi = spec["height_ratio"]
        if hr < lo:
            level = FAIL if hr < lo - 0.08 else max(level, WARN)
            msgs.append(f"人物高度占比 {hr * 100:.0f}%（应 {lo * 100:.0f}-{hi * 100:.0f}%），会显得比别人小")
        elif hr > hi:
            level = FAIL if hr > hi + 0.05 else max(level, WARN)
            msgs.append(f"人物高度占比 {hr * 100:.0f}%（应 {lo * 100:.0f}-{hi * 100:.0f}%），会顶出格子")

        # 安全区
        if l < spec["safe_margin"] or r > cw - spec["safe_margin"] or t < spec["safe_margin"]:
            if level == OK:
                level = WARN
            msgs.append(f"内容触边（左右上应留 ≥{spec['safe_margin']}px），描边可能被裁")

    # 半透明灰边检测（抠图残留）
    # 正常抗锯齿边缘通常只占 1-3%；超过 3% 说明抠得不干净，深色背景上会泛白边
    hist = alpha.histogram()
    total = cw * ch
    semi = sum(hist[8:248])
    semi_ratio = semi / total
    if semi_ratio > 0.08:
        level = FAIL
        msgs.append(f"半透明像素占 {semi_ratio * 100:.1f}%（应 <3%），边缘有明显灰边/羽化残留")
    elif semi_ratio > 0.03:
        if level == OK:
            level = WARN
        msgs.append(f"半透明像素占 {semi_ratio * 100:.1f}%（应 <3%），边缘偏毛，建议重新抠图")

    # 地块：必须不透明铺满
    if spec["anchor"] == "fill":
        opaque_ratio = sum(hist[250:]) / total
        if opaque_ratio < 0.99:
            level = FAIL
            msgs.append(f"不透明像素仅 {opaque_ratio * 100:.1f}%，地块必须铺满（否则拼接露缝）")

    return level, msgs


def main() -> int:
    only = sys.argv[1] if len(sys.argv) > 1 else None
    fail = warn = 0
    checked = 0

    for name, spec in SPECS.items():
        if only and only != name:
            continue
        d = ROOT / spec["dir"]
        print(f"\n=== {name}  ({spec['dir']})  —— {spec['note']}")
        if not d.exists():
            print("  (目录不存在，跳过)")
            continue
        files = sorted(p for p in d.glob("*.png") if not p.name.endswith(".import"))
        if not files:
            print("  (暂无资源，目录已就绪)")
            continue
        for p in files:
            checked += 1
            level, msgs = check_file(p, spec)
            if level == FAIL:
                fail += 1
            elif level == WARN:
                warn += 1
            head = f"  [{level}] {p.name}"
            print(head)
            for m in msgs:
                print(f"         - {m}")

    print(f"\n合计校验 {checked} 张：{fail} 张不合格，{warn} 张有告警")
    if fail:
        print("→ 有 FAIL 项，先修这些再入库（否则游戏里会出现浮空/站偏/大小不一）")
        return 1
    if warn:
        print("→ 仅有告警，可入库，建议后续统一")
        return 2
    print("→ 全部合规 ✅")
    return 0


if __name__ == "__main__":
    sys.exit(main())
