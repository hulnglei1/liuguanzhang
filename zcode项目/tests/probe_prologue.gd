extends SceneTree
## 序章流程探测：清档 -> 主菜单 -> 点章节 -> 序章 -> 进入关卡

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")


func _initialize() -> void:
	var s: Dictionary = SaveCore.load_state()
	s["prologues_seen"] = []
	s["chapters"] = []
	SaveCore.save_state(s)
	change_scene_to_file("res://scenes/main.tscn")
	_run()


func _wait(x: float) -> void:
	await create_timer(x).timeout


func _scene_info() -> String:
	if current_scene == null:
		return "(null)"
	var scr = current_scene.get_script()
	var p: String = scr.resource_path if scr != null else "?"
	return "%s [%s]" % [current_scene.name, p]


func _run() -> void:
	await _wait(1.2)
	var btn = root.find_child("btn_chapter1", true, false)
	print("[探测] 找到章节按钮: ", btn != null)
	if current_scene.has_method("_on_chapter"):
		current_scene._on_chapter("chapter1")
	await _wait(1.2)
	print("[探测] 切换后场景: ", _scene_info())

	# 推进序章（Space 先补全打字，再推进下一行）
	for i in range(60):
		var ev := InputEventKey.new()
		ev.keycode = KEY_SPACE
		ev.pressed = true
		Input.parse_input_event(ev)
		await _wait(0.25)
	await _wait(1.5)
	print("[探测] 推进后场景: ", _scene_info())
	var st: Dictionary = SaveCore.load_state()
	print("[探测] prologues_seen = ", st.get("prologues_seen", []))
	quit(0)
