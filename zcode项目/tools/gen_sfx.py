"""程序化生成战棋音效（16-bit 44.1kHz 单声道 WAV）。

为什么不下载素材包：合成音零版权风险、可复现、体积小；
战棋这类回合制的音效只需要"清脆/有反馈"，不需要真实录音。

产出到 zcode项目/assets/audio/：
  ui_click / attack / hit / skill / death / victory / defeat / turn
"""
import wave
from pathlib import Path

import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)

rng = np.random.default_rng(20261106)


def t(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def env(n, attack=0.005, decay=3.5, hold=0.0):
    """指数包络：快起、指数衰减。"""
    a = int(SR * attack)
    e = np.ones(n)
    if a > 1:
        e[:a] = np.linspace(0, 1, a)
    rest = np.exp(-decay * np.linspace(0, 1, n - a) ** 0.9) if n > a else np.ones(0)
    e[a:] = rest
    if hold > 0:
        h = int(SR * hold)
        if h < n:
            e[h:] *= np.exp(-decay * np.linspace(0, 1, n - h))
    return e


def save(name, data, peak=0.85):
    data = np.asarray(data, dtype=np.float64)
    m = np.max(np.abs(data)) or 1.0
    data = data / m * peak
    # 5ms 淡出，避免爆音
    f = min(len(data), int(SR * 0.005))
    if f > 1:
        data[-f:] *= np.linspace(1, 0, f)
    pcm = (data * 32767).astype(np.int16)
    path = OUT / (name + ".wav")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("  %-10s %5d ms  %6.1f KB" % (name, len(data) / SR * 1000, path.stat().st_size / 1024))


# 1. UI 点击：短促高频
x = t(0.05)
save("ui_click", np.sin(2 * np.pi * 1350 * x) * env(len(x), decay=9) * 0.6
     + rng.normal(0, 0.03, len(x)) * env(len(x), decay=14))

# 2. 普攻：噪声冲击 + 下滑音（挥砍感）
x = t(0.18)
f = np.linspace(520, 130, len(x))
sweep = np.sin(2 * np.pi * np.cumsum(f) / SR)
noise = rng.normal(0, 1, len(x))
noise = np.convolve(noise, np.ones(6) / 6, mode="same")      # 轻微低通
save("attack", (sweep * 0.55 + noise * 0.5) * env(len(x), decay=5.5, attack=0.002))

# 3. 命中：低频闷响 + 短噪声
x = t(0.14)
thud = np.sin(2 * np.pi * 95 * x) * np.exp(-np.linspace(0, 6, len(x)))
crack = rng.normal(0, 1, len(x)) * np.exp(-np.linspace(0, 22, len(x)))
save("hit", thud * 0.9 + crack * 0.35)

# 4. 绝技：上扬扫频 + 二次谐波（蓄力爆发）
x = t(0.32)
f = np.linspace(280, 1250, len(x)) ** 1.02
ph = 2 * np.pi * np.cumsum(f) / SR
sweep = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.18 * np.sin(3 * ph)
shimmer = 0.12 * np.sin(2 * np.pi * 2100 * x) * np.exp(-np.linspace(0, 3, len(x)))
save("skill", (sweep * 0.7 + shimmer) * env(len(x), attack=0.03, decay=2.6))

# 5. 阵亡：下沉 + 噪声尾
x = t(0.5)
f = np.linspace(420, 70, len(x))
ph = 2 * np.pi * np.cumsum(f) / SR
save("death", (np.sin(ph) * 0.8 + rng.normal(0, 0.15, len(x))) * env(len(x), decay=3.2))

# 6. 胜利：大三和弦琶音
def note(freq, dur, decay=4.0, amp=0.7):
    xx = t(dur)
    return (np.sin(2 * np.pi * freq * xx) + 0.3 * np.sin(4 * np.pi * freq * xx)) * env(len(xx), decay=decay) * amp


victory = np.concatenate([
    note(523.25, 0.14, 4), note(659.25, 0.14, 4),
    note(783.99, 0.14, 4), note(1046.50, 0.42, 2.4),
])
save("victory", victory)

# 7. 战败：下行小调
def gliss(f0, f1, dur, decay=2.6, amp=0.7):
    xx = t(dur)
    f = np.linspace(f0, f1, len(xx))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(xx), decay=decay) * amp


save("defeat", np.concatenate([
    gliss(392, 330, 0.3, 3.0), gliss(330, 262, 0.55, 2.0),
]))

# 8. 回合切换：双音轻铃
x = t(0.26)
bell = (np.sin(2 * np.pi * 880 * x) + 0.5 * np.sin(2 * np.pi * 1320 * x)) * np.exp(-np.linspace(0, 7, len(x)))
x2 = t(0.26)
bell2 = np.sin(2 * np.pi * 1320 * x2) * np.exp(-np.linspace(0, 10, len(x2))) * 0.5
mix = bell * 0.7
off = int(SR * 0.06)
mix[off:] += bell2[:len(mix) - off] * 0.5
save("turn", mix)

print("\n全部生成到", OUT)
