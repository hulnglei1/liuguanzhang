extends SceneTree
## 宣传短片导演脚本：自动演示第一关 / 第二关，可配合 MovieMaker 录视频
##
## 用法：
##   预览（无窗口）：Godot_console.exe --headless --path zcode项目 --script res://tests/director_promo.gd -- ch1
##   录像（Godot 4 MovieMaker，输出 MJPEG AVI）：
##     Godot_console.exe --path zcode项目 --write-movie "<绝对路径>.avi" --fixed-fps 30 --resolution 1280x720 --script res://tests/director_promo.gd -- ch1
##
## 参数：ch1 / ch2 / all，缺省 all

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")

var target := "all"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg in ["ch1", "ch2", "all"]:
			target = arg
	print("[导演] 启动，目标: ", target)
	root.size = Vector2i(1280, 720)

	var save: Dictionary = SaveCore.load_state()
	var chs: Array = []
	# 为了让目标关卡的按钮显示为首次出征，只解锁它之前的关卡
	if target == "ch2" or target == "all":
		chs.append("chapter1")
	save["chapters"] = chs
	save["prestige"] = 8888
	SaveCore.save_state(save)

	_run()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _frame() -> void:
	await process_frame


func _click(pos: Vector2, delay_after: float = 0.0) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	Input.parse_input_event(motion)
	await _frame()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	Input.parse_input_event(down)
	await _frame()
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	Input.parse_input_event(up)
	await _frame()
	if delay_after > 0.0:
		await _wait(delay_after)


func _click_node(ctrl: Node, delay_after: float = 0.0) -> bool:
	if ctrl == null or not is_instance_valid(ctrl):
		return false
	if ctrl is Control:
		await _click(ctrl.get_global_rect().get_center(), delay_after)
		return true
	return false


func _btn(node_name: String) -> Node:
	return root.find_child(node_name, true, false)


func _run() -> void:
	if target == "all" or target == "ch1":
		await _play("chapter1")
	if target == "all" or target == "ch2":
		await _play("chapter2")
	print("[导演] 演示结束")
	quit(0)


func _press_space() -> void:
	var d := InputEventKey.new()
	d.keycode = KEY_SPACE
	d.pressed = true
	Input.parse_input_event(d)
	await _frame()
	var u := InputEventKey.new()
	u.keycode = KEY_SPACE
	u.pressed = false
	Input.parse_input_event(u)
	await _frame()


func _play(chapter_id: String) -> void:
	print("[导演] >>> ", chapter_id)
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(1.3)

	BattleScript.chapter_id = chapter_id
	await _click_node(_btn("btn_" + chapter_id), 1.4)
	if not (current_scene is BattleScript):
		change_scene_to_file("res://scenes/battle.tscn")
		await _wait(1.4)

	var battle := current_scene
	await _wait(1.2)
	# 玩家按空格推进两句对白，然后跳过余下剧情直奔战斗
	await _press_space()
	await _wait(0.9)
	await _press_space()
	await _wait(0.6)
	if battle.has_method("_on_dialog_skip_pressed"):
		battle._on_dialog_skip_pressed()
	await _wait(1.0)

	if chapter_id == "chapter1":
		await _act_chapter1(battle)
	else:
		await _act_chapter2(battle)
	await _wait(1.2)


func _act_chapter1(battle) -> void:
	# 满蓄力青龙偃月斩 · 一刀斩华雄
	var gy = battle._unit_by_id("guanyu")
	var hx = battle._unit_by_id("huaxiong")
	if gy and hx and is_instance_valid(gy) and is_instance_valid(hx):
		gy.charge = 10
		battle.selected_id = "guanyu"
		battle._select_unit("guanyu")
		await _wait(1.2)
		battle.selected_id = "guanyu"
		battle._do_skill(hx.cell)
		await _wait(3.4)
	# 胜利对白 -> 结算面板
	if battle.has_method("_on_dialog_skip_pressed"):
		battle._on_dialog_skip_pressed()
	await _wait(2.2)


func _act_chapter2(battle) -> void:
	# 张飞开局即吼，震晕吕布并震散方天连击
	var zf = battle._unit_by_id("zhangfei")
	var gy = battle._unit_by_id("guanyu")
	var lb = battle._unit_by_id("lubu")
	if zf and lb and is_instance_valid(zf) and is_instance_valid(lb):
		battle.selected_id = "zhangfei"
		battle._select_unit("zhangfei")
		await _wait(0.9)
		battle.selected_id = "zhangfei"
		battle._do_skill(lb.cell)
		await _wait(2.6)
	# 关羽满蓄力跟进
	if gy and lb and is_instance_valid(gy) and is_instance_valid(lb):
		gy.charge = 10
		battle.selected_id = "guanyu"
		battle._select_unit("guanyu")
		await _wait(1.0)
		battle.selected_id = "guanyu"
		battle._do_skill(lb.cell)
		await _wait(3.0)
