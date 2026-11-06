"""生成障碍物贴图：寨墙（青石砖）与关门（铁木城门），104×104。"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

N = 104
OUT = Path(__file__).resolve().parents[1] / "assets" / "tiles"
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(20261107)


def grain(img, amount=10):
    arr = np.asarray(img).astype(np.int16)
    noise = rng.integers(-amount, amount + 1, (arr.shape[0], arr.shape[1], 1))
    arr[:, :, :3] = np.clip(arr[:, :, :3] + noise, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


# ---------- 青石寨墙 ----------
wall = Image.new("RGBA", (N, N), (52, 56, 62, 255))
d = ImageDraw.Draw(wall)
row_h = 26
for ry in range(0, N, row_h):
    offset = (ry // row_h % 2) * 26
    for bx in range(-26, N + 26, 52):
        x0 = bx + offset
        top = ry
        shade = rng.integers(0, 14)
        body = (74 + shade, 78 + shade, 86 + shade, 255)
        d.rectangle([x0 + 1, top + 1, x0 + 50, top + row_h - 2], fill=body)
        # 砖面高光与磨损
        d.line([(x0 + 2, top + 2), (x0 + 49, top + 2)], fill=(96 + shade, 100 + shade, 108 + shade, 255))
        if rng.random() < 0.35:
            d.line([(x0 + 8, top + 14), (x0 + 30, top + 14)], fill=(60, 62, 68, 255))
wall = grain(wall, 8)
wall.save(OUT / "wall.png")
print("wall.png")

# ---------- 铁木城门 ----------
gate = Image.new("RGBA", (N, N), (46, 30, 20, 255))
d = ImageDraw.Draw(gate)
plank_w = 17
for px in range(0, N, plank_w):
    shade = rng.integers(0, 16)
    d.rectangle([px, 0, px + plank_w - 2, N], fill=(92 + shade, 58 + shade, 32 + shade, 255))
    d.line([(px, 0), (px, N)], fill=(54, 34, 20, 255))
# 横向铁箍
for y in (22, 78):
    d.rectangle([0, y, N, y + 7], fill=(58, 58, 64, 255))
    d.line([(0, y + 1), (N, y + 1)], fill=(92, 92, 100, 255))
# 门钉
for y in (26, 82):
    for x in range(10, N, 21):
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(120, 120, 128, 255))
        d.ellipse([x - 3, y - 3, x + 3, y + 3], outline=(70, 70, 76, 255))
# 中缝
d.line([(N // 2, 0), (N // 2, N)], fill=(30, 20, 14, 255), width=2)
gate = grain(gate, 6)
gate.save(OUT / "gate.png")
print("gate.png")
