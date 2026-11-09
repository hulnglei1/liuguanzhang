extends SceneTree
## 玩家反馈回归：眩晕的三件事 + 回合结束弹窗
##
## 1. 我方被眩晕后**不能再移动/行动**（之前 14 字咆哮把刘备吼晕，他还能走）
## 2. 眩晕要有**可视图标**（我方和敌方都要，之前只有我方偶发出现）
## 3. 全员行动完毕要**弹窗问是否结束回合**（曹操传式，之前自动切走）

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


func _label_of(uid: String) -> String:
	var n = b.unit_nodes.get(uid)
	if n == null:
		return "<无节点>"
	var lab: Label = n.get_node_or_null("StatusLabel")
	return "<无标签>" if lab == null else lab.text


func _run() -> void:
	print("\n===== 眩晕回归 + 回合结束弹窗 =====")
	var s: Dictionary = SaveCore.new_state()
	s["prologues_seen"] = ["chapter1"]
	SaveCore.save_state(s)
	BattleScript.chapter_id = "chapter1"
	change_scene_to_file("res://scenes/battle.tscn")
	await _wait(2.2)
	b = current_scene
	await _wait(0.4)
	var guard := 0
	while bool(b.dialog_showing) and guard < 60:
		b._on_dialog_btn_pressed()
		await _wait(0.05)
		guard += 1

	var zf = b._unit_by_id("zhangfei")
	var lb = b._unit_by_id("liubei")
	var foe = null
	for u in b._camp_units("enemy"):
		foe = u
		break
	_check(zf != null and lb != null and foe != null, "张飞 / 刘备 / 一名敌人 就位")

	# ---------- 1. 我方被吼晕 → 立即失去行动权 ----------
	print("\n[1] 我方被眩晕后不能行动")
	lb.acted = false
	lb.moved_this_turn = false
	var allies: Array = [lb]
	b._apply_events(SkillsCore.do_roar(zf, [], 14, allies))
	await _wait(0.3)
	print("  刘备 stun=%d acted=%s moved=%s" % [lb.stun_turns, str(lb.acted), str(lb.moved_this_turn)])
	_check(lb.stun_turns > 0, "刘备被眩晕")
	_check(lb.acted, "眩晕即视为已行动（不再能移动/攻击）")
	_check(lb.moved_this_turn, "眩晕也标记已移动（不能再走一次）")
	# 选中应被拒绝
	b.selected_id = ""
	b._select_unit(lb.id)
	_check(str(b.selected_id).is_empty(), "点击眩晕单位不会进入可操作态")

	# ---------- 2. 图标 ----------
	print("\n[2] 眩晕图标（我方 + 敌方）")
	var lb_icon := _label_of(lb.id)
	print("  刘备图标='%s'" % lb_icon)
	_check(lb_icon.contains("💫"), "我方眩晕有 💫 图标")

	foe.stun_turns = 0
	b._apply_events(SkillsCore.do_roar(zf, [foe], 14, []))
	await _wait(0.3)
	var foe_icon := _label_of(foe.id)
	print("  %s 图标='%s' stun=%d" % [foe.name, foe_icon, foe.stun_turns])
	_check(foe_icon.contains("💫"), "敌方眩晕同样有 💫 图标")

	# ---------- 3. 全员行动完 → 弹窗 ----------
	print("\n[3] 全员行动完毕弹窗")
	for u in b._camp_units("player"):
		u.acted = true
		if u.id not in b.turn_state.acted_ids:
			b.turn_state.acted_ids.append(u.id)
	b.end_turn_prompt = null
	b._after_action(zf)
	await _wait(0.4)
	var prompt: Control = b.end_turn_prompt
	var found_yes := false
	if prompt != null and is_instance_valid(prompt):
		found_yes = prompt.find_child("btn_end_turn_yes", true, false) != null
	print("  弹窗=%s 带「结束回合」按钮=%s" % [str(prompt != null), str(found_yes)])
	_check(prompt != null, "全员行动完后弹出确认窗")
	_check(found_yes, "确认窗里有「结束回合」按钮")
	_check(b.turn_state != null, "此时还未自动切到敌方回合（等玩家确认）")

	print("\n===== %s =====" % ("全部通过 ✅" if failed == 0 else "失败 %d 项 ❌" % failed))
	SaveCore.save_state(SaveCore.new_state())
	quit(0 if failed == 0 else 1)
