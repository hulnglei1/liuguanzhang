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
import os
import re
import shutil
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

FAIL_PAT = re.compile(r"SCRIPT ERROR|Parse Error|\[FAIL\]|超时未完成|失败 [1-9]\d* 项|未通关")

# 这些测试要完整打一遍关卡，耗时远超默认 90 秒
SLOW = {
    "probe_player_styles": 360,   # 4 种玩家风格各打一遍第一关
    "probe_player_view": 200,     # 主菜单→序章→战场全流程
    "probe_space_endturn": 200,   # 多个回合流转
    "probe_chaos": 200,           # 随机操作 100+ 步
}


def discover() -> list[Path]:
    tests = sorted(ROOT.glob("tests/*.gd"))
    return [t for t in tests if t.stem not in SKIP and not t.stem.endswith("_template")]


def run_one(path: Path, timeout: int = 90) -> tuple[bool, str, float]:
    # 少数测试天生慢（要完整打一遍关卡），单独放宽超时
    timeout = SLOW.get(path.stem, timeout)
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


def _user_save_path() -> Path:
    """玩家真实存档位置：%APPDATA%/Godot/app_userdata/<项目名>/save.json"""
    appdata = os.environ.get("APPDATA") or os.path.expanduser("~")
    return Path(appdata) / "Godot" / "app_userdata" / "魂穿刘关张 · 战棋" / "save.json"


if __name__ == "__main__":
    # 保护玩家进度：测试脚本会反复重置存档（SaveCore.new_state()），
    # 直接跑会把玩家辛苦打出来的章节/声望/背包全清掉。
    # 所以跑测试前先备份、跑完（无论成败）还原。
    _save = _user_save_path()
    _bak = _save.parent / (_save.name + ".userbak")
    _had_save = _save.exists()
    if _had_save:
        shutil.copy2(_save, _bak)
    try:
        _code = main()
    finally:
        if _had_save and _bak.exists():
            shutil.copy2(_bak, _save)
            _bak.unlink()
            print("\n[已还原玩家存档] 测试过程重置的进度已恢复：%s" % _save)
    sys.exit(_code)
