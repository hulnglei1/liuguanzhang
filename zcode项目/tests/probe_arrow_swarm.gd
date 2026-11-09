extends SceneTree
## 公孙瓒「回旋飞弹」第二版验收（按玩家反馈改）：
##
## 原著：「他朝天上连射数箭……犹如人形防空炮」「唯一的缺点就是箭矢速度偏慢！」
##       「箭雨**绕了个弯**，朝自己的脸上飞来」「一支箭从他**身后**擦过肩膀」
##
## 本版三条硬要求：
##   1. 一次只射 1 支（两支同格同速会完全重叠，看起来就是一支）
##   2. 真·绕后：先飞到目标**身后 2 格**，再折返命中（不是每回合朝目标直线挪）
##   3. 速度 1 格/回合 + CD 0 → 越打天上越多

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
	print("\n===== 回旋飞弹 v2：一支 / 绕后 / 慢速 =====")
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
	var foe = null
	var best_d := 999
	for u in b._camp_units("enemy"):
		var d: int = GridCore.chebyshev(gsz.cell, u.cell)
		if d > 1 and d < best_d:
			best_d = d
			foe = u
	_check(gsz != null and foe != null, "公孙瓒与远处目标就位（%d 格）" % best_d)

	# ---------- 1. 一次 1 支 ----------
	b.active_arrows.clear()
	b._apply_events(SkillsCore.do_arrow_rain(gsz, foe, b.units))
	await _wait(0.3)
	print("  施放后空中飞弹 = %d" % b.active_arrows.size())
	_check(b.active_arrows.size() == 1, "一次施放只有 1 支（不再重叠）")
	var arr: Dictionary = b.active_arrows[0]

	# ---------- 2. 绕后航点在目标身后 ----------
	b._update_homing_arrows()
	await _wait(0.4)
	var wp: Vector2i = arr.get("waypoint", Vector2i(-1, -1))
	var wp_from_target: int = GridCore.chebyshev(wp, foe.cell)
	print("  绕后航点=%s，距目标 %d 格，当前阶段=%s" % [str(wp), wp_from_target, str(arr.get("phase"))])
	_check(wp != Vector2i(-1, -1), "航点已计算")
	_check(wp_from_target >= 1 and wp_from_target <= 3, "航点在目标身旁/身后（不是目标本身）")

	# 推进直到进入 strike 阶段：说明它先飞过目标再折返
	var passed := 0
	var switched := false
	var dist_at_switch := 0
	for i in range(24):
		b._update_homing_arrows()
		await _wait(0.05)
		if b.active_arrows.is_empty():
			break
		if str(b.active_arrows[0].get("phase")) == "strike":
			switched = true
			dist_at_switch = GridCore.chebyshev(b.active_arrows[0].cell, foe.cell)
			break
		passed += 1
	print("  第 %d 回合转入折返，此时距目标 %d 格" % [passed, dist_at_switch])
	_check(switched, "箭先绕到目标身侧/身后再折返（真·绕后）")

	# ---------- 3. 折返后能命中 ----------
	var hp_before: int = foe.hp
	for i in range(24):
		b._update_homing_arrows()
		await _wait(0.05)
		if b.active_arrows.is_empty():
			break
	print("  命中后 %s HP %d → %d，空中剩余 %d" % [foe.name, hp_before, foe.hp, b.active_arrows.size()])
	_check(foe.hp < hp_before or not foe.alive, "绕后一圈后仍然命中")

	# ---------- 4. 多轮补射能累积 ----------
	b.active_arrows.clear()
	for turn in range(4):
		b._apply_events(SkillsCore.do_arrow_rain(gsz, foe, b.units))
		await _wait(0.15)
		b._update_homing_arrows()
		await _wait(0.15)
	print("  连射 4 轮后空中 = %d" % b.active_arrows.size())
	_check(b.active_arrows.size() >= 3, "CD 0 + 慢速 → 天上会累积多支")

	print("\n===== %s =====" % ("全部通过 ✅" if failed == 0 else "失败 %d 项 ❌" % failed))
	SaveCore.save_state(SaveCore.new_state())
	quit(0 if failed == 0 else 1)
