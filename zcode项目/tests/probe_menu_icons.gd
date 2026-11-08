extends SceneTree
## 命令菜单图标验收：确认按钮真的挂上了印章图标（不是只有 10 张图躺在磁盘里）。
##
## 这类"资源做了但没接进 UI"的退化用眼睛很难发现——按钮照常能点，
## 只是回到了 emoji/纯文字，所以必须自动查。

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")

var failed := 0


func _initialize() -> void:
	_run()


func _wait(x: float) -> void:
	await create_timer(x).timeout


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  ✅ " + msg)
	else:
		printerr("  ❌ " + msg)
		failed += 1


func _find_btn(root: Node, keyword: String) -> Button:
	if root is Button and String((root as Button).text).contains(keyword):
		return root
	for c in root.get_children():
		var hit := _find_btn(c, keyword)
		if hit != null:
			return hit
	return null


func _run() -> void:
	print("\n===== 命令菜单图标验收 =====")
	var s: Dictionary = SaveCore.new_state()
	s["prologues_seen"] = ["chapter1"]
	SaveCore.save_state(s)

	BattleScript.chapter_id = "chapter1"
	change_scene_to_file("res://scenes/battle.tscn")
	await _wait(2.2)
	var b: Node = current_scene
	await _wait(0.4)
	var guard := 0
	while bool(b.dialog_showing) and guard < 40:
		b._on_dialog_btn_pressed()
		await _wait(0.05)
		guard += 1

	# 选中刘备并弹命令菜单
	b._select_unit("liubei")
	await _wait(0.3)
	b._show_command_menu()
	await _wait(0.3)

	var menu: Control = b.command_menu
	_check(menu != null and menu.visible, "命令菜单已弹出")

	var pairs := {
		"普通攻击": "attack",
		"待机休整": "def",
	}
	for keyword in pairs.keys():
		var btn := _find_btn(menu, keyword)
		if btn == null:
			_check(false, "找不到按钮：%s" % keyword)
			continue
		var has_icon: bool = btn.icon != null
		_check(has_icon, "「%s」按钮挂上了印章图标" % keyword)

	# 绝技按钮：刘备有技能，应带图标
	var skill_btn := _find_btn(menu, "龙斩")
	if skill_btn == null:
		skill_btn = _find_btn(menu, "咆哮")
	if skill_btn != null:
		_check(skill_btn.icon != null, "「绝技」按钮挂上了印章图标")
	else:
		print("  ⚠ 刘备没有可显示绝技按钮（跳过）")

	# 图标资源本身齐全
	for n in ["attack", "skill", "move", "endturn", "morale", "hp", "atk", "def", "mov", "range"]:
		var p := "res://assets/icons/%s.png" % n
		_check(ResourceLoader.exists(p), "图标文件存在：%s.png" % n)

	print("\n===== %s =====" % ("全部通过 ✅" if failed == 0 else "失败 %d 项 ❌" % failed))
	SaveCore.save_state(SaveCore.new_state())
	quit(0 if failed == 0 else 1)
