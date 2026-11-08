"""给主角生成待机 / 攻击序列帧（程序化，不是逐帧 AI 生图）。

为什么不用 AI 逐帧生成：
    每一帧都是独立一次生成，角色会"每一帧都重画一遍"——脸、衣纹、武器角度全在抖，
    连起来就是闪烁。实测过情绪立绘那种图生图，同一提示词两帧之间都对不齐，
    8 帧连续播放只会更糟。

这里用**单图剪影变换**（pivot 锁在脚底）：
    待机 = 轻微挤压 + 摆动，攻击 = 后仰蓄力 → 前冲拉伸 → 收势。
    同一张原图只做仿射变换，所以帧与帧之间**像素级一致**，风格零漂移。
    单位在战场上只有约 70px 高，这种变换完全够读。
"""
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
UNITS = ROOT / "assets" / "units"

PAD = 64           # 四周留白，避免旋转/拉伸时被裁
CANVAS = 256 + PAD * 2

# 待机：#(纵向缩放, 旋转角°, 横向位移)
IDLE = [
    (1.000, 0.0, 0.0),
    (1.022, -0.6, 0.6),
    (1.000, 0.0, 0.0),
    (0.982, 0.6, -0.6),
]

# 攻击：#(纵向缩放, 旋转角°, 横向位移, 横向拉伸)
ATTACK = [
    (1.030, 3.5, -2.0, 1.00),   # 蓄力后仰
    (0.960, -7.0, 5.0, 1.07),   # 前冲出手
    (0.985, -4.0, 3.0, 1.03),   # 余势
    (1.000, 0.0, 0.0, 1.00),    # 收势
]


def affine_about(pivot, theta_deg, sy, sx, dx):
    """绕 pivot 旋转 + 纵向缩放 sy + 横向缩放 sx + 平移 dx（反向采样矩阵）"""
    t = math.radians(theta_deg)
    c, s = math.cos(t), math.sin(t)
    # 反向映射：先平移回原点 → 反向缩放 → 反向旋转 → 平移回去
    a = c / sx
    b = s / sx
    d = -s / sy
    e = c / sy
    px, py = pivot
    cc = px - a * px - b * py - dx
    ff = py - d * px - e * py
    return (a, b, cc, d, e, ff)


def render(src: Image.Image, pivot, theta, sy, sx, dx) -> Image.Image:
    mat = affine_about(pivot, theta, sy, sx, dx)
    return src.transform((CANVAS, CANVAS), Image.AFFINE, mat, resample=Image.BICUBIC)


def build(uid: str) -> bool:
    src_path = UNITS / (uid + ".png")
    if not src_path.exists():
        print("  [MISS] %s" % src_path.name)
        return False

    base = Image.open(src_path).convert("RGBA")
    bbox = base.getbbox()
    if bbox is None:
        print("  [SKIP] %s 全透明" % uid)
        return False

    padded = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    padded.alpha_composite(base, (PAD, PAD))

    # 脚底中心作为支点（人物动画的铁律：脚不能飘）
    pivot = (PAD + (bbox[0] + bbox[2]) / 2.0, PAD + bbox[3])

    idle_dir = UNITS / (uid + "_idle")
    atk_dir = UNITS / (uid + "_attack")
    idle_dir.mkdir(exist_ok=True)
    atk_dir.mkdir(exist_ok=True)

    for i, (sy, deg, dx) in enumerate(IDLE):
        frame = render(padded, pivot, deg, sy, 1.0, dx)
        frame.crop((PAD, PAD, PAD + 256, PAD + 256)).save(idle_dir / ("%d.png" % i))

    for i, (sy, deg, dx, sx) in enumerate(ATTACK):
        frame = render(padded, pivot, deg, sy, sx, dx)
        frame.crop((PAD, PAD, PAD + 256, PAD + 256)).save(atk_dir / ("%d.png" % i))

    print("  %-10s idle 4 帧 + attack 4 帧" % uid)
    return True


def main():
    print("生成序列帧（程序化剪影变换）")
    # 主角：手绘（关羽）+ 程序化（其余三位）
    heroes = ["liubei", "zhangfei", "zhaoyun"]
    # 主将：出场就有"大动作"的 Boss，优先给
    bosses = ["huaxiong", "lubu", "xuchu", "zangba", "xurong", "dianwei", "wuanguo", "changxi"]
    for uid in heroes + bosses:
        build(uid)
    print("\n完成。关羽保留手绘帧不动。")


if __name__ == "__main__":
    main()
