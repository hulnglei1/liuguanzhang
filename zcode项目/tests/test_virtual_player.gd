extends SceneTree
## 全量虚拟玩家真机驱动测试 (Virtual Player Full-Loop Driver Test)
## 彻底告别逻辑白盒假通过：全流程 100% 模拟真实玩家物理鼠标移动、点击、键盘输入！
## 运行方式：.\godot_bin\Godot_v4.3-stable_win64_console.exe --path game -s tests/test_virtual_player.gd

const SaveCore := preload("res://scripts/systems/save.gd")
const BattleScript := preload("res://scripts/battle.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")

var total_asserts: int = 0
var passed_asserts: int = 0
var failed_asserts: int = 0

func _initialize() -> void:
	print("\n==================================================")
	print("🎮 [虚拟玩家全量测试] 启动全引擎真机输入测试套件")
	print("==================================================")
	
	# 确保视口标准 1280x720
	root.size = Vector2i(1280, 720)
	
	# 初始化测试存档：赋予充足声望与第1关通关标记（以支持抽奖与扫荡测试）
	var save: Dictionary = SaveCore.load_state()
	var chs: Array = save.get("chapters", [])
	if not "chapter1" in chs:
		chs.append("chapter1")
		save["chapters"] = chs
	save["prestige"] = maxi(int(save.get("prestige", 0)), 8888)
	SaveCore.save_state(save)

	# 启动测试流程
	_run_all_tests()

func _assert(condition: bool, msg: String) -> void:
	total_asserts += 1
	if condition:
		passed_asserts += 1
		print("  ✅ [PASS] %s" % msg)
	else:
		failed_asserts += 1
		printerr("  ❌ [FAIL] %s" % msg)

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

## 物理鼠标移动
func mouse_move(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)
	await process_frame

## 物理鼠标点击（按下 + 抬起）
func mouse_click(pos: Vector2, is_right: bool = false, delay_after: float = 0.08) -> void:
	var btn := MOUSE_BUTTON_RIGHT if is_right else MOUSE_BUTTON_LEFT
	
	# 移动
	var ev_motion := InputEventMouseMotion.new()
	ev_motion.position = pos
	ev_motion.global_position = pos
	Input.parse_input_event(ev_motion)
	await process_frame
	
	# 按下
	var ev_down := InputEventMouseButton.new()
	ev_down.button_index = btn
	ev_down.pressed = true
	ev_down.position = pos
	ev_down.global_position = pos
	Input.parse_input_event(ev_down)
	await process_frame
	
	# 抬起
	var ev_up := InputEventMouseButton.new()
	ev_up.button_index = btn
	ev_up.pressed = false
	ev_up.position = pos
	ev_up.global_position = pos
	Input.parse_input_event(ev_up)
	await process_frame
	
	if delay_after > 0:
		await create_timer(delay_after).timeout

## 物理点击控件中心
func click_control(ctrl: Control, delay_after: float = 0.08) -> void:
	var rect := ctrl.get_global_rect()
	var center := rect.get_center()
	await mouse_click(center, false, delay_after)

## 物理键盘按键敲击
func key_press(keycode: Key, delay_after: float = 0.08) -> void:
	var ev_down := InputEventKey.new()
	ev_down.keycode = keycode
	ev_down.pressed = true
	Input.parse_input_event(ev_down)
	await process_frame
	
	var ev_up := InputEventKey.new()
	ev_up.keycode = keycode
	ev_up.pressed = false
	Input.parse_input_event(ev_up)
	await process_frame
	
	if delay_after > 0:
		await create_timer(delay_after).timeout

## 在树中递归查找指定类型的节点（支持文本模糊匹配）
func find_node_by_text(node: Node, text_substr: String) -> Control:
	if node is Button and text_substr in node.text:
		return node
	for child in node.get_children():
		var found = find_node_by_text(child, text_substr)
		if found:
			return found
	return null

## ==================== 全量测试主流程 ====================
func _run_all_tests() -> void:
	print("\n>>> 正在载入主城大厅...")
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(0.5)

	# -------------------------------------------------------------
	# 阶段 1: 主城大厅导航与抽奖模块全链路真手测试
	# -------------------------------------------------------------
	print("\n--- 【阶段 1】主城大厅 -> 军机抽奖模块真手测试 ---")
	var btn_lottery: Button = find_node_by_text(root, "军机祈赏")
	_assert(btn_lottery != null, "成功定位主城大厅【🎲 军机祈赏】按钮")
	
	if btn_lottery:
		print("  -> 物理鼠标点击【🎲 军机祈赏】按钮...")
		await click_control(btn_lottery, 0.4)
		_assert(current_scene.scene_file_path == "res://scenes/lottery.tscn", "物理点击成功切换到抽奖场景！")
	
	# 在抽奖界面进行仙种抽取
	var btn_seed: Button = find_node_by_text(root, "祈得仙种")
	_assert(btn_seed != null, "成功定位【🌱 消耗 1000 军功 · 祈得仙种】按钮")
	if btn_seed:
		var pre_save := SaveCore.load_state()
		var pre_p := int(pre_save.get("prestige", 0))
		print("  -> 物理鼠标点击【神农仙种抽取】按钮（当前声望: %d）..." % pre_p)
		await click_control(btn_seed, 0.3)
		var post_save := SaveCore.load_state()
		var post_p := int(post_save.get("prestige", 0))
		_assert(post_p == pre_p - 1000, "声望真实扣减 1000（剩余声望: %d）" % post_p)

	# 物理点击返回主城按钮
	var btn_back_lottery: Button = find_node_by_text(root, "返回主菜单")
	_assert(btn_back_lottery != null, "成功定位抽奖界面【🔙 返回主菜单】按钮")
	if btn_back_lottery:
		print("  -> 物理鼠标点击【🔙 返回主菜单】按钮...")
		await click_control(btn_back_lottery, 0.2)
		await _wait(0.5)
		_assert(current_scene.scene_file_path == "res://scenes/main.tscn", "物理点击成功返回主城场景！")

	# -------------------------------------------------------------
	# 阶段 2: 主城大厅导航与诸侯图鉴模块全链路真手测试
	# -------------------------------------------------------------
	print("\n--- 【阶段 2】主城大厅 -> 诸侯图鉴模块真手测试 ---")
	var btn_gallery: Button = find_node_by_text(root, "诸侯图鉴")
	_assert(btn_gallery != null, "成功定位主城大厅【📜 诸侯图鉴】按钮")
	if btn_gallery:
		print("  -> 物理鼠标点击【📜 诸侯图鉴】按钮...")
		await click_control(btn_gallery, 0.2)
		await _wait(0.5)
		_assert(current_scene.scene_file_path == "res://scenes/gallery.tscn", "物理点击成功切换到图鉴场景！")

	var btn_back_gallery: Button = find_node_by_text(root, "返回主菜单")
	_assert(btn_back_gallery != null, "成功定位图鉴界面【🔙 返回主菜单】按钮")
	if btn_back_gallery:
		print("  -> 物理鼠标点击【🔙 返回主菜单】按钮...")
		await click_control(btn_back_gallery, 0.2)
		await _wait(0.5)
		_assert(current_scene.scene_file_path == "res://scenes/main.tscn", "物理点击成功从图鉴返回主城！")

	# -------------------------------------------------------------
	# 阶段 3: 主城一键扫荡与模态弹窗真手测试
	# -------------------------------------------------------------
	print("\n--- 【阶段 3】主城一键扫荡与弹窗真手测试 ---")
	var btn_sweep: Button = find_node_by_text(root, "一键扫荡")
	_assert(btn_sweep != null, "成功定位【⚡ 一键扫荡】按钮")
	if btn_sweep:
		var pre_p := int(SaveCore.load_state().get("prestige", 0))
		print("  -> 物理鼠标点击【⚡ 一键扫荡】按钮...")
		await click_control(btn_sweep, 0.3)
		
		# 检查弹窗是否存在
		var btn_modal_ok: Button = find_node_by_text(root, "领赏凯旋")
		_assert(btn_modal_ok != null, "扫荡弹窗成功挂载且找到【领赏凯旋】确认按钮")
		if btn_modal_ok:
			print("  -> 物理鼠标点击【领赏凯旋】按钮...")
			await click_control(btn_modal_ok, 0.2)
			var post_p := int(SaveCore.load_state().get("prestige", 0))
			_assert(post_p == pre_p + 1000, "扫荡成功增加 1000 声望（当前声望: %d）" % post_p)

	# -------------------------------------------------------------
	# 阶段 4: 进军战役与战前剧情真实点击推进测试
	# -------------------------------------------------------------
	print("\n--- 【阶段 4】进军战役与剧情对白真手交互测试 ---")
	var btn_enter_battle: Button = find_node_by_text(root, "手动重战")
	if btn_enter_battle == null:
		btn_enter_battle = find_node_by_text(root, "进 军 出 征")
	_assert(btn_enter_battle != null, "成功定位第1关出征/重战按钮")
	if btn_enter_battle:
		print("  -> 物理鼠标点击出征按钮进入第一关战场...")
		await click_control(btn_enter_battle, 0.5)
		_assert(current_scene.scene_file_path == "res://scenes/battle.tscn", "物理点击成功加载战场场景！")

	var battle = current_scene
	_assert(battle.dialog_showing == true, "战前剧情对话框正确激活显示")

	# 子测试 4.1：测试空白处物理点击翻页（验证修复）
	print("  -> 测试物理鼠标点击屏幕空白区域 (500, 300) 推进对白...")
	var initial_dialog_count: int = battle.pending_dialog.size()
	await mouse_click(Vector2(500, 300), false, 0.15)
	_assert(battle.pending_dialog.size() < initial_dialog_count or not battle.dialog_showing, "空白处物理点击成功推进对白！")

	# 子测试 4.2：测试物理敲击空格键翻页
	print("  -> 测试物理键盘敲击【空格键】推进对白...")
	var pre_space_count: int = battle.pending_dialog.size()
	await key_press(KEY_SPACE, 0.15)
	_assert(battle.pending_dialog.size() < pre_space_count or not battle.dialog_showing, "空格键物理敲击成功推进对白！")

	# 子测试 4.3：测试物理点击“跳过剧情”按钮
	print("  -> 测试物理鼠标直接点击【跳过剧情 ⏩】按钮...")
	var skip_btn: Button = battle.dialog_skip_btn
	_assert(skip_btn != null, "成功找到【跳过剧情 ⏩】按钮")
	if skip_btn:
		await click_control(skip_btn, 0.25)
		_assert(battle.dialog_showing == false, "物理点击跳过剧情后，剧情彻底关闭，战局正式开始！")

	# -------------------------------------------------------------
	# 阶段 5: 真实物理点击选人、取消、走位与待机手感测试
	# -------------------------------------------------------------
	print("\n--- 【阶段 5】真实棋盘网格点击、走位与指令测试 ---")
	
	# 关羽初始坐标 (2, 5)
	var guanyu_cell := Vector2i(2, 5)
	var guanyu_px: Vector2 = battle._cell_to_px(guanyu_cell)
	print("  -> 关羽初始物理像素坐标: ", guanyu_px)

	# 子测试 5.1: 物理鼠标点击关羽所在格子
	print("  -> 物理鼠标点击关羽格子进行武将选中...")
	await mouse_click(guanyu_px, false, 0.2)
	_assert(battle.selected_id == "guanyu", "物理点击棋盘成功选中关羽（selected_id == guanyu）！")
	_assert(battle._is_in_reachable(Vector2i(4, 5)), "关羽移动范围计算正确，(4, 5) 在绿色可达范围中！")

	# 子测试 5.2: 物理鼠标右键点击取消选择
	print("  -> 物理鼠标右键点击屏幕任意处，测试右键取消选人...")
	await mouse_click(Vector2(600, 300), true, 0.15)
	_assert(battle.selected_id == "", "物理鼠标右键成功取消选人（selected_id 为空）！")
	_assert(battle.command_menu.visible == false, "军令指示菜单随之隐退！")

	# 子测试 5.3: 重新点击关羽 -> 直接点击绿色格子进行直观走位
	print("  -> 再次物理鼠标左键点击关羽...")
	await mouse_click(guanyu_px, false, 0.15)
	_assert(battle.selected_id == "guanyu", "关羽重新被选中")

	# 选择一个关羽可达的目标格 (4, 5)
	var target_cell := Vector2i(4, 5)
	var target_px: Vector2 = battle._cell_to_px(target_cell)
	print("  -> 物理鼠标直接点击绿色可达格子 (4, 5) 坐标: %s..." % target_px)
	await mouse_click(target_px, false, 0.25)
	
	var guanyu_unit = battle._unit_by_id("guanyu")
	_assert(guanyu_unit.cell == target_cell, "关羽成功移动到目标格 (4, 5)！")
	_assert(guanyu_unit.charge == 2, "关羽移动2格累积2层蓄力（charge = %d）！" % guanyu_unit.charge)

	_assert(guanyu_unit.acted == true, "关羽走位后自动进入行动完毕状态！")

	# 子测试 5.4: 点击张飞进行待机蓄力（测试燕人咆哮蓄力与军令菜单物理点击）
	print("  -> 物理鼠标点击张飞 (1, 6) 进行选中与军令待机测试...")
	var zhangfei_px: Vector2 = battle._cell_to_px(Vector2i(1, 6))
	await mouse_click(zhangfei_px, false, 0.2)
	_assert(battle.selected_id == "zhangfei", "物理点击成功选中张飞（selected_id == zhangfei）！")
	_assert(battle.command_menu.visible == true, "张飞军令菜单成功浮现！")

	var btn_standby: Button = find_node_by_text(battle.command_menu, "待机")
	_assert(btn_standby != null, "成功在张飞军令菜单中找到【待机/蓄力】按钮")
	if btn_standby:
		print("  -> 物理鼠标点击【待机/蓄力】按钮...")
		await click_control(btn_standby, 0.2)
		var zhangfei_unit = battle._unit_by_id("zhangfei")
		_assert(zhangfei_unit.acted == true, "张飞成功待机休整（acted == true）！")
		_assert(zhangfei_unit.charge == 1, "张飞待机成功叠加1层咆哮蓄力（charge == 1）！")

	# -------------------------------------------------------------
	# 阶段 6: 顶部战术秘籍与结束回合真手测试
	# -------------------------------------------------------------
	print("\n--- 【阶段 6】战术秘籍与结束回合真手测试 ---")
	var help_btn: Button = battle.help_btn
	_assert(help_btn != null, "成功找到顶部【? 战术秘籍】按钮")
	if help_btn:
		print("  -> 物理鼠标点击【? 战术秘籍】...")
		await click_control(help_btn, 0.2)
		_assert(battle.dialog_showing == true, "战术秘籍教学弹窗成功展开！")
		
		print("  -> 物理点击【跳过剧情 ⏩】关闭秘籍弹窗...")
		var help_skip_btn: Button = battle.dialog_skip_btn
		if help_skip_btn:
			await click_control(help_skip_btn, 0.2)
		_assert(battle.dialog_showing == false, "秘籍弹窗成功关闭！")

	var end_turn_btn: Button = battle.end_turn_btn
	_assert(end_turn_btn != null, "成功找到顶部【结束回合 ⚔️】按钮")
	if end_turn_btn:
		print("  -> 物理鼠标点击【结束回合 ⚔️】按钮...")
		await click_control(end_turn_btn, 0.1)
		print("  -> 等待敌方回合行动与动画演算...")
		await _wait(2.2)
		_assert(battle.turn_state.turn == 2, "回合成功推进至第 2 回合（turn_state.turn == 2）！")
		_assert(guanyu_unit.acted == false, "新回合开始，我方武将行动状态自动重置！")

	# -------------------------------------------------------------
	# 验收与总结
	# -------------------------------------------------------------
	print("\n==================================================")
	print("🏁 [虚拟玩家测试完成] 总断言: %d | 通过: %d | 失败: %d" % [total_asserts, passed_asserts, failed_asserts])
	print("==================================================")
	
	if failed_asserts == 0:
		print("🎉【100% 全量真机模拟测试完全通过】真实玩家操作无死角！")
		quit(0)
	else:
		printerr("💥【测试存在失败项】请排查上述 FAIL 条目！")
		quit(1)
