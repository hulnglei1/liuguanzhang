"""从 normal 立绘派生情绪立绘（angry / shock）。

为什么不 AI 重绘：实测两次图生图都会把水墨厚涂带成"美漫赛璐璐"，
脸型和服装都会变——对话里切换表情时反而出戏。
这里只做色彩分级：原图一笔不改，保证身体/服装/构图绝对一致。

angry：提对比、压暗、偏红、加暗角、轻微推近 → 视觉上"上火了"
shock：提亮、去饱和、偏冷、轻微拉远 → 视觉上"懵了/倒吸一口气"
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PORTRAITS = ROOT / "assets" / "portraits"

# 实际被对白引用到的组合（见 docs/游戏设计文档 与对白统计）
NEEDED = {
    "zhangfei": ["angry"],
    "guanyu": ["angry", "shock"],
    "lubu": ["shock"],
    "wuanguo": ["shock"],
    "zhaoyun": ["angry"],
    "gongsunzan": ["angry"],
    "xuchu": ["angry", "shock"],
    "zangba": ["shock"],
}


def zoom(img: Image.Image, factor: float) -> Image.Image:
    w, h = img.size
    nw, nh = int(w / factor), int(h / factor)
    left, top = (w - nw) // 2, (h - nh) // 2
    return img.crop((left, top, left + nw, top + nh)).resize((w, h), Image.LANCZOS)


def vignette(arr: np.ndarray, strength: float) -> np.ndarray:
    h, w = arr.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    cx, cy = w / 2, h / 2
    d = np.sqrt(((xx - cx) / cx) ** 2 + ((yy - cy) / cy) ** 2)
    v = np.clip(1.0 - strength * np.clip(d - 0.45, 0, 1) ** 1.3, 0.55, 1.0)
    arr[:, :, :3] *= v[:, :, None]
    return arr


def grade(img: Image.Image, emotion: str) -> Image.Image:
    if emotion == "angry":
        img = zoom(img, 1.05)
    elif emotion == "shock":
        img = zoom(img, 0.97)

    arr = np.asarray(img).astype(np.float64)
    rgb = arr[:, :, :3] / 255.0

    if emotion == "angry":
        rgb = (rgb - 0.5) * 1.18 + 0.46          # 对比↑ 整体压暗
        rgb[:, :, 0] *= 1.10                      # 偏红
        rgb[:, :, 1] *= 0.94
        rgb[:, :, 2] *= 0.88
        # 提高高光锐度：让眼神更"凶"
        rgb = np.clip(rgb, 0, 1) ** 0.94
        arr[:, :, :3] = np.clip(rgb * 255, 0, 255)
        arr = vignette(arr, 0.55)
    else:  # shock
        gray = rgb.mean(axis=2, keepdims=True)
        rgb = gray + (rgb - gray) * 0.70          # 去饱和（更明显）
        rgb = (rgb - 0.5) * 1.08 + 0.56           # 提亮
        rgb[:, :, 2] *= 1.13                       # 偏冷
        rgb[:, :, 0] *= 0.95
        arr[:, :, :3] = np.clip(rgb * 255, 0, 255)
        arr = vignette(arr, 0.25)

    out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    return out


def main():
    count = 0
    for uid, emotions in NEEDED.items():
        src = PORTRAITS / (uid + "_normal.png")
        if not src.exists():
            print("  [MISS] %s" % src.name)
            continue
        base = Image.open(src).convert("RGBA")
        for emo in emotions:
            out = PORTRAITS / ("%s_%s.png" % (uid, emo))
            grade(base, emo).save(out)
            print("  %-22s <- %s" % (out.name, src.name))
            count += 1
    print("\n共生成 %d 张情绪立绘" % count)


if __name__ == "__main__":
    main()
