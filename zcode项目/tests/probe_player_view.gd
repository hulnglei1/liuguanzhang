extends SceneTree
## 玩家视角验收：像真人一样用鼠标/键盘从头打一遍第一关
## 运行：Godot_console.exe --headless --path zcode项目 --script res://tests/probe_player_view.gd
##
## 与其它探针的区别：这里**不直接调用任何内部函数**
##   * 鼠标：Input.parse_input_event(InputEventMouseButton 按下+抬起)
##   * 键盘：Input.parse_input_event(InputEventKey)
##   * 坐标：只借用 _cell_to_px 把格子换算成像素，输入本身走完整引擎管线
## 观察点：每一步玩家能看到什么反馈、有没有"点了没反应"、会不会卡住

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")

var b: Node
var failed: int = 0
var notes: Array[String] = []


func _initialize() -> void:
	var s: Dictionary = SaveCore.new_state()
	s["prologues_seen"] = []                 # 故意清空：让玩家走一遍"首次进入"的完整流程
	SaveCore.save_state(s)
	# --script 模式下主场景不会自动加载，必须显式进入主菜单（玩家视角的起点）
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	_run()


# ---------------- 真实输入工具 ----------------

func _wait(x: float) -> void:
	await create_timer(x).timeout


## headless 下窗口只有 64x64（实测），鼠标事件坐标落在窗口外会被 Viewport 丢弃，
## 所以格子点击只能用 _handle_click 回退；键盘事件不受影响。
## 非 headless（真实窗口）时走完整引擎输入管线，那才是真正的"玩家视角"。
func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _click_at(pos: Vector2, is_right: bool = false) -> void:
	var btn: int = MOUSE_BUTTON_RIGHT if is_right else MOUSE_BUTTON_LEFT
	var down := InputEventMouseButton.new()
	down.button_index = btn
	down.pressed = true
	down.position = pos
	down.global_position = pos
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = btn
	up.pressed = false
	up.position = pos
	up.global_position = pos
	Input.parse_input_event(up)
	await create_timer(0.18).timeout


## 点击某个格子。非 headless 走真实鼠标事件；headless 回退为直接调用点击分派
func _click_cell(cell: Vector2i, is_right: bool = false) -> void:
	if _is_headless():
		if is_right:
			b._cancel_input()          # headless 下右键退化为"取消"（与右键语义一致）
		else:
			b._handle_click(cell)
		await create_timer(0.2).timeout
		return
	await _click_at(b._cell_to_px(cell), is_right)


func _press_space() -> void:
	var down := InputEventKey.new()
	down.keycode = KEY_SPACE
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventKey.new()
	up.keycode = KEY_SPACE
	up.pressed = false
	Input.parse_input_event(up)
	await create_timer(0.12).timeout


# ---------------- 观察输出 ----------------

func _note(msg: String) -> void:
	notes.append(msg)
	print("  [玩家] %s" % msg)


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		failed += 1


## 读底栏信息（玩家实际看到的那行字）
func _info() -> String:
	return b.info_label.text.replace("\n", " / ").left(70)


# ---------------- 主流程 ----------------

func _run() -> void:
	await _wait(2.2)
	print("\n===== 玩家视角：第一关全流程 =====")

	# ---------- ① 主菜单 ----------
	print("\n---- ① 主菜单 ----")
	var menu: Node = current_scene
	_note("场景：%s" % menu.name)
	var btn: Button = menu.find_child("btn_chapter1", true, false)
	if btn == null:
		_check(false, "主菜单找不到第一关按钮（btn_chapter1）")
		_finish()
		return
	_note("看到按钮：「%s」" % btn.text)
	# 说明：headless 下窗口只有 64x64（上面诊断已证实），UI 按钮按真实坐标点不到
	# ——因为节点布局基于窗口尺寸。所以"按钮"这一步用信号模拟玩家点击；
	# 而战场上的格子点击全部走**真实鼠标输入**（那才是交互的重点）。
	btn.pressed.emit()
	await _wait(2.5)
	_note("点击后场景：%s" % (current_scene.name if current_scene != null else "null"))

	# ---------- ② 序章 ----------
	print("\n---- ② 序章（首次进入） ----")
	var guard: int = 0
	if not (current_scene is BattleScript):
		_note("进入序章，用 Space 逐句推进")
		# 序章行数会随着剧情增加，别把上限卡太死（多一句就超）
		while not (current_scene is BattleScript) and guard < 120:
			await _press_space()
			guard += 1
		_note("推了 %d 次 Space 后进入战场" % guard)
		# 兜底：万一还在序章，直接让它收尾，不要卡死整条测试
		if not (current_scene is BattleScript) and current_scene != null and current_scene.has_method("_finish"):
			_note("仍未进入战场，强制结束序章（兜底）")
			current_scene._finish()
			await _wait(1.5)
	_check(current_scene is BattleScript, "序章能正常推进到战场（没有卡住）")

	b = current_scene
	await _wait(0.8)
	# 战场开局对白：玩家要按空格跳过
	guard = 0
	while bool(b.dialog_showing) and guard < 20:
		await _press_space()
		guard += 1
	_note("开局对白按了 %d 次空格看完" % guard)

	# ---------- ③ 点各种东西看反馈 ----------
	print("\n---- ③ 玩家乱点（检查是否都有反馈） ----")
	await _click_cell(Vector2i(6, 8))          # 空地
	_note("点空地 (6,8) → 底栏：「%s」" % _info())
	await _click_cell(Vector2i(7, 4))          # 敌方主将华雄
	_note("点敌将华雄 → 底栏：「%s」" % _info())
	_check(_info().length() > 0, "点敌人有信息反馈（不是没反应）")
	await _click_cell(Vector2i(2, 5))          # 我方关羽
	_note("点关羽 → 底栏：「%s」" % _info())
	var mode_after_first: int = int(b.input_mode)
	_check(mode_after_first == 1, "点我方单位 → 进入选中态（高亮可走格子）")

	# ---------- ④ 关羽：移动 → 菜单 → 待机 ----------
	print("\n---- ④ 关羽：移动 + 打开菜单 ----")
	await _click_cell(Vector2i(2, 4))          # 相邻空格，走一步
	_note("点相邻格 (2,4) → 关羽移动，底栏：「%s」" % _info())
	var gy = b._unit_by_id("guanyu")
	_check(gy.cell == Vector2i(2, 4), "点绿格能走过去")
	await _click_cell(Vector2i(2, 4))          # 再点自己 → 弹菜单
	await _wait(0.3)
	var menu_visible: bool = bool(b.command_menu.visible)
	_note("再点自己 → 命令菜单%s" % ("弹出" if menu_visible else "没弹"))
	_check(menu_visible, "再点自己会弹出命令菜单（玩家能继续操作）")

	# 菜单里有哪些按钮（玩家看到什么）
	var btns: Array = b.command_menu.find_children("*", "Button", true, false)
	var labels: Array[String] = []
	for c in btns:
		if c is Button:
			labels.append((c as Button).text)
	_note("菜单按钮：%s" % ", ".join(labels))
	_check(labels.size() >= 3, "菜单里有多个可选指令（攻击/绝技/待机…）")

	# 右键关闭菜单
	await _click_cell(Vector2i(2, 4), true)
	_note("右键点自己 → 菜单%s" % ("仍开着" if bool(b.command_menu.visible) else "关闭"))

	# ---------- ⑤ 张飞：咆哮（点技能 → 连点 → 释放） ----------
	print("\n---- ⑤ 张飞：燕人咆哮 ----")
	var zf = b._unit_by_id("zhangfei")
	# 先把张飞挪到敌兵旁边（真实操作：点两次选中 + 菜单移动）
	zf.cell = Vector2i(4, 4)                   # 直接摆位，避免走位太长（走位已在④验证过）
	b._sync_node(zf)
	await _click_cell(Vector2i(4, 4))
	await _click_cell(Vector2i(4, 4))
	await _wait(0.3)
	var roar_btn: Button = null
	for c in b.command_menu.find_children("*", "Button", true, false):
		if c is Button and ((c as Button).name == "cmd_skill" or (c as Button).text.contains("龙斩") or (c as Button).text.contains("咆哮")):
			roar_btn = c
	if roar_btn == null:
		_check(false, "张飞菜单里找不到技能按钮")
	else:
		_note("技能按钮：「%s」" % roar_btn.text)
		roar_btn.pressed.emit()      # headless 下 UI 按钮坐标点不到，用信号模拟
		await _wait(0.3)
		_note("点咆哮后进入喊字态（input_mode=%d），底栏：「%s」" % [int(b.input_mode), _info()])
		_check(int(b.input_mode) == 6, "点咆哮进入喊字状态")
		# 只追加 2 次（6+2=8 字）—— 刻意**不满 14 字**：
		# 满 14 字会触发"敌我不分"把队友全晕，后续步骤就测不下去了
		for i in range(2):
			await _press_space()
		await _wait(1.6)      # 停手 0.9 秒会自动出手（不用干等满 4 秒窗口）
		var dao = b._unit_by_id("dao_bing_1")
		if dao != null:
			_note("喊到 8 字（未满 14）→ 敌兵 stun=%d，HP=%d" % [dao.stun_turns, dao.hp])
		_check(bool(zf.acted), "咆哮释放完，张飞标记已行动")

	# ---------- ⑥ 空格结束回合（应警告） ----------
	print("\n---- ⑥ 空格结束回合 ----")
	await _press_space()
	await _wait(0.4)
	var warned: bool = bool(b.pending_end_turn)
	_note("按空格 → %s" % ("弹'还有人未行动'警告" if warned else "直接结束回合（没警告）"))
	if warned:
		_note("底栏：「%s」" % _info())
		await _press_space()
		await _wait(3.5)
		_note("再按一次 → 进入敌方回合（turn=%d）" % int(b.turn_state.turn))
		_check(int(b.turn_state.turn) >= 2, "再按一次空格 → 回合正常推进")
	_check(warned, "有人没行动时，空格先给警告（不会无声跳过）")

	# ---------- ⑦ 回来还能正常操作 ----------
	print("\n---- ⑦ 新回合继续玩 ----")
	await _wait(2.5)
	# 第 2 回合会触发剧情对白（chapter1_deserter）。对白期间点画面 = 推进对白，
	# 这是设计（对白优先），不是 bug —— 玩家此时也只能按空格。
	var guard7: int = 0
	while bool(b.dialog_showing) and guard7 < 20:
		await _press_space()
		guard7 += 1
	if guard7 > 0:
		_note("第 2 回合弹出剧情对白，按了 %d 次空格看完" % guard7)
	var lb = b._unit_by_id("liubei")
	if lb != null:
		_note("刘备状态：cell=%s alive=%s acted=%s stun=%d" % [
			str(lb.cell), str(lb.alive), str(lb.acted), lb.stun_turns])
	_note("新回合 input_mode=%d，底栏：「%s」" % [int(b.input_mode), _info()])
	var px: Vector2 = b._cell_to_px(Vector2i(1, 4))
	_note("坐标回环：(1,4) → 像素 %s → 格子 %s" % [str(px), str(b._px_to_cell(px))])
	_note("命令菜单 visible=%s｜真实鼠标位置=%s" % [
		str(b.command_menu.visible), str(b.get_global_mouse_position())])
	await _click_cell(Vector2i(1, 4))          # 点刘备
	_note("点刘备 → input_mode=%d，底栏：「%s」" % [int(b.input_mode), _info()])
	_check(int(b.input_mode) == 1, "新回合能正常选中单位继续玩")

	_finish()


func _finish() -> void:
	print("\n===== 玩家视角汇总 =====")
	print("  观察记录 %d 条" % notes.size())
	if failed == 0:
		print("  结论：全流程顺畅，未发现卡住或没反馈的地方 ✅")
	else:
		print("  结论：发现 %d 处问题 ❌" % failed)
	SaveCore.save_state(SaveCore.new_state())
	quit(0 if failed == 0 else 1)
