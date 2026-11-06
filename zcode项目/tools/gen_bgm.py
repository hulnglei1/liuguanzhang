"""程序化生成 3 首循环 BGM（中国五声音阶），输出 WAV，再由 ffmpeg 转 OGG。

设计：
  bgm_menu   72 BPM，8 小节，缓慢、留白多（主菜单/图鉴）
  bgm_battle 96 BPM，8 小节，低音鼓点 + 拨弦动机（战场）
  bgm_win    只播一次，约 9 秒（结算）
"""
import wave
from pathlib import Path

import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(20261107)

# D 羽调式五声：D F G A C
D3, F3, G3, A3, C4, D4, F4, G4, A4, C5, D5 = (
    146.83, 174.61, 196.00, 220.00, 261.63, 293.66, 349.23, 392.00, 440.00, 523.25, 587.33)


def t(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def pluck(freq, dur, amp=0.5, bright=0.35):
    """拨弦：基频 + 少量泛音，指数衰减"""
    x = t(dur)
    e = np.exp(-4.2 * x / dur)
    w = (np.sin(2 * np.pi * freq * x)
         + bright * 0.5 * np.sin(4 * np.pi * freq * x)
         + bright * 0.25 * np.sin(6 * np.pi * freq * x))
    atk = int(SR * 0.004)
    if atk:
        w[:atk] *= np.linspace(0, 1, atk)
    return w * e * amp


def pad(freqs, dur, amp=0.16, attack=0.6, release=0.8):
    """铺底和弦：慢起慢落"""
    x = t(dur)
    w = np.zeros_like(x)
    for f in freqs:
        w += np.sin(2 * np.pi * f * x)
        w += 0.25 * np.sin(2 * np.pi * f * 2 * x)
    w /= max(len(freqs), 1)
    e = np.ones_like(x)
    a = int(SR * attack)
    r = int(SR * release)
    if a:
        e[:a] = np.linspace(0, 1, a) ** 1.6
    if r:
        e[-r:] *= np.linspace(1, 0, r) ** 1.4
    return w * e * amp


def drum(dur=0.5, amp=0.7, low=58, click=0.25):
    """战鼓：低频下滑 + 瞬态噪声"""
    x = t(dur)
    f = np.linspace(low * 2.2, low, len(x))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-7.5 * x / dur)
    noise = rng.normal(0, 1, len(x)) * np.exp(-30 * x / dur) * click
    return (body + noise) * amp


def bell(freq, dur=1.2, amp=0.35):
    x = t(dur)
    w = (np.sin(2 * np.pi * freq * x) * 0.7
         + np.sin(2 * np.pi * freq * 2.01 * x) * 0.2
         + np.sin(2 * np.pi * freq * 3.02 * x) * 0.1)
    return w * np.exp(-3.0 * x / dur) * amp


def mix_at(buf, sound, at_sec):
    i = int(SR * at_sec)
    n = min(len(sound), len(buf) - i)
    if n > 0:
        buf[i:i + n] += sound[:n]


def save(name, data, peak=0.75):
    m = np.max(np.abs(data)) or 1.0
    data = data / m * peak
    f = min(len(data), int(SR * 0.01))
    if f > 1:
        data[-f:] *= np.linspace(1, 0, f)
    pcm = (data * 32767).astype(np.int16)
    path = OUT / (name + ".wav")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("  %-11s %5.1fs  %6.1f KB" % (name, len(data) / SR, path.stat().st_size / 1024))


# ---------------- 主菜单：72 BPM，8 小节 ----------------
bpm = 72
beat = 60 / bpm
bar = beat * 4
total = bar * 8
buf = np.zeros(int(SR * total))

chords = [
    [D3, A3, D4], [F3, C4, F4], [G3, D4, G4], [A3, C4, A4],
    [D3, A3, D4], [F3, C4, F4], [G3, A3, D4], [D3, A3, D4],
]
for i, ch in enumerate(chords):
    mix_at(buf, pad(ch, bar * 1.05, amp=0.15, attack=0.5, release=1.0), i * bar)

melody = [
    (0, D5, 1.4), (1.6, A4, 1.0), (2.6, C5, 1.6),
    (4, G4, 1.6), (5.8, A4, 1.2),
    (8, F4, 1.4), (9.6, G4, 1.2), (10.8, A4, 1.8),
    (12, D5, 2.4),
    (16, C5, 1.2), (17.4, A4, 1.2), (18.8, G4, 1.8),
    (20, A4, 2.0),
    (24, D5, 1.6), (25.8, C5, 1.2), (27, A4, 2.2),
    (28, D5, 3.2),
]
for at, f, dur in melody:
    mix_at(buf, pluck(f, dur * 0.9, amp=0.42), at)
    mix_at(buf, bell(f, dur * 0.8, amp=0.12), at)
save("bgm_menu", buf, peak=0.7)

# ---------------- 战场：96 BPM，8 小节 ----------------
bpm = 96
beat = 60 / bpm
bar = beat * 4
total = bar * 8
buf = np.zeros(int(SR * total))

# 低音持续
for i in range(8):
    root = D3 if i % 4 != 2 else G3
    mix_at(buf, pad([root, root * 0.5], bar * 1.0, amp=0.13, attack=0.15, release=0.35), i * bar)

# 鼓点：每小节 1、3 拍重音，2、4 拍轻
for i in range(8):
    base = i * bar
    for b in range(4):
        strong = b in (0, 2)
        mix_at(buf, drum(0.45, amp=0.75 if strong else 0.4, low=56, click=0.3), base + b * beat)

# 拨弦动机（短促、重复，带推进感）
motif = [D4, A4, C5, A4, G4, D4, F4, G4]
for i in range(8):
    for k in range(4):
        f = motif[(i * 4 + k) % len(motif)]
        mix_at(buf, pluck(f, beat * 0.55, amp=0.28, bright=0.5), i * bar + k * beat)
save("bgm_battle", buf, peak=0.72)

# ---------------- 胜利结算：单次，约 9 秒 ----------------
total = 9.0
buf = np.zeros(int(SR * total))
prog = [
    (0.0, [D3, A3, D4], 2.4),
    (2.2, [G3, C4, G4], 2.4),
    (4.4, [A3, D4, A4], 2.2),
    (6.4, [D3, A3, D4, F4], 2.6),
]
for at, ch, dur in prog:
    mix_at(buf, pad(ch, dur, amp=0.18, attack=0.05, release=0.8), at)
for at, f in [(0.0, D5), (0.9, A4), (1.8, D5), (2.6, F4), (3.4, G4), (4.2, A4),
              (5.2, C5), (6.0, D5), (7.0, A4)]:
    mix_at(buf, pluck(f, 1.6, amp=0.4), at)
    mix_at(buf, bell(f, 1.4, amp=0.14), at)
for at in (0.0, 2.2, 4.4, 6.4):
    mix_at(buf, drum(0.6, amp=0.55, low=50, click=0.2), at)
save("bgm_win", buf, peak=0.78)

print("\nWAV 已生成：", OUT)
