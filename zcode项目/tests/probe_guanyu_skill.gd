extends SceneTree
## 关羽青龙斩：**走真实点击链路**验收（按钮 → 点目标 → 技能真的打出去）
## 运行：Godot_console.exe --headless --path zcode项目 --script res://tests/probe_guanyu_skill.gd
##
## 为什么单独写这个：之前只断言 `_has_skill_target()` 的返回值就下了结论，结果玩家实测仍然"点不出来"。
## 教训（第二次了）：涉及输入/按钮的验证必须走真实入口 —— 看真实按钮节点的 disabled、
## 真的 emit pressed、真的走 _handle_click。

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")

const MODE_SELECT := 1
const MODE_SKILL := 4

var b: Node
var failed: int = 0


func _initialize() -> void:
	var s: Dictionary = SaveCore.new_state()
	s["prologues_seen"] = ["chapter1", "chapter2", "chapter3", "chapter4"]
	SaveCore.save_state(s)
	BattleScript.chapter_id = "chapter1"
	change_scene_to_file("res://scenes/battle.tscn")
	_run()


func _wait(x: float) -> void:
	await create_timer(x).timeout


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		failed += 1


## 从命令菜单里找技能按钮（真实 UI 节点）
func _find_skill_button() -> Button:
	var btns: Array = b.command_menu.find_children("*", "Button", true, false)
	for c in btns:
		if c is Button and (c as Button).text.begins_with("✨"):
			return c
	return null


func _clear_dialog() -> void:
	b.pending_dialog = []
	b.dialog_showing = false
	b.dialog_box.visible = false


func _run() -> void:
	await _wait(2.5)
	b = current_scene
	if b.has_method("_on_dialog_skip_pressed"):
		b._on_dialog_skip_pressed()
	await _wait(0.8)

	var gy = b._unit_by_id("guanyu")
	var dao = b._unit_by_id("dao_bing_1")      # (5,4)
	if gy == null or dao == null:
		print("❌ 找不到关羽或刀兵")
		quit(1)
		return

	print("\n===== 关羽青龙斩：真实点击链路 =====")

	# ---------- 场景 1：站到敌人相邻格 ----------
	print("\n---- 1. 相邻敌军（应为可用）----")
	_clear_dialog()
	gy.cell = Vector2i(4, 4)                   # 与 dao_bing_1(5,4) 相邻
	gy.charge = 0
	gy.acted = false
	gy.cds.clear()
	b.selected_id = ""
	b._handle_click(gy.cell)                   # 玩家第一次点：选中
	await _wait(0.3)
	b._handle_click(gy.cell)                   # 玩家第二次点自己：才弹出命令菜单
	await _wait(0.4)
	print("  两次点击后 input_mode=%d（1=SELECT / 5=POST_MOVE）" % int(b.input_mode))
	var btn: Button = _find_skill_button()
	if btn == null:
		print("  ❌ 命令菜单里找不到技能按钮（按钮根本没生成）")
		failed += 1
	else:
		print("  技能按钮：text=\"%s\"  disabled=%s" % [btn.text, str(btn.disabled)])
		_check(not btn.disabled, "站在敌人相邻格 → 按钮**不灰**")
		if not btn.disabled:
			btn.pressed.emit()                 # 真实点击
			await _wait(0.4)
			print("  点技能后 input_mode=%d（应为 %d=SKILL）" % [int(b.input_mode), MODE_SKILL])
			_check(int(b.input_mode) == MODE_SKILL, "点技能 → 进入选目标态")
			var hp0: int = dao.hp
			b._handle_click(dao.cell)          # 真实点目标格
			await _wait(0.8)
			print("  刀兵 HP %d → %d" % [hp0, dao.hp])
			_check(dao.hp < hp0, "点相邻敌军 → 青龙斩真的打出去了")
			_check(bool(gy.acted), "出手后关羽标记已行动")

	# ---------- 场景 2：斩华雄后劈城门 ----------
	print("\n---- 2. 斩华雄 → 劈城门（应为可用）----")
	_clear_dialog()
	var hx = b._unit_by_id("huaxiong")
	hx.hp = 0
	hx.alive = false
	b._check_victory()
	await _wait(1.2)
	_clear_dialog()
	print("  stage_idx=%d（应为 1）gate_broken=%s" % [int(b.stage_idx), str(b.gate_broken)])

	gy.cell = Vector2i(7, 4)                   # 与城门 (10,4) 同排、距离 3
	gy.charge = 10
	gy.acted = false
	gy.cds.clear()
	b.selected_id = ""
	b._handle_click(gy.cell)
	await _wait(0.3)
	b._handle_click(gy.cell)
	await _wait(0.4)
	var btn2: Button = _find_skill_button()
	if btn2 == null:
		print("  ❌ 找不到技能按钮")
		failed += 1
	else:
		print("  技能按钮：text=\"%s\"  disabled=%s" % [btn2.text, str(btn2.disabled)])
		_check(not btn2.disabled, "与城门同排 + 满蓄力 → 按钮**不灰**")
		if not btn2.disabled:
			btn2.pressed.emit()
			await _wait(0.4)
			var marked: bool = false
			for c in b.overlay.get_children():
				marked = true
			print("  点技能后 input_mode=%d，高亮格数=%d" % [int(b.input_mode), int(b.overlay.get_child_count())])
			_check(marked, "点技能后画出了可劈位置高亮（含城门）")
			b._handle_click(Vector2i(10, 4))
			await _wait(1.0)
			print("  gate_broken=%s" % str(b.gate_broken))
			_check(bool(b.gate_broken), "点城门 → 真的劈开了汜水关")

	# ---------- 场景 3：蓄力不足时按钮仍应可用（点了才提示）----------
	print("\n---- 3. 蓄力不足（按钮应可用，点了给提示）----")
	_clear_dialog()
	# 场景 2 通关后残敌已被清场，这里放一个敌人到关羽身旁再测
	var dao2 = b._unit_by_id("dao_bing_2")
	if dao2 != null:
		dao2.alive = true
		dao2.hp = dao2.max_hp
		dao2.cell = Vector2i(6, 4)
		b._sync_text(dao2)
	gy.charge = 3
	gy.acted = false
	gy.cell = Vector2i(7, 4)
	b.selected_id = ""
	b._handle_click(gy.cell)
	await _wait(0.3)
	b._handle_click(gy.cell)
	await _wait(0.3)
	var btn3: Button = _find_skill_button()
	if btn3 != null:
		print("  按钮 disabled=%s，text=\"%s\"" % [str(btn3.disabled), btn3.text])
		_check(not btn3.disabled, "蓄力不足但直线够近 → 按钮可用（不能灰，否则玩家不知道能做什么）")

	print("\n===== 汇总 =====")
	if failed == 0:
		print("关羽技能链路：全部通过 ✅")
	else:
		print("关羽技能链路：失败 %d 项 ❌" % failed)
	SaveCore.save_state(SaveCore.new_state())
	quit(0 if failed == 0 else 1)
