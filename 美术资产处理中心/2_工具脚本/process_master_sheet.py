#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
关羽全套母图 (Master Sheet) 一次性生成与切图入库流水线

核心原理（第一性原理）：
1. 成本最优：单次生图 API 调用生成包含「立绘 + 2x2 战斗序列帧」的母图，杜绝多次调用的费用浪费。
2. 画风绝对一致：同一模型在同一画布内完成立绘与动作切片，服饰/武器/脸部特征 100% 统一。
3. 自动化闭环：rembg 去底 -> 智能区域切片 -> 居中贴底标准化 -> 自动同步入库与质检。
"""

import os
import sys
import time
import base64
import shutil
from pathlib import Path

try:
    import requests
    from PIL import Image
    import rembg
except ImportError as e:
    print(f"缺失必要库: {e}，请运行: pip install requests pillow rembg")
    sys.exit(1)

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

CENTER_DIR = Path(__file__).resolve().parent.parent
GAME_ASSETS = CENTER_DIR.parent / "zcode项目" / "assets"
API_URL = "https://api.slomerex.xyz/v1/images/generations"
API_KEY = os.getenv("SLOMEREX_API_KEY", "sk-NPXEyJQcAEbjzfNlrReTCSP0iNRBl1kJ9IZbcQ2PklDtVXNm")
MODEL = "gpt-image-2.5-sunburst-1K"

GUANYU_PROMPT = (
    "A comprehensive character master sprite sheet for a comedic Three Kingdoms strategy tactical RPG game, "
    "vibrant Chinese comic manhua art style, clean solid pure white background #FFFFFF, highly detailed, zero background clutter. "
    "Layout: "
    "LEFT HALF (50% width): Full-body character portrait of Guan Yu, whose soul is a transmigrated modern slacker college student. "
    "Features: crimson-red skin, magnificent long lush black beard, ornate green silk warrior robe with golden dragon embroidery, "
    "dark green headscarf, holding the giant ornate Green Dragon Crescent Blade casually. "
    "Comedic expression: a crooked sly smirk and smug grin at corner of mouth, one raised eyebrow, mischievous eyes looking sideways, "
    "pretending to look like an aloof invincible God of War while secretly snickering about exploiting game bugs. "
    "RIGHT HALF (50% width): 4 combat battle chibi sprites of this exact same Guan Yu with identical costume, arranged in a clean 2x2 grid: "
    "Top-Left: Idle stance, standing ready with crescent blade, confident cheeky smile. "
    "Top-Right: Wind-up charging pose, leaning back and hoisting the heavy blade over shoulder, preparing to slash. "
    "Bottom-Left: Dynamic power slash impact, swinging the Green Dragon Blade forward in a wide arc with vivid emerald green dragon energy blade wave. "
    "Bottom-Right: Follow-through and landing pose, blade sweeping down, triumphant smug grin. "
    "All characters on pure white background, distinct margins between left and right sides and between grid cells."
)


def call_api_with_retry(prompt: str, size: str = "1024x1024", max_retries: int = 5, delay: float = 4.0) -> bytes | None:
    headers = {
        "Authorization": f"Bearer {API_KEY.strip()}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": MODEL,
        "prompt": prompt,
        "size": size
    }

    for attempt in range(1, max_retries + 1):
        print(f"\n[尝试 {attempt}/{max_retries}] 请求中转站生成关羽全家桶母图 (模型: {MODEL}, 尺寸: {size})...")
        try:
            resp = requests.post(API_URL, headers=headers, json=payload, timeout=120)
            if resp.status_code == 200:
                data = resp.json()
                items = data.get("data", [])
                if items:
                    b64 = items[0].get("b64_json")
                    if b64:
                        print("  ✅ 成功获取 Base64 图片数据！")
                        return base64.b64decode(b64)
                    url = items[0].get("url")
                    if url:
                        print(f"  ✅ 获取图片 URL: {url}，正在下载...")
                        r = requests.get(url, timeout=60)
                        if r.status_code == 200:
                            return r.content
                print(f"  ⚠️ 未找到图片数据: {data}")
            elif resp.status_code == 401:
                print(f"  ❌ 授权失败 (401): {resp.text}")
                return None
            else:
                print(f"  ⚠️ 状态码 {resp.status_code}: {resp.text[:200]}")
        except Exception as e:
            print(f"  ⚠️ 网络异常: {e}")

        if attempt < max_retries:
            print(f"  ⏳ 等待 {delay} 秒后重试...")
            time.sleep(delay)

    return None


def clean_alpha_noise(img: Image.Image) -> Image.Image:
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    r, g, b, a = img.split()
    a = a.point(lambda p: p if p >= 20 else 0)
    return Image.merge("RGBA", (r, g, b, a))


def normalize_to_canvas(crop_img: Image.Image, canvas_size: tuple[int, int], height_ratio: float, anchor_bottom: bool = True, bottom_margin: int = 4) -> Image.Image:
    img = clean_alpha_noise(crop_img)
    bbox = img.getchannel("A").getbbox()
    if bbox is None:
        return Image.new("RGBA", canvas_size, (0, 0, 0, 0))

    cropped = img.crop(bbox)
    cw, ch = cropped.size
    target_w, target_h = canvas_size

    scale = (target_h * height_ratio) / float(ch)
    if cw * scale > target_w * 0.96:
        scale = (target_w * 0.96) / float(cw)

    new_w = max(1, int(round(cw * scale)))
    new_h = max(1, int(round(ch * scale)))
    resized = cropped.resize((new_w, new_h), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    pos_x = (target_w - new_w) // 2
    if anchor_bottom:
        pos_y = target_h - new_h - bottom_margin
    else:
        pos_y = (target_h - new_h) // 2

    canvas.paste(resized, (pos_x, pos_y), resized)
    return canvas


def slice_master_sheet(nobg_path: Path):
    print(f"\n✂️ 开始智能切分母图: {nobg_path}...")
    master = Image.open(nobg_path).convert("RGBA")
    W, H = master.size

    # 1. 切分左半区：立绘 (Portrait)
    left_crop = master.crop((0, 0, int(W * 0.50), H))
    portrait_canvas = normalize_to_canvas(left_crop, (900, 1200), height_ratio=0.85, anchor_bottom=True, bottom_margin=8)

    # 2. 切分右半区：2x2 战斗序列帧
    right_crop = master.crop((int(W * 0.50), 0, W, H))
    rw, rh = right_crop.size
    half_rw = rw // 2
    half_rh = rh // 2

    q_idle = right_crop.crop((0, 0, half_rw, half_rh))          # Top-Left: Idle
    q_windup = right_crop.crop((half_rw, 0, rw, half_rh))        # Top-Right: Wind-up
    q_slash = right_crop.crop((0, half_rh, half_rw, rh))        # Bottom-Left: Slash
    q_smug = right_crop.crop((half_rw, half_rh, rw, rh))        # Bottom-Right: Smug

    unit_idle = normalize_to_canvas(q_idle, (192, 192), height_ratio=0.82, anchor_bottom=True, bottom_margin=4)
    frame_0 = normalize_to_canvas(q_idle, (192, 192), height_ratio=0.82, anchor_bottom=True, bottom_margin=4)
    frame_1 = normalize_to_canvas(q_windup, (192, 192), height_ratio=0.82, anchor_bottom=True, bottom_margin=4)
    frame_2 = normalize_to_canvas(q_slash, (192, 192), height_ratio=0.82, anchor_bottom=True, bottom_margin=4)
    frame_3 = normalize_to_canvas(q_smug, (192, 192), height_ratio=0.82, anchor_bottom=True, bottom_margin=4)

    # 3. 输出到 5_最终入库成品/
    out_portrait_dir = CENTER_DIR / "5_最终入库成品" / "portraits"
    out_unit_dir = CENTER_DIR / "5_最终入库成品" / "units"
    out_attack_dir = out_unit_dir / "guanyu_attack"

    out_portrait_dir.mkdir(parents=True, exist_ok=True)
    out_unit_dir.mkdir(parents=True, exist_ok=True)
    out_attack_dir.mkdir(parents=True, exist_ok=True)

    # 保存立绘
    p1 = out_portrait_dir / "guanyu_normal.png"
    p2 = out_portrait_dir / "guanyu.png"
    portrait_canvas.save(p1)
    portrait_canvas.save(p2)
    print(f"  ✅ 立绘保存成功: {p1} ({p1.stat().st_size / 1024:.1f} KB)")

    # 保存单位 Idle
    u_idle_path = out_unit_dir / "guanyu.png"
    unit_idle.save(u_idle_path)
    print(f"  ✅ 战场 Idle 单位保存成功: {u_idle_path}")

    # 保存攻击 4 帧（支持 0.png 及 guanyu_attack_sheet_00.png 两种命名）
    frames = [frame_0, frame_1, frame_2, frame_3]
    for idx, f in enumerate(frames):
        f.save(out_attack_dir / f"{idx}.png")
        f.save(out_attack_dir / f"guanyu_attack_sheet_{idx:02d}.png")
        f.save(out_attack_dir / f"guanyu_attack_{idx}.png")
    print(f"  ✅ 战场 4 帧攻击序列帧切片保存成功: {out_attack_dir}")


def sync_to_game():
    print(f"\n🔄 正在一键同步至游戏运行资产目录: {GAME_ASSETS}...")
    src_p = CENTER_DIR / "5_最终入库成品" / "portraits"
    src_u = CENTER_DIR / "5_最终入库成品" / "units"
    dst_p = GAME_ASSETS / "portraits"
    dst_u = GAME_ASSETS / "units"

    dst_p.mkdir(parents=True, exist_ok=True)
    dst_u.mkdir(parents=True, exist_ok=True)

    for item in src_p.glob("*.png"):
        shutil.copy2(item, dst_p / item.name)
        print(f"  -> 同步立绘: {item.name}")

    for item in src_u.glob("*.png"):
        shutil.copy2(item, dst_u / item.name)
        print(f"  -> 同步单位: {item.name}")

    src_attack = src_u / "guanyu_attack"
    dst_attack = dst_u / "guanyu_attack"
    if src_attack.exists():
        dst_attack.mkdir(parents=True, exist_ok=True)
        for item in src_attack.glob("*.png"):
            shutil.copy2(item, dst_attack / item.name)
            print(f"  -> 同步动作帧: guanyu_attack/{item.name}")

    print("🎉 游戏资产同步完成！")


def main():
    print("==================================================")
    print("🎨 关羽全家桶母图流水线 (单次出图·全套切片·绝对一致)")
    print(f"   生图模型: {MODEL}")
    print(f"   接口地址: {API_URL}")
    print("==================================================")

    # 1. 检查或生成母图
    raw_dir = CENTER_DIR / "3_原始出图_raw"
    raw_dir.mkdir(parents=True, exist_ok=True)
    raw_file = raw_dir / "guanyu_master_raw.png"

    img_bytes = call_api_with_retry(GUANYU_PROMPT, size="1024x1024", max_retries=5)
    if not img_bytes:
        print("❌ 生图请求未成功返回。")
        sys.exit(1)

    with open(raw_file, "wb") as f:
        f.write(img_bytes)
    print(f"✅ 原始母图已保存: {raw_file} ({len(img_bytes)/1024:.1f} KB)")

    # 2. rembg 抠图去底
    proc_dir = CENTER_DIR / "4_抠图与切片_processed"
    proc_dir.mkdir(parents=True, exist_ok=True)
    nobg_file = proc_dir / "guanyu_master_nobg.png"

    print(f"\n🪄 正在调用 rembg 进行智能纯透明去底...")
    with open(raw_file, "rb") as inp_f:
        raw_data = inp_f.read()
    nobg_data = rembg.remove(raw_data)
    with open(nobg_file, "wb") as out_f:
        out_f.write(nobg_data)
    print(f"✅ 扣图完成: {nobg_file}")

    # 3. 智能切片与规整
    slice_master_sheet(nobg_file)

    # 4. 同步入库
    sync_to_game()

    print("\n🎉 全套资产生成、去底、切片与游戏同步一键达成！")


if __name__ == "__main__":
    main()
