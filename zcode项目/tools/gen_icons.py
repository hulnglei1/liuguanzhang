"""程序化生成 UI 图标：朱红印章 + 楷书单字。

为什么用印章不用通用图标包：
- 通用 CC0 图标包是扁平彩色风，和本作"水墨+金边+朱印"的调性打架；
- 印章单字是中式 UI 的正统做法（按钮、状态、属性都用它），风格天然统一；
- 程序化生成 = 零版权、零下载、随时可改。

尺寸 128×128，透明底。调用方用 Button.icon 挂上去。
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 128
OUT = Path(__file__).resolve().parents[1] / "assets" / "icons"
OUT.mkdir(parents=True, exist_ok=True)

# 楷书（古风），Windows 自带 simkai.ttf
FONT_PATH = r"C:\Windows\Fonts\simkai.ttf"
if not Path(FONT_PATH).exists():
    FONT_PATH = r"C:\Windows\Fonts\simhei.ttf"

# 图标名 → (单字, 用途, 印泥色)
ICONS = [
    ("attack",  "兵", "普通攻击", (0.72, 0.18, 0.16)),
    ("skill",   "技", "绝技",     (0.60, 0.14, 0.14)),
    ("move",    "行", "移动",     (0.16, 0.34, 0.26)),
    ("endturn", "止", "结束回合", (0.28, 0.26, 0.30)),
    ("morale",  "势", "战局士气", (0.70, 0.42, 0.10)),
    ("hp",      "命", "生命值",   (0.42, 0.14, 0.20)),
    ("atk",     "攻", "攻击力",   (0.66, 0.30, 0.12)),
    ("def",     "防", "防御力",   (0.16, 0.28, 0.44)),
    ("mov",     "移", "移动力",   (0.20, 0.36, 0.44)),
    ("range",   "射", "射程",     (0.34, 0.30, 0.18)),
]


def rounded_seal(size: int, color) -> Image.Image:
    """朱红印章：圆角方框 + 边缘做旧（轻微缺口 + 噪点）"""
    pad = 6
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rgba = tuple(int(c * 255) for c in color) + (255,)
    d.rounded_rectangle([pad, pad, size - pad, size - pad], radius=16,
                        fill=rgba[:3] + (235,), outline=rgba, width=3)
    # 做旧：随机小缺口
    import random
    rnd = random.Random(7)
    for _ in range(26):
        x = rnd.randint(pad, size - pad)
        y = rnd.randint(pad, size - pad)
        r = rnd.randint(1, 3)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(0, 0, 0, 0))
    return img


def main():
    font = ImageFont.truetype(FONT_PATH, 78)
    for name, glyph, usage, color in ICONS:
        seal = rounded_seal(SIZE, color)
        # 字：白色，带一点柔和投影
        layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        bbox = d.textbbox((0, 0), glyph, font=font)
        w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
        x = (SIZE - w) / 2 - bbox[0]
        y = (SIZE - h) / 2 - bbox[1] + 4
        shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).text((x + 2, y + 2), glyph, font=font, fill=(0, 0, 0, 120))
        shadow = shadow.filter(ImageFilter.GaussianBlur(2))
        layer = Image.alpha_composite(shadow, layer)
        ImageDraw.Draw(layer).text((x, y), glyph, font=font, fill=(255, 248, 235, 255))

        out = Image.alpha_composite(seal, layer)
        path = OUT / (name + ".png")
        out.save(path)
        print("  %-10s %s  (%s)" % (name + ".png", glyph, usage))
    print("\n共 %d 张图标 -> %s" % (len(ICONS), OUT))


if __name__ == "__main__":
    main()
