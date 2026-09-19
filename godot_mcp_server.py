#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Layer 3: Godot 4 Model Context Protocol (MCP) Server
Implements Anthropic Model Context Protocol (MCP) JSON-RPC 2.0 interface
for direct black-box game testing, UI tree inspection, and virtual input injection.
"""

import sys
import json
import socket
import time
import os
import subprocess

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

GAME_DIR = os.path.join(BASE_DIR, "zcode项目")
GODOT_EXE = os.path.join(BASE_DIR, ".tools", "godot_extracted", "Godot_v4.7.2-stable_win64_console.exe")
TCP_HOST = "127.0.0.1"
TCP_PORT = 9099

MCP_TOOLS = [
    {
        "name": "godot_dump_ui_tree",
        "description": "Dump the current live Godot UI tree, listing all visible Controls, Buttons, Labels, screen bounding boxes, and text.",
        "inputSchema": {
            "type": "object",
            "properties": {}
        }
    },
    {
        "name": "godot_query_node",
        "description": "Query specific details and bounding box of a node by node path or text substring.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Text substring on button/label or node path to search"
                }
            },
            "required": ["query"]
        }
    },
    {
        "name": "godot_click_node",
        "description": "Click a visible UI element by its text or node name (auto-calculates center and sends physical mouse click).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "name_or_text": {
                    "type": "string",
                    "description": "Text on the button (e.g. '军机祈赏', '跳过剧情', '进军出征') or node name"
                }
            },
            "required": ["name_or_text"]
        }
    },
    {
        "name": "godot_click_coordinate",
        "description": "Send a physical mouse left-click event at screen coordinates (x, y).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "x": {"type": "number", "description": "X coordinate in pixels"},
                "y": {"type": "number", "description": "Y coordinate in pixels"}
            },
            "required": ["x", "y"]
        }
    },
    {
        "name": "godot_capture_screenshot",
        "description": "Capture a live high-resolution screenshot from the running Godot game viewport.",
        "inputSchema": {
            "type": "object",
            "properties": {}
        }
    },
    {
        "name": "godot_press_key",
        "description": "Simulate a keyboard key press (space, enter, escape).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "key": {"type": "string", "description": "Key name, e.g. space, enter, escape"}
            },
            "required": ["key"]
        }
    },
    {
        "name": "godot_wait",
        "description": "Wait for animations, dialogue, or turn transitions to complete and take updated screenshot.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "seconds": {"type": "number", "description": "Seconds to wait (default 1.0)"}
            }
        }
    }
]

def is_godot_running():
    out = subprocess.run(["powershell", "-Command", "Get-Process -Name Godot* -ErrorAction SilentlyContinue"], capture_output=True, text=True)
    return "Godot" in out.stdout

def rpc_call(method: str, params: dict = None, timeout: float = 10.0) -> dict:
    if params is None:
        params = {}
        
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(timeout)
    try:
        s.connect((TCP_HOST, TCP_PORT))
    except Exception as e:
        return {"status": "error", "message": f"Cannot connect to Godot MCP Bridge on {TCP_HOST}:{TCP_PORT} ({e}). Ensure Godot is running."}
        
    req = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,
        "params": params
    }
    raw = (json.dumps(req, ensure_ascii=False) + "\n").encode("utf-8")
    s.sendall(raw)
    
    # Read response line
    buffer = b""
    start_time = time.time()
    while time.time() - start_time < timeout:
        chunk = s.recv(4096)
        if not chunk:
            break
        buffer += chunk
        if b"\n" in buffer:
            break
            
    s.close()
    try:
        resp = json.loads(buffer.decode("utf-8").strip())
        return resp.get("result", resp)
    except Exception as e:
        return {"status": "error", "message": f"Failed to parse JSON response: {buffer.decode('utf-8', errors='ignore')}"}

# Standard Model Context Protocol (MCP) Stdio Loop
def run_mcp_stdio_server():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except Exception:
            continue
            
        method = req.get("method")
        msg_id = req.get("id")
        
        if method == "initialize":
            resp = {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {
                        "tools": {}
                    },
                    "serverInfo": {
                        "name": "godot-srpg-mcp-server",
                        "version": "1.0.0"
                    }
                }
            }
            sys.stdout.write(json.dumps(resp, ensure_ascii=False) + "\n")
            sys.stdout.flush()
            
        elif method == "notifications/initialized":
            # Client acknowledge
            pass
            
        elif method == "tools/list":
            resp = {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "tools": MCP_TOOLS
                }
            }
            sys.stdout.write(json.dumps(resp, ensure_ascii=False) + "\n")
            sys.stdout.flush()
            
        elif method == "tools/call":
            params = req.get("params", {})
            tool_name = params.get("name")
            args = params.get("arguments", {})
            
            result_data = {}
            if tool_name == "godot_dump_ui_tree":
                result_data = rpc_call("dump_ui_tree", args)
            elif tool_name == "godot_query_node":
                result_data = rpc_call("query_node_coord", args)
            elif tool_name == "godot_click_node":
                result_data = rpc_call("click_node", args)
            elif tool_name == "godot_click_coordinate":
                result_data = rpc_call("click_coord", args)
            elif tool_name == "godot_capture_screenshot":
                result_data = rpc_call("capture_screenshot", args)
            elif tool_name == "godot_press_key":
                result_data = rpc_call("press_key", args)
            elif tool_name == "godot_wait":
                result_data = rpc_call("wait", args)
            else:
                result_data = {"error": f"Unknown tool: {tool_name}"}
                
            resp = {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "content": [
                        {
                            "type": "text",
                            "text": json.dumps(result_data, ensure_ascii=False, indent=2)
                        }
                    ]
                }
            }
            sys.stdout.write(json.dumps(resp, ensure_ascii=False) + "\n")
            sys.stdout.flush()
            
        elif method == "ping":
            resp = {"jsonrpc": "2.0", "id": msg_id, "result": {}}
            sys.stdout.write(json.dumps(resp, ensure_ascii=False) + "\n")
            sys.stdout.flush()

# Direct CLI mode for terminal testing
def run_cli():
    if len(sys.argv) < 2:
        print("Model Context Protocol (MCP) Godot Server")
        print("Usage:")
        print("  python godot_mcp_server.py stdio                        (Start standard MCP JSON-RPC server)")
        print("  python godot_mcp_server.py dump                         (Dump live Godot UI tree)")
        print("  python godot_mcp_server.py query <text>                 (Query node coordinates by text)")
        print("  python godot_mcp_server.py click_node <text>            (Click button by text directly)")
        print("  python godot_mcp_server.py click <x> <y>                (Click pixel coordinates)")
        print("  python godot_mcp_server.py screenshot                   (Capture screen)")
        return
        
    cmd = sys.argv[1].lower()
    if cmd == "stdio":
        run_mcp_stdio_server()
    elif cmd in ["dump", "tree"]:
        res = rpc_call("dump_ui_tree")
        print(json.dumps(res, ensure_ascii=False, indent=2))
    elif cmd == "query":
        q = sys.argv[2] if len(sys.argv) > 2 else ""
        res = rpc_call("query_node_coord", {"query": q})
        print(json.dumps(res, ensure_ascii=False, indent=2))
    elif cmd == "click_node":
        q = sys.argv[2] if len(sys.argv) > 2 else ""
        res = rpc_call("click_node", {"name_or_text": q})
        print(json.dumps(res, ensure_ascii=False, indent=2))
    elif cmd == "click":
        x = float(sys.argv[2])
        y = float(sys.argv[3])
        res = rpc_call("click_coord", {"x": x, "y": y})
        print(json.dumps(res, ensure_ascii=False, indent=2))
    elif cmd == "screenshot":
        res = rpc_call("capture_screenshot")
        print(json.dumps(res, ensure_ascii=False, indent=2))
    else:
        print(f"Unknown CLI command: {cmd}")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "stdio":
        run_mcp_stdio_server()
    else:
        run_cli()
