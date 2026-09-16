extends SceneTree
## 可视化实机演示驱动器（慢速播放，供用户亲眼观看 AI 像真人一样玩游戏）
## 运行后在桌面显示窗口，每步停顿 1.2 秒，并在完成全部演示后常驻不退，供用户即刻接手游玩！

const SaveCore := preload("res://scripts/systems/save.gd")

func _initialize() -> void:
	print("\n==================================================")
	print("🎬 [实机可视化演示] 启动慢速真人操作模拟回放")
	print("==================================================")
	
	root.size = Vector2i(1280, 720)
	
	var save: Dictionary = SaveCore.load_state()
	var chs: Array = save.get("chapters", [])
	if not "chapter1" in chs:
		chs.append("chapter1")
		save["chapters"] = chs
	save["prestige"] = maxi(int(save.get("prestige", 0)), 8888)
	SaveCore.save_state(save)

	_run_demo()

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func click_at(pos: Vector2, is_right: bool = false, delay_after: float = 1.0) -> void:
	var btn := MOUSE_BUTTON_RIGHT if is_right else MOUSE_BUTTON_LEFT
	var ev_motion := InputEventMouseMotion.new()
	ev_motion.position = pos
	ev_motion.global_position = pos
	Input.parse_input_event(ev_motion)
	await process_frame
	
	var ev_down := InputEventMouseButton.new()
	ev_down.button_index = btn
	ev_down.pressed = true
	ev_down.position = pos
	ev_down.global_position = pos
	Input.parse_input_event(ev_down)
	await process_frame
	
	var ev_up := InputEventMouseButton.new()
	ev_up.button_index = btn
	ev_up.pressed = false
	ev_up.position = pos
	ev_up.global_position = pos
	Input.parse_input_event(ev_up)
	await process_frame
	
	await _wait(delay_after)

func click_node(ctrl: Control, delay_after: float = 1.0) -> void:
	var center := ctrl.get_global_rect().get_center()
	await click_at(center, false, delay_after)

func find_btn(node: Node, text_substr: String) -> Button:
	if node is Button and text_substr in node.text:
		return node
	for c in node.get_children():
		var found = find_btn(c, text_substr)
		if found:
			return found
	return null

func _run_demo() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(1.5)

	# 1. 演示进入抽奖
	var btn_lottery = find_btn(root, "军机祈赏")
	if btn_lottery:
		print("👉 [AI操作演示 1/6] 物理鼠标点击【🎲 军机祈赏 (声望抽奖)】...")
		await click_node(btn_lottery, 1.2)

	# 2. 演示抽奖并返回
	var btn_seed = find_btn(root, "祈得仙种")
	if btn_seed:
		print("👉 [AI操作演示 2/6] 物理鼠标点击【神农仙种抽取】获得战利品...")
		await click_node(btn_seed, 1.5)
	
	var btn_back = find_btn(root, "返回主菜单")
	if btn_back:
		print("👉 [AI操作演示 3/6] 物理鼠标点击【🔙 返回主菜单】...")
		await click_node(btn_back, 1.2)

	# 3. 演示进军出征第一关
	var btn_enter = find_btn(root, "手动重战")
	if btn_enter == null:
		btn_enter = find_btn(root, "进 军 出 征")
	if btn_enter:
		print("👉 [AI操作演示 4/6] 物理鼠标点击【出征/重战】进军第一关·汜水关...")
		await click_node(btn_enter, 1.5)

	var battle = current_scene
	# 4. 演示快速点击空白处翻阅对白，随后跳过剧情
	print("👉 [AI操作演示 5/6] 物理鼠标点击屏幕空白区推进对白...")
	await click_at(Vector2(500, 300), false, 0.8)
	await click_at(Vector2(500, 300), false, 0.8)
	
	var skip_btn = battle.dialog_skip_btn
	if skip_btn:
		print("👉 [AI操作演示 5/6] 物理鼠标点击【跳过剧情 ⏩】开打！...")
		await click_node(skip_btn, 1.2)

	# 5. 演示真实选中关羽、直点绿色格子走位千里蓄力
	var guanyu_px = battle._cell_to_px(Vector2i(2, 5))
	print("👉 [AI操作演示 6/6] 物理鼠标点击关羽坐标 (2, 5) 选中将牌...")
	await click_at(guanyu_px, false, 1.2)

	var target_px = battle._cell_to_px(Vector2i(4, 5))
	print("👉 [AI操作演示 6/6] 物理鼠标直接点击绿色可达格 (4, 5) 进行千里蓄力行军！...")
	await click_at(target_px, false, 1.5)

	print("\n==================================================")
	print("🎉 [AI操作演示完毕！] 游戏窗口已常驻在您的屏幕上，请您直接上手体验！")
	print("==================================================")
	# 此处绝不调用 quit()！窗口将永久保留在用户屏幕上，用户可自由操作！
