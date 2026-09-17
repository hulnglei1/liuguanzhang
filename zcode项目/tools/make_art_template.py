#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成美术母版与错误示意（规范的可视化版本）

产物（docs/art/）：
    母版_立绘_900x1200.png      立绘对齐母版（可丢进 AI 工具当构图参考）
    母版_单位_192x192.png       战场单位对齐母版
    母版_地块_104x104_平铺.png  地块母版 + 3x3 拼接示意
    示意_常见错误对比.png       合规 / 浮空 / 站偏 / 灰边 四联对比

规范调整后重跑本脚本即可刷新母版。
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "art"
OUT.mkdir(parents=True, exist_ok=True)

BG = (18, 20, 26, 255)
GRID = (44, 48, 58, 255)
SAFE = (234, 198, 91, 255)      # #EAC65B 项目金
BASE = (226, 75, 74, 255)       # 基准线（脚底）
CENTER = (133, 183, 235, 255)   # 中心线
TEXT = (217, 217, 217, 255)
WARN = (226, 75, 74, 255)
OKC = (99, 153, 34, 255)


def font(sz: int):
    for p in [r"C:\Windows\Fonts\simhei.ttf", r"C:\Windows\Fonts\msyh.ttc"]:
        if Path(p).exists():
            try:
                return ImageFont.truetype(p, sz)
            except Exception:
                pass
    return ImageFont.load_default()


def dashed(dr, p1, p2, color, dash=14, gap=10, width=1):
    x1, y1 = p1
    x2, y2 = p2
    dist = max(1, int(((x2 - x1) ** 2 + (y2 - y1) ** 2) ** 0.5))
    for i in range(0, dist, dash + gap):
        t0, t1 = i / dist, min(1.0, (i + dash) / dist)
        dr.line([x1 + (x2 - x1) * t0, y1 + (y2 - y1) * t0,
                 x1 + (x2 - x1) * t1, y1 + (y2 - y1) * t1], fill=color, width=width)


def make_portrait_template():
    W, H = 900, 1200
    im = Image.new("RGBA", (W, H), BG)
    dr = ImageDraw.Draw(im)
    for x in range(0, W, 50):
        dr.line([(x, 0), (x, H)], fill=GRID, width=1)
    for y in range(0, H, 50):
        dr.line([(0, y), (W, y)], fill=GRID, width=1)

    ratio = 0.83
    top = int(H * (1 - ratio))
    pad = 30  # 安全区

    dashed(dr, (pad, pad), (W - pad, pad), SAFE)
    dashed(dr, (pad, pad), (pad, H - pad), SAFE)
    dashed(dr, (W - pad, pad), (W - pad, H - pad), SAFE)

    dr.line([(W // 2, 0), (W // 2, H)], fill=CENTER, width=2)
    dr.line([(0, H - 8), (W, H - 8)], fill=BASE, width=3)
    dr.line([(0, top), (W, top)], fill=SAFE, width=2)

    f1, f2 = font(26), font(20)
    dr.text((W // 2 + 8, top - 34), "头顶线 y=204（人物高 996px，占 83%）", font=f2, fill=SAFE)
    dr.text((W // 2 + 8, 14), "画布 900 x 1200（3:4）· 安全区 30px 内不要放描边/发丝", font=f2, fill=TEXT)
    dr.text((W // 2 + 8, H - 40), "脚底线 y=1192 —— 人物脚底必须落在这里（±10px 内）", font=f2, fill=BASE)
    dr.text((W // 2 + 12, 300), "中心线 x=450", font=f2, fill=CENTER)
    dr.text((pad + 6, H // 2), "半透明背景仅作图用，最终导出必须透明", font=f2, fill=TEXT)
    dr.text((pad + 6, H - 90), "命名：{unit_id}_{emotion}.png   例 guanyu_angry.png", font=f1, fill=SAFE)
    im.save(OUT / "母版_立绘_900x1200.png")


def make_unit_template():
    W, H = 192, 192
    im = Image.new("RGBA", (W, H), BG)
    dr = ImageDraw.Draw(im)
    for x in range(0, W, 16):
        dr.line([(x, 0), (x, H)], fill=GRID)
    for y in range(0, H, 16):
        dr.line([(0, y), (W, y)], fill=GRID)
    ratio = 0.88
    top = int(H * (1 - ratio))
    dr.line([(W // 2, 0), (W // 2, H)], fill=CENTER, width=1)
    dr.line([(0, H - 8), (W, H - 8)], fill=BASE, width=2)
    dr.line([(0, top), (W, top)], fill=SAFE, width=1)
    dashed(dr, (4, 4), (W - 4, 4), SAFE)
    f = font(13)
    dr.text((6, H - 60), "脚底线 y=184", font=f, fill=BASE)
    dr.text((6, 6), "192x192", font=f, fill=TEXT)
    dr.text((6, 24), "高占比 88%", font=f, fill=SAFE)
    dr.text((6, 42), "居中/脚底贴底", font=f, fill=CENTER)
    im.save(OUT / "母版_单位_192x192.png")


def make_tile_template():
    W, H = 104, 104
    one = Image.new("RGBA", (W, H), (23, 33, 21, 255))
    dr = ImageDraw.Draw(one)
    dr.rectangle([0, 0, W - 1, H - 1], outline=(73, 78, 86, 255))
    f = font(13)
    dr.text((8, 8), "104x104", font=f, fill=TEXT)
    dr.text((8, 26), "铺满不透明", font=f, fill=SAFE)

    sheet = Image.new("RGBA", (W * 3 + 40, H * 3 + 70), BG)
    for i in range(3):
        for j in range(3):
            sheet.paste(one, (10 + i * W, 40 + j * H), one)
    ds = ImageDraw.Draw(sheet)
    ds.text((10, 10), "3x3 拼接示意：相邻边必须无缝（左右/上下可接）", font=font(20), fill=TEXT)
    ds.text((10, 40 + H * 3 + 12), "地形贴图光照统一：左上 45° 光源，暗部朝右下", font=font(18), fill=SAFE)
    sheet.save(OUT / "母版_地块_104x104_平铺.png")


def make_error_demo():
    """四联对比：同一张画布上，人物站位/边缘处理正确与错误的差别"""
    CW, CH = 240, 320          # 模拟画布（3:4，与立绘一致）
    PAD = 18
    PANEL_W = CW + PAD * 2
    sheet = Image.new("RGBA", (PANEL_W * 4 + 20, CH + 170), BG)
    ds = ImageDraw.Draw(sheet)
    f1, f2 = font(22), font(16)

    def person(foot_gap=0, x_off=0, semi=False):
        im = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
        dr = ImageDraw.Draw(im)
        cx = CW // 2 + x_off
        foot = CH - foot_gap
        head_top = foot - 250
        dr.ellipse((cx - 40, head_top, cx + 40, head_top + 78), fill=(235, 215, 185, 255))
        dr.polygon([(cx, head_top + 78), (cx - 58, foot), (cx + 58, foot)], fill=(70, 135, 95, 255))
        if semi:
            dr.ellipse((cx - 40, head_top, cx + 40, head_top + 78), outline=(255, 255, 255, 120), width=13)
            dr.polygon([(cx, head_top + 78), (cx - 58, foot), (cx + 58, foot)],
                       outline=(255, 255, 255, 100), width=13)
        return im

    items = [
        ("合规", person(), OKC, "脚底贴底 · 居中"),
        ("脚底悬空", person(foot_gap=56), WARN, "角色浮空一截"),
        ("水平偏移", person(x_off=44), WARN, "站偏，换人会跳"),
        ("抠图灰边", person(semi=True), WARN, "深色底泛白边"),
    ]

    for i, (label, art, col, tip) in enumerate(items):
        px = 10 + i * PANEL_W
        py = 26
        ds.text((px + PAD, py), label, font=f1, fill=col)
        ds.text((px + PAD, py + 30), tip, font=f2, fill=TEXT)
        # 画布框
        cy = py + 60
        ds.rectangle([px + PAD, cy, px + PAD + CW, cy + CH], outline=col, width=2)
        # 脚底基准线（画布底边）
        ds.line([(px + PAD, cy + CH), (px + PAD + CW, cy + CH)], fill=BASE, width=3)
        sheet.paste(art, (px + PAD, cy), art)
        ds.text((px + PAD, cy + CH + 14), "红线 = 脚底基准线", font=f2, fill=BASE)
        if i == 0:
            ds.line([(px + PAD + CW // 2, cy), (px + PAD + CW // 2, cy + CH)],
                    fill=CENTER, width=1)
            ds.text((px + PAD, cy + CH + 38), "蓝线 = 中心线", font=f2, fill=CENTER)

    ds.text((10, sheet.height - 34),
            "四种错误都会在游戏里表现为「有人浮空 / 有人站偏 / 有的顶出格子 / 深色底泛白边」",
            font=f2, fill=SAFE)
    sheet.save(OUT / "示意_常见错误对比.png")


if __name__ == "__main__":
    make_portrait_template()
    make_unit_template()
    make_tile_template()
    make_error_demo()
    print("母版与示意已生成 ->", OUT)
    for p in sorted(OUT.glob("*.png")):
        print("  ", p.name)
