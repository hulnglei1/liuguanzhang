#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""美术资源自动规整：把 AI 出的原图（任意尺寸/构图）批量处理成项目规范格式

为什么要它：AI 出的图尺寸、人物大小、站位都不一致，靠手工 PS 会被逼疯，
            而且手工一不一致，游戏里就会出现"有人浮空、有人站偏、有的顶出格子"。

它会做四件事：
    1. 裁掉四周透明边（trim）
    2. 按规范高度占比缩放（立绘 83%、单位 88%）
    3. 贴到规范画布上：脚底贴底、水平居中
    4. 可选：统一色板（把整体色相/饱和度往主视觉拉，解决多批出图偏色）

用法：
    # 先看会怎么处理（不写文件）
    python tools/normalize_art.py --kind portraits --dry-run 原图/*.png

    # 处理并输出到规范目录
    python tools/normalize_art.py --kind portraits 原图/*.png

    # 指定命名（把原图名映射成 unit_id_emotion；不带 --name 时沿用原名）
    python tools/normalize_art.py --kind portraits --name guanyu_normal.png 关羽.png

    # 单位 / 地块
    python tools/normalize_art.py --kind units 原图/*.png
    python tools/normalize_art.py --kind tiles 原图/*.png

处理完请务必跑一遍 tools/check_art.py 复验。
"""
import argparse
import shutil
import sys
from pathlib import Path

try:
    from PIL import Image, ImageEnhance
except ImportError:
    print("需要 Pillow：pip install pillow")
    sys.exit(1)

ROOT = Path(__file__).resolve().parent.parent

SPECS = {
    # kind: (画布, 高度占比, 输出目录, 是否要求脚底贴底)
    "portraits": ((900, 1200), 0.83, "assets/portraits", True),
    "units": ((192, 192), 0.88, "assets/units", True),
    "tiles": ((104, 104), 1.00, "assets/tiles", False),
}


def normalize(src: Path, spec, out_dir: Path, dry: bool, name: str | None,
              saturate: float) -> Path | None:
    size, ratio, _d, anchor_bottom = spec
    img = Image.open(src)
    if img.mode != "RGBA":
        img = img.convert("RGBA")

    bbox = img.getchannel("A").getbbox()
    if bbox is None:
        print(f"  [SKIP] {src.name}：全透明，跳过")
        return None
    img = img.crop(bbox)

    if anchor_bottom:
        target_h = int(size[1] * ratio)
        scale = target_h / img.height
        new_w = max(1, round(img.width * scale))
        img = img.resize((new_w, target_h), Image.LANCZOS)
        if new_w > size[0]:
            print(f"  [WARN] {src.name}：等比缩放后宽 {new_w}px > 画布 {size[0]}px，将被左右裁切")
            left = (new_w - size[0]) // 2
            img = img.crop((left, 0, left + size[0], target_h))
            new_w = size[0]
        canvas = Image.new("RGBA", size, (0, 0, 0, 0))
        canvas.paste(img, ((size[0] - new_w) // 2, size[1] - target_h), img)
        out = canvas
    else:
        out = img.resize(size, Image.LANCZOS)

    if abs(saturate - 1.0) > 0.001:
        rgb = out.convert("RGB")
        rgb = ImageEnhance.Color(rgb).enhance(saturate)
        rgb.putalpha(out.getchannel("A"))
        out = rgb

    out_dir.mkdir(parents=True, exist_ok=True)
    dst = out_dir / (name or src.name)
    if dst.suffix.lower() != ".png":
        dst = dst.with_suffix(".png")
    if dry:
        print(f"  [DRY] {src.name} -> {dst.relative_to(ROOT)}  画布{size[0]}x{size[1]} 高占比{ratio:.0%}")
        return None
    out.save(dst)
    print(f"  [OK ] {src.name} -> {dst.relative_to(ROOT)}")
    return dst


def main() -> int:
    ap = argparse.ArgumentParser(description="把 AI 原图规整成项目美术规范格式")
    ap.add_argument("files", nargs="+", help="原始图片路径（支持通配）")
    ap.add_argument("--kind", choices=list(SPECS), default="portraits")
    ap.add_argument("--name", default=None, help="输出文件名（单张时用）")
    ap.add_argument("--dry-run", action="store_true", help="只预览不写文件")
    ap.add_argument("--saturate", type=float, default=1.0,
                    help="统一饱和度，如 0.9 表示降饱和 10%%（多批出图偏色时用）")
    ap.add_argument("--in-place", action="store_true", help="覆盖原文件（默认输出到规范目录）")
    args = ap.parse_args()

    spec = SPECS[args.kind]
    out_dir = ROOT / spec[2] if not args.in_place else None
    if args.name and len(args.files) > 1:
        print("--name 仅在处理单张时可用")
        return 1

    print(f"处理 {len(args.files)} 张 -> {spec[2]}（画布 {spec[0][0]}x{spec[0][1]}，高度占比 {spec[1]:.0%}）")
    if args.dry_run:
        print("（dry-run：不会写文件）")
    for f in args.files:
        p = Path(f)
        if not p.exists():
            print(f"  [MISS] {f} 不存在")
            continue
        target_dir = out_dir if out_dir else p.parent
        normalize(p, spec, target_dir, args.dry_run, args.name, args.saturate)

    print("\n下一步：python tools/check_art.py %s   # 复验" % args.kind)
    return 0


if __name__ == "__main__":
    sys.exit(main())
