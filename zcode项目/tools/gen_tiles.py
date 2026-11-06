"""程序化生成战棋地块贴图（104×104，四方连续）。

为什么程序化：AI 出的地块很难保证"上边接得下边"，而棋盘是平铺的，
一条接缝就会毁掉整片地面。这里用**整数频率的正弦叠加**生成天然可平铺的噪声，
再加少量细节（草叶/石纹），保证四周严格对接。
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

N = 104
OUT = Path(__file__).resolve().parents[1] / "assets" / "tiles"
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(20261107)

yy, xx = np.mgrid[0:N, 0:N]


def periodic_noise(octaves):
    """整数频率正弦叠加 → 严格的四方连续噪声，值域约 [-1,1]"""
    acc = np.zeros((N, N), dtype=np.float64)
    amp = 1.0
    total = 0.0
    for kx, ky in octaves:
        ph = rng.uniform(0, 2 * np.pi)
        acc += amp * np.sin(2 * np.pi * (kx * xx + ky * yy) / N + ph)
        total += amp
        amp *= 0.62
    return acc / max(total, 1e-6)


def colorize(val, base, span, alpha=255):
    """val∈[-1,1] → RGB"""
    v = np.clip((val + 1) / 2, 0, 1)
    rgb = np.zeros((N, N, 3), dtype=np.uint8)
    for i in range(3):
        lo, hi = base[i], base[i] + span[i]
        rgb[:, :, i] = np.clip(lo + (hi - lo) * v, 0, 255).astype(np.uint8)
    a = np.full((N, N, 1), alpha, dtype=np.uint8)
    return Image.fromarray(np.concatenate([rgb, a], axis=2), "RGBA")


def add_tufts(img, n, color, length=(3, 7), width=1):
    """草叶/石子：按模坐标绘制，越界的部分从另一侧补，保持无缝"""
    d = ImageDraw.Draw(img)
    for _ in range(n):
        x, y = rng.integers(0, N, 2)
        ang = rng.uniform(-0.9, -0.4)
        ln = rng.integers(length[0], length[1])
        x2 = int(x + np.cos(ang) * ln)
        y2 = int(y + np.sin(ang) * ln)
        for dx in (-N, 0, N):
            for dy in (-N, 0, N):
                d.line([(x + dx, y + dy), (x2 + dx, y2 + dy)], fill=color, width=width)
    return img


# 草地 A（稍亮）与 B（稍暗）—— 两张交替铺，保留棋盘的"格"感
for name, base, span, tuft in [
    ("grass_a", (34, 56, 34), (26, 40, 24), (86, 132, 74)),
    ("grass_b", (28, 48, 28), (22, 34, 20), (74, 116, 64)),
]:
    img = colorize(periodic_noise([(1, 2), (2, 1), (3, 5), (5, 3), (8, 8)]), base, span)
    img = add_tufts(img, 26, tuft + (150,))
    img.save(OUT / (name + ".png"))
    print("  %-10s -> %s" % (name, (OUT / (name + ".png")).name))

# 高地/岩石：灰褐，对比更强
img = colorize(periodic_noise([(1, 1), (3, 2), (5, 4), (7, 9)]), (78, 66, 48), (54, 46, 36))
d = ImageDraw.Draw(img)
for _ in range(14):                        # 裂纹
    x, y = rng.integers(0, N, 2)
    x2 = x + rng.integers(-22, 22)
    y2 = y + rng.integers(-22, 22)
    for dx in (-N, 0, N):
        for dy in (-N, 0, N):
            d.line([(x + dx, y + dy), (x2 + dx, y2 + dy)], fill=(46, 38, 28, 210), width=1)
img.save(OUT / "stone.png")
print("  stone      -> stone.png")

# 土路/干地（后续关卡可直接用）
img = colorize(periodic_noise([(1, 2), (2, 3), (4, 1), (6, 5)]), (92, 76, 52), (40, 34, 24))
img = add_tufts(img, 18, (66, 54, 38, 160), length=(2, 4))
img.save(OUT / "dirt.png")
print("  dirt       -> dirt.png")

print("\n全部生成到", OUT)
