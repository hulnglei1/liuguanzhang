# agent_bridge.gd
# Layer 3: Model Context Protocol (MCP) & JSON-RPC 2.0 Bridge for Godot 4
# Exposes TCP JSON-RPC on 127.0.0.1:9099 and file IPC fallback.

extends Node

const TCP_PORT := 9099
const CMD_PATH := "res://agent_cmd.json"
const RESP_PATH := "res://agent_resp.json"
const SCREENSHOT_PATH := "res://screenshots/agent_view.png"

var tcp_server: TCPServer
var clients: Array[StreamPeerTCP] = []
var is_busy := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_tcp_server()
	print("[MCP-Bridge] 🌟 Godot 4 Layer-3 MCP/JSON-RPC 桥接服务启动 (127.0.0.1:%d)" % TCP_PORT)

func _init_tcp_server() -> void:
	tcp_server = TCPServer.new()
	var err = tcp_server.listen(TCP_PORT, "127.0.0.1")
	if err == OK:
		print("[MCP-Bridge] ✅ TCP 监听成功: 127.0.0.1:%d" % TCP_PORT)
	else:
		print("[MCP-Bridge] ⚠️ TCP 监听失败 (错误码 %d)，使用文件 IPC 模式" % err)

func _process(_delta: float) -> void:
	# Accept new TCP client connections
	if tcp_server and tcp_server.is_connection_available():
		var peer = tcp_server.take_connection()
		if peer:
			clients.append(peer)
			print("[MCP-Bridge] 🔌 新客户端已接入 TCP/JSON-RPC 端口")

	# Poll active TCP clients
	for i in range(clients.size() - 1, -1, -1):
		var client = clients[i]
		client.poll()
		var status = client.get_status()
		if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
			clients.remove_at(i)
			continue
			
		var bytes_avail = client.get_available_bytes()
		if bytes_avail > 0 and not is_busy:
			var msg = client.get_utf8_string(bytes_avail)
			_handle_tcp_message(client, msg)

	# Also check file IPC fallback
	if not is_busy and FileAccess.file_exists(CMD_PATH):
		_handle_file_command()

func _handle_tcp_message(client: StreamPeerTCP, raw_msg: String) -> void:
	is_busy = true
	var lines = raw_msg.split("\n", false)
	for line in lines:
		var trimmed = line.strip_edges()
		if trimmed.is_empty():
			continue
		var json = JSON.new()
		if json.parse(trimmed) != OK or typeof(json.data) != TYPE_DICTIONARY:
			var err_resp = {"jsonrpc": "2.0", "id": null, "error": {"code": -32700, "message": "Parse error"}}
			_send_tcp_json(client, err_resp)
			continue
			
		var req: Dictionary = json.data
		var req_id = req.get("id", 1)
		var method = req.get("method", "")
		var params = req.get("params", {})
		
		var result = await _execute_mcp_method(method, params)
		var resp = {
			"jsonrpc": "2.0",
			"id": req_id,
			"result": result
		}
		_send_tcp_json(client, resp)
	is_busy = false

func _send_tcp_json(client: StreamPeerTCP, data: Dictionary) -> void:
	var s = JSON.stringify(data) + "\n"
	client.put_data(s.to_utf8_buffer())

func _execute_mcp_method(method: String, params: Dictionary) -> Dictionary:
	print("[MCP-Bridge] ⚙️ 执行 RPC 方法: %s, 参数: %s" % [method, str(params)])
	match method:
		"dump_ui_tree":
			return _build_ui_tree()
			
		"query_node_coord":
			var q: String = params.get("query", "")
			return _query_node(q, str(params.get("class_filter", "")), str(params.get("path_filter", "")))
			
		"click_coord":
			var x = float(params.get("x", 0))
			var y = float(params.get("y", 0))
			var btn: int = int(params.get("button", MOUSE_BUTTON_LEFT))
			await _simulate_click(Vector2(x, y), btn)
			await _capture_screenshot()
			return {
				"status": "ok",
				"clicked_at": [x, y],
				"button": btn,
				"screenshot": ProjectSettings.globalize_path(SCREENSHOT_PATH)
			}
			
		"click_node":
			var q: String = params.get("name_or_text", "")
			var query_res = _query_node(q)
			if query_res.get("found", false):
				var center = query_res.get("center", [0, 0])
				await _simulate_click(Vector2(center[0], center[1]))
				await _capture_screenshot()
				return {
					"status": "ok",
					"matched_node": query_res.get("path"),
					"clicked_at": center,
					"screenshot": ProjectSettings.globalize_path(SCREENSHOT_PATH)
				}
			else:
				return {"status": "error", "message": "Node not found matching: " + q}
				
		"capture_screenshot":
			await _capture_screenshot()
			return {
				"status": "ok",
				"screenshot": ProjectSettings.globalize_path(SCREENSHOT_PATH),
				"viewport_size": [get_viewport().size.x, get_viewport().size.y]
			}
			
		"press_key":
			var key_str = str(params.get("key", "space")).to_lower()
			await _simulate_key(key_str)
			await _capture_screenshot()
			return {
				"status": "ok",
				"key": key_str,
				"screenshot": ProjectSettings.globalize_path(SCREENSHOT_PATH)
			}
			
		"wait":
			var secs = float(params.get("seconds", 1.0))
			await get_tree().create_timer(secs).timeout
			await _capture_screenshot()
			return {
				"status": "ok",
				"waited_seconds": secs,
				"screenshot": ProjectSettings.globalize_path(SCREENSHOT_PATH)
			}

		"get_battle_state":
			# 有头模式下驱动"真实玩家操作"所需的最小状态（只读，不改任何战斗状态）
			return _build_battle_state()

		"get_audio_state":
			# 音频自检：当前曲目、总线音量、播放器是否真的在走
			return _build_audio_state()

		_:
			return {"status": "error", "message": "Unknown RPC method: " + method}


## 音频只读快照：用来验证"音乐真的在放"，而不是加载了空文件
func _build_audio_state() -> Dictionary:
	var ad: Node = get_node_or_null("/root/AudioDirector")
	var out: Dictionary = {"status": "ok"}
	if ad == null:
		out["status"] = "error"
		out["message"] = "AudioDirector 未加载"
		return out

	var buses: Dictionary = {}
	for name in ["Master", "BGM", "SFX"]:
		var idx: int = AudioServer.get_bus_index(name)
		if idx < 0:
			buses[name] = {"exists": false}
		else:
			buses[name] = {
				"exists": true,
				"db": AudioServer.get_bus_volume_db(idx),
				"mute": AudioServer.is_bus_mute(idx),
			}

	var playing: Array = []
	for p in ad._players:
		playing.append({
			"playing": bool(p.playing),
			"db": float(p.volume_db),
			"pos": float(p.get_playback_position()),
			"len": float(p.stream.get_length()) if p.stream != null else 0.0,
		})

	out["track"] = str(ad._current_track)
	out["buses"] = buses
	out["players"] = playing
	out["sfx"] = {
		"master": float(ad.settings.get("master", 0)),
		"bgm": float(ad.settings.get("bgm", 0)),
		"sfx": float(ad.settings.get("sfx", 0)),
		"fullscreen": bool(ad.settings.get("fullscreen", false)),
	}
	return out


## 组装战斗状态的只读快照。
## 只暴露"玩家眼睛能看到的 + 决定该点哪里所必需的"信息：
## 单位在哪一格/哪个像素、谁能动、蓄力多少、被晕几回合、军令在第几阶段。
func _build_battle_state() -> Dictionary:
	var scene: Node = get_tree().current_scene
	var out: Dictionary = {
		"status": "ok",
		"scene": str(scene.name) if scene != null else "",
		"viewport": [get_viewport().size.x, get_viewport().size.y],
	}
	if scene == null or not ("units" in scene):
		return out      # 不在战斗场景（主菜单/序章），只回场景名

	out["tile"] = float(scene.TILE)
	out["map"] = [int(scene.MAP_W), int(scene.MAP_H)]
	out["grid_offset"] = [float(scene.MAP_OFFSET.x), float(scene.MAP_OFFSET.y)]
	out["chapter_id"] = str(scene.chapter_id)
	out["turn"] = int(scene.turn_state.turn)
	out["stage_idx"] = int(scene.stage_idx)
	out["stage_count"] = int(scene.stages.size())
	out["gate_broken"] = bool(scene.gate_broken)
	out["victory"] = bool(scene.victory)
	out["defeat"] = bool(scene.defeat)
	out["dialog_showing"] = bool(scene.dialog_showing)
	out["input_mode"] = int(scene.input_mode)
	out["selected_id"] = str(scene.selected_id)

	var us: Array = []
	for u in scene.units:
		if not bool(u.alive):
			continue
		us.append({
			"id": str(u.id),
			"name": str(u.name),
			"camp": str(u.camp),
			"cell": [int(u.cell.x), int(u.cell.y)],
			"hp": int(u.hp),
			"max_hp": int(u.max_hp),
			"acted": bool(u.acted),
			"moved": bool(u.moved_this_turn),
			"charge": int(u.charge),
			"stun": int(u.stun_turns),
			"rng": int(u.rng),
			"cavalry": bool(u.is_cavalry()),
			"commander": bool(u.is_commander),
			"skills": u.skill_ids.duplicate(),
		})
	out["units"] = us

	# 敌军下一步会扑谁（复现玩家看到的面板提示）
	var gates: Array = []
	if scene.chapter.has("map"):
		for o in scene.chapter["map"].get("obstacles", []):
			if bool(o.get("is_gate", false)):
				gates.append([int(o.get("x", -1)), int(o.get("y", -1))])
	out["gates"] = gates
	return out

func _simulate_click(pos: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	var ev_m = InputEventMouseMotion.new()
	ev_m.position = pos
	ev_m.global_position = pos
	Input.parse_input_event(ev_m)
	await get_tree().process_frame
	
	var ev_down = InputEventMouseButton.new()
	ev_down.position = pos
	ev_down.global_position = pos
	ev_down.button_index = button
	ev_down.pressed = true
	Input.parse_input_event(ev_down)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var ev_up = InputEventMouseButton.new()
	ev_up.position = pos
	ev_up.global_position = pos
	ev_up.button_index = button
	ev_up.pressed = false
	Input.parse_input_event(ev_up)
	
	for i in range(8):
		await get_tree().process_frame

func _simulate_key(key_str: String) -> void:
	var keycode = KEY_SPACE
	if key_str == "space": keycode = KEY_SPACE
	elif key_str == "enter": keycode = KEY_ENTER
	elif key_str == "escape": keycode = KEY_ESCAPE
	
	var ev_down = InputEventKey.new()
	ev_down.keycode = keycode
	ev_down.pressed = true
	Input.parse_input_event(ev_down)
	await get_tree().process_frame
	
	var ev_up = InputEventKey.new()
	ev_up.keycode = keycode
	ev_up.pressed = false
	Input.parse_input_event(ev_up)
	for i in range(8):
		await get_tree().process_frame

func _capture_screenshot() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var vp = get_viewport()
	if vp:
		var tex = vp.get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				var abs_path = ProjectSettings.globalize_path(SCREENSHOT_PATH)
				img.save_png(abs_path)

func _build_ui_tree() -> Dictionary:
	var list: Array = []
	_dump_node_recursive(get_tree().root, list)
	return {
		"total_nodes": list.size(),
		"elements": list,
		"screenshot": ProjectSettings.globalize_path(SCREENSHOT_PATH)
	}

func _dump_node_recursive(node: Node, out: Array) -> void:
	if not node:
		return
	if node is CanvasItem and not node.is_visible_in_tree():
		return
		
	var item := {
		"path": str(node.get_path()),
		"name": node.name,
		"class": node.get_class()
	}
	
	if node is Control:
		var rect = node.get_global_rect()
		item["rect"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		item["center"] = [rect.position.x + rect.size.x / 2.0, rect.position.y + rect.size.y / 2.0]
		item["mouse_filter"] = node.mouse_filter
		
		if node is Button:
			item["text"] = node.text
			item["disabled"] = node.disabled
			out.append(item)
		elif node is Label and not node.text.is_empty():
			item["text"] = node.text
			out.append(item)
		elif node is ProgressBar:
			item["value"] = node.value
			item["max_value"] = node.max_value
			out.append(item)
		elif node is HSlider:
			item["value"] = node.value
			item["min_value"] = node.min_value
			item["max_value"] = node.max_value
			out.append(item)
			
	for child in node.get_children():
		_dump_node_recursive(child, out)

## 按文本/路径/名字查找节点。
## class_filter / path_filter 是可选的收紧条件 —— 仪表盘上的说明文字里也含"待机""✨"，
## 不加过滤会点到说明文字而不是按钮（自动化踩过这个坑）。
func _query_node(q: String, class_filter: String = "", path_filter: String = "") -> Dictionary:
	var list: Array = []
	_dump_node_recursive(get_tree().root, list)
	var q_clean = q.replace(" ", "").to_lower()
	for item in list:
		if not class_filter.is_empty() and str(item.get("class", "")) != class_filter:
			continue
		if not path_filter.is_empty() and not (path_filter in str(item.get("path", ""))):
			continue
		var text: String = item.get("text", "")
		var path: String = item.get("path", "")
		var name: String = item.get("name", "")
		var text_clean = text.replace(" ", "").to_lower()
		var path_clean = path.to_lower()
		var name_clean = name.to_lower()
		if q in text or q in path or q == name or (not q_clean.is_empty() and q_clean in text_clean):
			return {
				"found": true,
				"path": path,
				"name": name,
				"text": text,
				"class": item.get("class"),
				"rect": item.get("rect"),
				"center": item.get("center"),
				"disabled": item.get("disabled", false)
			}
	return {"found": false, "query": q, "class_filter": class_filter}

# File IPC Fallback
func _handle_file_command() -> void:
	var f = FileAccess.open(CMD_PATH, FileAccess.READ)
	if not f: return
	var content = f.get_as_text()
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CMD_PATH))
	
	var json = JSON.new()
	if json.parse(content) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return
	var cmd: Dictionary = json.data
	var action = cmd.get("action", "")
	var method = "capture_screenshot"
	var params = {}
	
	if action == "screenshot" or action == "view":
		method = "capture_screenshot"
	elif action == "click":
		method = "click_coord"
		params = {"x": cmd.get("x", 0), "y": cmd.get("y", 0)}
	elif action == "key":
		method = "press_key"
		params = {"key": cmd.get("key", "space")}
	elif action == "wait":
		method = "wait"
		params = {"seconds": cmd.get("seconds", 1.0)}
		
	is_busy = true
	var result = await _execute_mcp_method(method, params)
	var ui = _build_ui_tree()
	result["elements"] = ui.get("elements", [])
	var abs_path = ProjectSettings.globalize_path(RESP_PATH)
	var fw = FileAccess.open(abs_path, FileAccess.WRITE)
	if fw:
		fw.store_string(JSON.stringify(result, "  "))
		fw.close()
	is_busy = false
