#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""全量回归测试：自动发现并运行 tests/ 下所有测试，汇总结果。

用法：
    python tools/run_all_tests.py              # 跑全部
    python tools/run_all_tests.py core e2e     # 只跑文件名含这些关键词的
    python tools/run_all_tests.py --list       # 只列出会跑哪些

退出码：0 全过；1 有失败
"""
import argparse
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent          # zcode项目/
GAME_ROOT = ROOT.parent                                 # 工作区根
GODOT = GAME_ROOT / ".tools" / "godot_extracted" / "Godot_v4.7.2-stable_win64_console.exe"

# 这些是演示/录制脚本，不是测试，默认跳过
SKIP = {"capture_visual_showcase", "director_promo", "demo_virtual_player_live",
        "live_headed_multiverse", "live_headed_tester", "test_virtual_player"}

FAIL_PAT = re.compile(r"SCRIPT ERROR|Parse Error|\[FAIL\]|超时未完成|失败 [1-9]\d* 项")


def discover() -> list[Path]:
    tests = sorted(ROOT.glob("tests/*.gd"))
    return [t for t in tests if t.stem not in SKIP and not t.stem.endswith("_template")]


def run_one(path: Path, timeout: int = 90) -> tuple[bool, str, float]:
    cmd = [str(GODOT), "--headless", "--path", str(ROOT), "--script",
           f"res://tests/{path.name}"]
    t0 = time.time()
    try:
        p = subprocess.run(cmd, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=timeout)
        out = (p.stdout or "") + (p.stderr or "")
    except subprocess.TimeoutExpired:
        return False, "TIMEOUT", time.time() - t0
    dt = time.time() - t0
    bad = FAIL_PAT.search(out)
    if bad:
        line = next((ln.strip() for ln in out.splitlines()
                     if FAIL_PAT.search(ln)), "?")
        return False, line[:110], dt
    return True, "", dt


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("filters", nargs="*", help="文件名关键词（可多个，命中任一即跑）")
    ap.add_argument("--list", action="store_true", help="只列出将运行哪些测试")
    ap.add_argument("--timeout", type=int, default=90, help="单个测试超时秒数")
    args = ap.parse_args()

    tests = discover()
    if args.filters:
        tests = [t for t in tests if any(f in t.stem for f in args.filters)]

    if not tests:
        print("没有匹配的测试")
        return 1
    if args.list:
        for t in tests:
            print(" ", t.stem)
        print(f"共 {len(tests)} 个")
        return 0

    if not GODOT.exists():
        print(f"找不到 Godot：{GODOT}")
        print("（首次使用请确认 .tools/godot_extracted/ 下有 Godot 可执行文件）")
        return 1

    print(f"=== 全量回归：{len(tests)} 个测试 ===")
    ok, bad = [], []
    for t in tests:
        passed, msg, dt = run_one(t, args.timeout)
        if passed:
            ok.append(t.stem)
            print(f"  [OK]   {t.stem:<28} {dt:5.1f}s")
        else:
            bad.append((t.stem, msg))
            print(f"  [FAIL] {t.stem:<28} {dt:5.1f}s  → {msg}")

    print(f"\n=== 汇总：{len(ok)} 通过 / {len(bad)} 失败 ===")
    if bad:
        print("失败项：")
        for name, msg in bad:
            print(f"  - {name}: {msg}")
        return 1
    print("全部通过 [PASS]")
    return 0


if __name__ == "__main__":
    sys.exit(main())
