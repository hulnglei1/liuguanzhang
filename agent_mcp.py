# agent_mcp.py
# Python CLI controller for MCP Agent Game Testing
# Interacts purely through black-box screenshot viewing & coordinate clicking.

import sys
import json
import time
import os
import subprocess

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8')

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
GAME_DIR = os.path.join(BASE_DIR, "game")
CMD_FILE = os.path.join(GAME_DIR, "agent_cmd.json")
RESP_FILE = os.path.join(GAME_DIR, "agent_resp.json")
GODOT_EXE = os.path.join(BASE_DIR, "godot_bin", "Godot_v4.3-stable_win64_console.exe")

def is_godot_running():
    out = subprocess.run(["powershell", "-Command", "Get-Process -Name Godot* -ErrorAction SilentlyContinue"], capture_output=True, text=True)
    return "Godot" in out.stdout

def launch_godot():
    if not is_godot_running():
        print("[MCP] 🚀 正在启动游戏客户端窗口 (1280x720)...")
        DETACHED_PROCESS = 0x00000008
        subprocess.Popen([GODOT_EXE, "--path", GAME_DIR], cwd=GAME_DIR, creationflags=DETACHED_PROCESS)
        time.sleep(3.0)
    else:
        print("[MCP] 🎮 游戏客户端正在运行中")

def send_command(cmd_dict, timeout=10.0):
    # Ensure any previous response is removed
    if os.path.exists(RESP_FILE):
        try: os.remove(RESP_FILE)
        except: pass
        
    with open(CMD_FILE, "w", encoding="utf-8") as f:
        json.dump(cmd_dict, f, ensure_ascii=False, indent=2)
        
    start_time = time.time()
    while time.time() - start_time < timeout:
        if os.path.exists(RESP_FILE):
            time.sleep(0.05) # Give it a moment to finish writing
            try:
                with open(RESP_FILE, "r", encoding="utf-8") as f:
                    resp = json.load(f)
                return resp
            except Exception:
                pass
        time.sleep(0.05)
    return {"status": "timeout", "message": f"Command timed out after {timeout}s"}

def main():
    if len(sys.argv) < 2:
        print("Usage: python agent_mcp.py [launch | screenshot | click <x> <y> | key <key> | wait <secs>]")
        return
        
    action = sys.argv[1].lower()
    
    if action == "launch":
        launch_godot()
        # Take initial screenshot
        resp = send_command({"action": "screenshot"})
        print(json.dumps(resp, ensure_ascii=False, indent=2))
        return
        
    if not is_godot_running():
        launch_godot()
        
    if action in ["screenshot", "view"]:
        resp = send_command({"action": "screenshot"})
        print(json.dumps(resp, ensure_ascii=False, indent=2))
    elif action == "click":
        if len(sys.argv) < 4:
            print("Error: click requires x and y coordinates")
            return
        x = float(sys.argv[2])
        y = float(sys.argv[3])
        resp = send_command({"action": "click", "x": x, "y": y})
        print(json.dumps(resp, ensure_ascii=False, indent=2))
    elif action == "key":
        key = sys.argv[2] if len(sys.argv) > 2 else "space"
        resp = send_command({"action": "key", "key": key})
        print(json.dumps(resp, ensure_ascii=False, indent=2))
    elif action == "wait":
        secs = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0
        resp = send_command({"action": "wait", "seconds": secs})
        print(json.dumps(resp, ensure_ascii=False, indent=2))
    else:
        print(f"Unknown action: {action}")

if __name__ == "__main__":
    main()
