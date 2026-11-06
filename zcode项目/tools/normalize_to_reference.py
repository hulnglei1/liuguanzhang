"""把 AI 出的新角色图，规整成与"参考资产"完全一致的尺寸/占比/落点。

为什么需要它：
  同类资产如果各按各的比例缩放，进游戏后换人时大小会跳、脚底会浮。
  关羽那套是已认可的标杆，所以让新角色**对齐关羽的包围盒**（左右中心、底边、占比）即可。

用法：
  python tools/normalize_to_reference.py \
      --src 原始出图.png \
      --ref assets/units/guanyu.png \
      --out assets/units/liubei.png \
      [--crop-bottom 70] [--crop-right 70] [--no-rembg]

依赖：Pillow、numpy、rembg（抠图）。
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image

try:
    from rembg import remove
except Exception:                      # 没装 rembg 时退化为"直接用原图 alpha"
    remove = None


def subject_bbox_fractions(img: Image.Image, thr: int = 8):
    a = np.array(img)[:, :, 3]
    ys, xs = np.where(a > thr)
    if len(xs) == 0:
        return (0.0, 0.0, 1.0, 1.0)
    w, h = img.size
    return (xs.min() / w, ys.min() / h, (xs.max() + 1) / w, (ys.max() + 1) / h)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--ref", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--crop-bottom", type=int, default=0, help="先裁掉底部若干像素（去水印用）")
    ap.add_argument("--crop-right", type=int, default=0, help="先裁掉右侧若干像素（去水印用）")
    ap.add_argument("--no-rembg", action="store_true")
    ap.add_argument("--policy", choices=["fit", "height"], default="fit",
                    help="fit=宽高取小（立绘用，避免裁到肩膀）；"
                         "height=按高度对齐（战场单位用，保证换人时大小一致）")
    args = ap.parse_args()

    src = Image.open(args.src).convert("RGBA")
    if args.crop_bottom or args.crop_right:
        w, h = src.size
        src = src.crop((0, 0, w - args.crop_right, h - args.crop_bottom))

    if remove is not None and not args.no_rembg:
        cut = remove(src)
    else:
        cut = src

    fb = subject_bbox_fractions(cut)
    a = np.array(cut)[:, :, 3]
    ys, xs = np.where(a > 8)
    if len(xs) == 0:
        raise SystemExit("抠图后没有内容，检查输入图")
    subject = cut.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))

    ref = Image.open(args.ref).convert("RGBA")
    tw, th = ref.size
    rl, rt, rr, rb = subject_bbox_fractions(ref)

    target_w = (rr - rl) * tw
    target_h = (rb - rt) * th
    if args.policy == "height":
        # 战场单位：以"高度占比"为准。游戏里单位是按贴图高度缩放的，
        # 只有内容高度一致，换人时才不会出现一个高一个矮（赵云披风宽，按 fit 会变矮）。
        scale = target_h / subject.height
        if subject.width * scale > target_w * 1.7:      # 过宽时略收，避免横向压到邻格
            scale = target_w * 1.7 / subject.width
    else:
        scale = min(target_w / subject.width, target_h / subject.height)
    new = subject.resize((max(1, round(subject.width * scale)),
                          max(1, round(subject.height * scale))), Image.LANCZOS)

    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    cx = (rl + rr) / 2.0 * tw
    x = round(cx - new.width / 2.0)
    y = round(rb * th - new.height)          # 底边对齐参考资产
    canvas.alpha_composite(new, (x, y))      # 允许 x 为负：过宽时左右对称溢出，居中不偏

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out)

    ob = subject_bbox_fractions(canvas)
    print("参考 %s  %dx%d  包围盒 L%.1f%% T%.1f%% R%.1f%% B%.1f%%"
          % (Path(args.ref).name, tw, th, rl * 100, rt * 100, rr * 100, rb * 100))
    print("输出 %s  %dx%d  包围盒 L%.1f%% T%.1f%% R%.1f%% B%.1f%%"
          % (out.name, tw, th, ob[0] * 100, ob[1] * 100, ob[2] * 100, ob[3] * 100))
    print("源图内容框占比 %.1f%%（参考 %.1f%%）"
          % ((fb[2] - fb[0]) * (fb[3] - fb[1]) * 100, (rr - rl) * (rb - rt) * 100))


if __name__ == "__main__":
    main()
