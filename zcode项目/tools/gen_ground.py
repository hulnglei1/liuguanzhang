"""生成一整张连续的战场地面（2496×1456，2 倍于棋盘 1248×728）。

为什么不按格子铺：每格铺一张 104×104，等于每格都把图案"重置"一次，
格与格之间必然对不上，玩家看到的就是一块块补丁。
整张连续纹理才可能真正连起来。
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 2496, 1456   # 24x14 棋盘 @2x
OUT = Path(__file__).resolve().parents[1] / "assets" / "tiles"
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(20261107)


def smooth_noise(w, h, cells, seed_rng):
    """把一张低分辨率随机场放大成平滑噪声，模拟自然起伏"""
    small = seed_rng.random((cells, cells)) * 255
    img = Image.fromarray(small.astype(np.uint8), "L").resize((w, h), Image.BICUBIC)
    return np.asarray(img, dtype=np.float64) / 255.0


def fbm(w, h, octaves=(6, 12, 24, 48, 96), weights=(1.0, 0.55, 0.3, 0.16, 0.08)):
    acc = np.zeros((h, w))
    total = 0.0
    for cells, wt in zip(octaves, weights):
        acc += smooth_noise(w, h, cells, rng) * wt
        total += wt
    return acc / total


# --- 基础起伏 ---
base = fbm(W, H)
fine = smooth_noise(W, H, 220, rng)

# 大尺度明暗（让地面不是均匀一片）
macro = smooth_noise(W, H, 5, rng)
val = 0.62 * base + 0.18 * fine + 0.20 * macro

# --- 草色 ---
lo = np.array([30, 48, 30], dtype=np.float64)
hi = np.array([64, 88, 52], dtype=np.float64)
rgb = lo[None, None, :] + (hi - lo)[None, None, :] * val[:, :, None]

# --- 土斑：低频噪声超过阈值的地方露土 ---
dirt_mask = smooth_noise(W, H, 7, rng)
dirt_mask = np.clip((dirt_mask - 0.56) * 3.2, 0, 1)
dirt_mask = np.asarray(
    Image.fromarray((dirt_mask * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(18)),
    dtype=np.float64) / 255.0
dirt_lo = np.array([78, 66, 46], dtype=np.float64)
dirt_hi = np.array([104, 88, 62], dtype=np.float64)
dirt_rgb = dirt_lo[None, None, :] + (dirt_hi - dirt_lo)[None, None, :] * val[:, :, None]
rgb = rgb * (1 - dirt_mask[:, :, None]) + dirt_rgb * dirt_mask[:, :, None]

img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").convert("RGBA")

# --- 草叶（细密、低对比，不抢戏）---
d = ImageDraw.Draw(img, "RGBA")
for _ in range(5200):
    x, y = rng.integers(0, W), rng.integers(0, H)
    ang = rng.uniform(-1.35, -0.35)
    ln = rng.integers(2, 7)
    x2 = int(x + np.cos(ang) * ln)
    y2 = int(y + np.sin(ang) * ln)
    shade = rng.integers(0, 2)
    col = (86, 124, 70, 90) if shade else (34, 54, 32, 90)
    d.line([(x, y), (x2, y2)], fill=col, width=1)

# --- 碎石 ---
for _ in range(260):
    x, y = rng.integers(0, W), rng.integers(0, H)
    r = rng.integers(1, 4)
    g = rng.integers(70, 110)
    d.ellipse([x - r, y - r, x + r, y + r], fill=(g, g - 6, g - 16, 70))

# --- 轻微暗角，让视线聚到中间 ---
yy, xx = np.mgrid[0:H, 0:W]
cx, cy = W / 2, H / 2
dist = np.sqrt(((xx - cx) / cx) ** 2 + ((yy - cy) / cy) ** 2)
vignette = np.clip(1.0 - 0.18 * np.clip(dist - 0.55, 0, 1) ** 1.4, 0.82, 1.0)
arr = np.asarray(img).astype(np.float64)
arr[:, :, :3] *= vignette[:, :, None]
img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")

img.save(OUT / "ground.png")
print("ground.png ->", img.size, "%.1f KB" % ((OUT / "ground.png").stat().st_size / 1024))
