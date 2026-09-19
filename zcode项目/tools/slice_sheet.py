#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
序列帧与动作图集自动切图工具 (SpriteSheet Slicer)

用法：
    # 将一张 4 列 1 行的横向动作大图切分成 4 张独立帧
    python tools/slice_sheet.py --input "原图/关羽劈刀_4帧.png" --cols 4 --rows 1 --out "assets/units/guanyu_attack"

    # 切图的同时自动将每一帧对齐贴底与居中（避免播放时角色上下乱颠）
    python tools/slice_sheet.py --input "原图/关羽待机_3帧.png" --cols 3 --rows 1 --normalize --out "assets/units/guanyu_idle"
"""

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("错误：需要 Pillow 库，请先执行 pip install pillow")
    sys.exit(1)

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")


def slice_image(src_path: Path, cols: int, rows: int, out_dir: Path, do_normalize: bool) -> None:
    if not src_path.exists():
        print(f"❌ 找不到输入文件: {src_path}")
        sys.exit(1)

    out_dir.mkdir(parents=True, exist_ok=True)
    img = Image.open(src_path).convert("RGBA")
    w, h = img.size

    frame_w = w // cols
    frame_h = h // rows
    stem = src_path.stem

    print(f"🎬 开始切图: {src_path.name}")
    print(f"   大图尺寸: {w}x{h} | 划分: {cols} 列 x {rows} 行 | 单帧标称尺寸: {frame_w}x{frame_h}")

    idx = 0
    for r in range(rows):
        for c in range(cols):
            x0 = c * frame_w
            y0 = r * frame_h
            x1 = x0 + frame_w
            y1 = y0 + frame_h

            crop = img.crop((x0, y0, x1, y1))

            if do_normalize:
                # 计算不透明区域边界，裁除空白后居中贴底
                bbox = crop.getchannel("A").getbbox()
                if bbox:
                    char_crop = crop.crop(bbox)
                    cw, ch = char_crop.size

                    # 生成标准正方形画布
                    canvas = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
                    paste_x = (frame_w - cw) // 2
                    paste_y = frame_h - ch - 4  # 底部保留 4px 安全区贴底
                    canvas.paste(char_crop, (paste_x, paste_y), char_crop)
                    crop = canvas

            out_file = out_dir / f"{stem}_{idx:02d}.png"
            crop.save(out_file, "PNG")
            print(f"   [+] 切片导出: {out_file.name} ({crop.size[0]}x{crop.size[1]})")
            idx += 1

    print(f"✅ 切图完成！共生成 {idx} 个动作序列帧，已保存至: {out_dir}")


def main():
    parser = argparse.ArgumentParser(description="SpriteSheet 序列帧自动切图与贴底工具")
    parser.add_argument("--input", "-i", required=True, type=Path, help="待切的图集大图路径")
    parser.add_argument("--cols", "-c", required=True, type=int, help="横向列数")
    parser.add_argument("--rows", "-r", default=1, type=int, help="纵向行数（默认为1）")
    parser.add_argument("--out", "-o", required=True, type=Path, help="切片输出目录")
    parser.add_argument("--normalize", "-n", action="store_true", help="是否对切出的每帧进行居中贴底规整")

    args = parser.parse_args()
    slice_image(args.input, args.cols, args.rows, args.out, args.normalize)


if __name__ == "__main__":
    main()
