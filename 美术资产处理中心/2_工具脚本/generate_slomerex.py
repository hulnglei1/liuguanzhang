#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Slomerex 中转站 AI 生图与自动重试落库工具

功能：
    1. 调用中转站的 images/generations 接口 (gpt-image-2.5-sunburst-1K)
    2. 内置多次自动重试机制 (针对中转站不稳定的网络/上游超时自动重试)
    3. 自动解析提取返回的 b64_json 或 URL，保存为原始图片
    4. 自动串联 normalize_art.py 规整与 check_art.py 合规质检

用法：
    python tools/generate_slomerex.py --kind portrait --name guanyu_normal --prompt "关羽全身立绘..."
    python tools/generate_slomerex.py --kind unit --name guanyu --prompt "关羽战场单位..."
"""

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

try:
    import requests
except ImportError:
    print("错误：需要 requests 库，请先安装 pip install requests")
    sys.exit(1)

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_API_URL = "https://api.slomerex.xyz/v1/images/generations"
DEFAULT_MODEL = "gpt-image-2.5-sunburst-1K"


def generate_with_retry(api_url: str, api_key: str, model: str, prompt: str, size: str, max_retries: int = 5, delay: float = 4.0) -> bytes | str | None:
    headers = {
        "Authorization": f"Bearer {api_key.strip()}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": model,
        "prompt": prompt,
        "size": size,
    }

    for attempt in range(1, max_retries + 1):
        print(f"\n[尝试 {attempt}/{max_retries}] 正在请求中转站: {api_url} (模型: {model}, 尺寸: {size})...")
        try:
            resp = requests.post(api_url, headers=headers, json=payload, timeout=90)
            
            if resp.status_code == 200:
                data = resp.json()
                items = data.get("data", [])
                if items:
                    first = items[0]
                    # 1. 优先检查 b64_json
                    b64_data = first.get("b64_json")
                    if b64_data:
                        print("  ✅ 成功获取 Base64 图片数据！")
                        return base64.b64decode(b64_data)
                    # 2. 检查 url
                    url = first.get("url")
                    if url:
                        print(f"  ✅ 成功获取图片 URL: {url}")
                        return url
                print(f"  ⚠️ 返回结构中未找到图片数据: {data}")
            elif resp.status_code == 401:
                print(f"  ❌ 认证失败 (HTTP 401 Unauthorized): {resp.text}")
                return None
            else:
                print(f"  ⚠️ 中转站返回状态码 {resp.status_code}: {resp.text[:200]}")

        except Exception as e:
            print(f"  ⚠️ 网络请求异常: {e}")

        if attempt < max_retries:
            print(f"  ⏳ 等待 {delay} 秒后重试下一次...")
            time.sleep(delay)

    print(f"❌ 经过 {max_retries} 次重试均未成功生成图片。")
    return None


def save_raw_image(result: bytes | str, save_path: Path) -> bool:
    save_path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(result, bytes):
        with open(save_path, "wb") as f:
            f.write(result)
        print(f"  ✅ Base64 图片保存成功: {save_path} ({len(result) / 1024:.1f} KB)")
        return True
    elif isinstance(result, str):
        print(f"📥 正在从 URL 下载图片: {result}...")
        try:
            r = requests.get(result, timeout=60)
            if r.status_code == 200:
                with open(save_path, "wb") as f:
                    f.write(r.content)
                print(f"  ✅ 下载成功: {save_path} ({len(r.content) / 1024:.1f} KB)")
                return True
        except Exception as e:
            print(f"  ❌ 下载异常: {e}")
            return False
    return False


def main():
    parser = argparse.ArgumentParser(description="Slomerex 中转站 AI 生图与自动规整工具")
    parser.add_argument("--kind", choices=["portrait", "unit", "tile", "sheet"], required=True, help="资产类型")
    parser.add_argument("--name", required=True, help="资产名称（如 guanyu_normal 或 guanyu）")
    parser.add_argument("--prompt", required=True, help="生图提示词")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="中转站生图模型名称")
    parser.add_argument("--key", default=os.getenv("SLOMEREX_API_KEY", "sk-NPXEyJQcAEbjzfNlrReTCSP0iNRBl1kJ9IZbcQ2PklDtVXNm"), help="API Key")
    parser.add_argument("--url", default=DEFAULT_API_URL, help="API Base URL")
    parser.add_argument("--retries", type=int, default=5, help="最大重试次数")

    args = parser.parse_args()

    # 根据类型选择最接近的尺寸
    if args.kind == "portrait":
        size = "1024x1536"  # 接近 900x1200 (3:4 / 2:3)
    elif args.kind == "sheet":
        size = "1536x1024"  # 横向图集
    else:
        size = "1024x1024"  # 1:1 正方形

    print("==================================================")
    print("🎨 启动 Slomerex AI 自动生图流水线")
    print(f"   目标资产: {args.kind} -> {args.name}")
    print(f"   生图模型: {args.model}")
    print(f"   目标尺寸: {size}")
    print(f"   重试上限: {args.retries} 次")
    print("==================================================")

    res = generate_with_retry(args.url, args.key, args.model, args.prompt, size, max_retries=args.retries)
    if not res:
        print("\n❌ 生图任务未成功完成。")
        sys.exit(1)

    # 下载/保存至 raw 目录
    raw_dir = ROOT / "assets" / "raw_downloads"
    raw_file = raw_dir / f"{args.name}_raw.png"
    if not save_raw_image(res, raw_file):
        sys.exit(1)

    # 如果是动作图集 (sheet)，调用切图工具
    if args.kind == "sheet":
        print("\n🎬 正在调用 slice_sheet.py 自动切图...")
        out_sheet_dir = ROOT / "assets" / "units" / args.name
        cmd = [
            sys.executable,
            str(ROOT / "tools" / "slice_sheet.py"),
            "--input", str(raw_file),
            "--cols", "4",
            "--rows", "1",
            "--normalize",
            "--out", str(out_sheet_dir)
        ]
        s_res = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8")
        print(s_res.stdout)
        if s_res.returncode != 0:
            print("⚠️ 切图报告异常:", s_res.stderr)
        return

    # 否则调用 normalize_art.py 自动居中贴底
    print("\n🚀 正在调用 normalize_art.py 进行规范化裁剪对齐...")
    norm_kind = "portraits" if args.kind == "portrait" else ("units" if args.kind == "unit" else "tiles")
    target_name = f"{args.name}.png"
    
    cmd = [
        sys.executable,
        str(ROOT / "tools" / "normalize_art.py"),
        "--kind", norm_kind,
        "--name", target_name,
        str(raw_file)
    ]
    norm_res = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8")
    print(norm_res.stdout)
    if norm_res.returncode != 0:
        print("⚠️ 规整工具报告错误:", norm_res.stderr)

    print("\n🔍 正在运行 check_art.py 执行最终质检...")
    chk_cmd = [sys.executable, str(ROOT / "tools" / "check_art.py"), norm_kind]
    chk_res = subprocess.run(chk_cmd, capture_output=True, text=True, encoding="utf-8")
    print(chk_res.stdout)


if __name__ == "__main__":
    main()
