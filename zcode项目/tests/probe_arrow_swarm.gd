extends SceneTree
## 公孙瓒「回旋飞弹」按原著重做后的验收：
##   原著：「连射数箭……犹如人形防空炮」「唯一的缺点就是箭矢速度偏慢」「箭雨绕了个弯」
##   要求：一次射 2 支、每回合只推进 1 格、天上能同时挂多支

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")
const GridCore := preload("res://scripts/core/grid.gd")

var b: Node
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


func _run() -> void:
	print("\n===== 回旋飞弹：连射 + 慢速 + 多箭同挂 =====")
	var s: Dictionary = SaveCore.new_state()
	s["prologues_seen"] = ["chapter1", "chapter2"]
	SaveCore.save_state(s)
	BattleScript.chapter_id = "chapter2"
	change_scene_to_file("res://scenes/battle.tscn")
	await _wait(2.2)
	b = current_scene
	await _wait(0.4)
	var guard := 0
	while bool(b.dialog_showing) and guard < 60:
		b._on_dialog_btn_pressed()
		await _wait(0.05)
		guard += 1

	var gsz = b._unit_by_id("gongsunzan")
	if gsz == null:
		printerr("第 2 关没有公孙瓒")
		quit(1)
		return
	var foe = null
	var best_d := 999
	for u in b._camp_units("enemy"):
		var d: int = GridCore.chebyshev(gsz.cell, u.cell)
		if d > 1 and d < best_d:
			best_d = d
			foe = u
	_check(foe != null, "找到一个距离 >1 的敌人（%s，%d 格）" % [foe.name if foe else "-", best_d])

	# ---------- 1. 一次施放 = 2 支 ----------
	b.active_arrows.clear()
	var evs: Array = SkillsCore.do_arrow_rain(gsz, foe, b.units)
	b._apply_events(evs)
	await _wait(0.3)
	print("  第一次施放后，空中飞弹 = %d" % b.active_arrows.size())
	_check(b.active_arrows.size() == 2, "一次施放射出 2 支（原著「连射数箭」）")

	# ---------- 2. 每回合只推进 1 格 ----------
	var cells_before: Array = []
	for a in b.active_arrows:
		cells_before.append(a.cell)
	b._update_homing_arrows()
	await _wait(0.4)
	var moved_ok := true
	var detail: Array[String] = []
	for i in range(b.active_arrows.size()):
		var a: Dictionary = b.active_arrows[i]
		var from: Vector2i = cells_before[i]
		var to: Vector2i = a.get("cell", from)
		var step: int = GridCore.chebyshev(from, to)
		detail.append("%d" % step)
		if step > 1:
			moved_ok = false
	print("  一回合后各箭推进格数：%s" % ", ".join(detail))
	_check(moved_ok, "每回合只推进 1 格（原著「箭矢速度偏慢」）")
	_check(b.active_arrows.size() > 0, "飞弹仍在空中（没有当场命中）")

	# ---------- 3. 连续补射 → 天上攒多支 ----------
	for turn in range(2):
		var evs2: Array = SkillsCore.do_arrow_rain(gsz, foe, b.units)
		b._apply_events(evs2)
		await _wait(0.2)
		b._update_homing_arrows()
		await _wait(0.2)
	print("  连射 3 轮后，空中飞弹 = %d" % b.active_arrows.size())
	_check(b.active_arrows.size() >= 4, "多轮连射后天上挂着多支（人形防空炮）")
	_check(b.active_arrows.size() <= b.MAX_ARROWS_IN_FLIGHT, "不超过上限 %d 支" % b.MAX_ARROWS_IN_FLIGHT)

	# ---------- 4. 单支伤害有下调（靠数量取胜） ----------
	var mult_ok := true
	for a in b.active_arrows:
		if absf(float(a.get("mult", 1.0)) - 0.6) > 0.001:
			mult_ok = false
	_check(mult_ok, "单支伤害系数 0.6（不靠单击吃饭）")

	print("\n===== %s =====" % ("全部通过 ✅" if failed == 0 else "失败 %d 项 ❌" % failed))
	SaveCore.save_state(SaveCore.new_state())
	quit(0 if failed == 0 else 1)
