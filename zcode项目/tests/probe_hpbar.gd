extends SceneTree
## 血条实时刷新：砍完一刀，血槽必须当回合就变短。
## 玩家反馈："看了一刀，血槽还是满的，等刷新了一回合才少。"

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")
const CombatCore := preload("res://scripts/core/combat.gd")

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
	print("\n===== 血条实时刷新 =====")
	var s: Dictionary = SaveCore.new_state()
	s["prologues_seen"] = ["chapter1"]
	SaveCore.save_state(s)
	BattleScript.chapter_id = "chapter1"
	change_scene_to_file("res://scenes/battle.tscn")
	await _wait(2.2)
	var b: Node = current_scene
	await _wait(0.4)
	var guard := 0
	while bool(b.dialog_showing) and guard < 60:
		b._on_dialog_btn_pressed()
		await _wait(0.05)
		guard += 1

	var foe = null
	for u in b._camp_units("enemy"):
		if u.id.begins_with("dao_bing"):
			foe = u
			break
	if foe == null:
		printerr("找不到刀兵")
		quit(1)
		return

	var node: Node2D = b.unit_nodes.get(foe.id)
	var fill: ColorRect = node.get_node_or_null("HPBarFill")
	_check(fill != null, "找到血条节点")

	var w_before: float = fill.size.x
	var hp_before: int = foe.hp
	# 走真实伤害链路：先扣血，再发事件（引擎里就是这样）
	foe.take_damage(20)
	b._apply_events([CombatCore.make_damage_event(foe.id, 20, false)])
	await _wait(0.15)
	var w_after: float = fill.size.x
	print("  HP %d → %d ；血条宽 %.1f → %.1f" % [hp_before, foe.hp, w_before, w_after])
	_check(w_after < w_before, "受伤后血条**当场**变短（不需要等回合刷新）")

	print("\n===== %s =====" % ("全部通过 ✅" if failed == 0 else "失败 %d 项 ❌" % failed))
	SaveCore.save_state(SaveCore.new_state())
	quit(0 if failed == 0 else 1)
