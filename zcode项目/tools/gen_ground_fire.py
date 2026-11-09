"""生成"火场"地面变体（洛阳大火专用）：焦土 + 炭化裂缝 + 余烬。

与草地版同样是**一整张连续图**（2496×1456），保证格与格之间无缝。
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 2496, 1456   # 24x14 棋盘 @2x
OUT = Path(__file__).resolve().parents[1] / "assets" / "tiles"
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(20261107)


def smooth_noise(w, h, cells, seed_rng):
    small = seed_rng.random((cells, cells)) * 255
    img = Image.fromarray(small.astype(np.uint8), "L").resize((w, h), Image.BICUBIC)
    return np.asarray(img, dtype=np.float64) / 255.0


def fbm(w, h, octaves, weights):
    acc = np.zeros((h, w))
    total = 0.0
    for cells, wt in zip(octaves, weights):
        acc += smooth_noise(w, h, cells, rng) * wt
        total += wt
    return acc / total


base = fbm(W, H, (6, 12, 26, 60), (1.0, 0.55, 0.3, 0.15))
fine = smooth_noise(W, H, 200, rng)

# 焦土：黑褐为主
lo = np.array([26, 20, 17], dtype=np.float64)
hi = np.array([66, 50, 38], dtype=np.float64)
val = np.clip(0.65 * base + 0.35 * fine, 0, 1)
rgb = lo[None, None, :] + (hi - lo)[None, None, :] * val[:, :, None]

# 炭化裂缝：用脊状噪声（ridged noise）生成网状裂纹
ridged = 1.0 - np.abs(fbm(W, H, (22, 48, 96), (1.0, 0.5, 0.25)) * 2 - 1)
crack = np.clip((ridged - 0.88) * 9.0, 0, 1)
crack = np.asarray(
    Image.fromarray((crack * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(1.6)),
    dtype=np.float64) / 255.0
ember = np.array([214, 78, 18], dtype=np.float64)
rgb = rgb * (1 - crack[:, :, None] * 0.62) + ember[None, None, :] * (crack[:, :, None] * 0.62)

# 落灰
ash = np.array([138, 132, 126], dtype=np.float64)
rgb = rgb * (1 - 0.18 * fine[:, :, None]) + ash[None, None, :] * (0.18 * fine[:, :, None])

img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").convert("RGBA")

# 灰烬颗粒 + 零星未熄的火星
d = ImageDraw.Draw(img, "RGBA")
for _ in range(3000):
    x, y = rng.integers(0, W), rng.integers(0, H)
    r = rng.integers(0, 2)
    g = rng.integers(70, 120)
    d.ellipse([x - r, y - r, x + r, y + r], fill=(g, g - 4, g - 10, 28))
for _ in range(150):
    x, y = rng.integers(0, W), rng.integers(0, H)
    r = rng.integers(1, 4)
    d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 140, 55, 90))
img = img.filter(ImageFilter.GaussianBlur(0.4))

# 暗角（比草地版更强，火场本身就是压抑的）
arr = np.asarray(img).astype(np.float64)
yy, xx = np.mgrid[0:H, 0:W]
cx, cy = W / 2, H / 2
dist = np.sqrt(((xx - cx) / cx) ** 2 + ((yy - cy) / cy) ** 2)
v = np.clip(1.0 - 0.26 * np.clip(dist - 0.45, 0, 1) ** 1.3, 0.72, 1.0)
arr[:, :, :3] *= v[:, :, None]
Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA").save(OUT / "ground_fire.png")

print("ground_fire.png ->", img.size, "%.1f KB" % ((OUT / "ground_fire.png").stat().st_size / 1024))
