extends SceneTree
## 武安国剧情一致性验收：第 2 关"被吕布打飞"必须真实影响单位状态
## 运行：Godot_console.exe --headless --path zcode项目 --script res://tests/probe_wuanguo.gd
##
## 背景（原著）：武安国抡重锤挑战吕布，被方天画戟第三击（3 倍暴击）连人带锤打飞，
## "倒飞十几米，当场吐血脱力" —— 是重伤脱力，不是当场战死。
## 修复前的问题：剧情这么写，但游戏里武安国仍满血 160、DEF 不降、照样行动。

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")
const CombatCore := preload("res://scripts/core/combat.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")

var b: Node
var failed: int = 0


func _initialize() -> void:
	var s: Dictionary = SaveCore.load_state()
	s["chapters"] = []
	s["prologues_seen"] = ["chapter1", "chapter2", "chapter3", "chapter4"]
	SaveCore.save_state(s)
	BattleScript.chapter_id = "chapter2"
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


func _run() -> void:
	await _wait(2.5)
	b = current_scene
	if b.has_method("_on_dialog_skip_pressed"):
		b._on_dialog_skip_pressed()
	await _wait(0.6)

	var wu = b._unit_by_id("wuanguo")
	var lb = b._unit_by_id("lubu")
	if wu == null or lb == null:
		print("❌ 找不到武安国或吕布")
		quit(1)
		return

	print("\n===== 武安国剧情一致性验收 =====")
	print("  初始：HP %d/%d，DEF %d，吕布 ATK %d" % [
		wu.hp, wu.max_hp, wu.effective_def(), lb.effective_atk()])

	# ---------- 1. 第 3 回合之前不该有任何变化 ----------
	var hp0: int = wu.hp
	b.turn_state.turn = 1
	b._check_turn_events()
	await _wait(0.4)
	b.pending_dialog = []
	b.dialog_showing = false
	print("\n---- 1. 第 1 回合（事件未到）----")
	print("  HP %d → %d" % [hp0, wu.hp])
	_check(wu.hp == hp0, "第 1 回合不触发（狂暴事件在第 3 回合）")
	_check(not wu.exhausted, "第 1 回合不脱力")

	# ---------- 2. 第 3 回合触发：真实扣血 + 脱力 ----------
	print("\n---- 2. 第 3 回合「武安国被打飞」----")
	var hp_before: int = wu.hp
	var def_before: int = wu.effective_def()
	b.turn_state.turn = 3
	b._check_turn_events()
	await _wait(0.6)
	print("  HP %d → %d，DEF %d → %d，exhausted=%s，剩余 %d 回合" % [
		hp_before, wu.hp, def_before, wu.effective_def(), str(wu.exhausted), wu.exhausted_turns])
	_check(wu.alive, "武安国没被剧情直接打死（原著是吐血脱力，不是阵亡）")
	_check(wu.hp < hp_before, "剧情触发时真实扣血（血条会动，不再是满血站着）")
	_check(wu.exhausted and wu.exhausted_turns == 3, "进入 3 回合脱力状态")
	_check(wu.effective_def() < def_before, "DEF 因脱力真实下降（%d → %d）" % [def_before, wu.effective_def()])

	var floor_hp: int = int(ceil(float(wu.max_hp) * 0.3))
	_check(wu.hp >= floor_hp, "留有保底血量（应 ≥%d，实际 %d）" % [floor_hp, wu.hp])

	# ---------- 3. 残血保底：不能被打死 ----------
	print("\n---- 3. 残血保底（防剧情把单位打死）----")
	wu.hp = 5
	b._apply_event_effect({"kind": "smash_unit", "target": "wuanguo", "by": "lubu",
		"mult": 3.0, "hp_floor_ratio": 0.3, "exhausted_turns": 3})
	await _wait(0.3)
	print("  HP 5 → %d" % wu.hp)
	_check(wu.alive, "残血时剧情也只脱力、不致死")

	# ---------- 4. 脱力到期自动解除 ----------
	print("\n---- 4. 脱力回合数递减 ----")
	wu.set_exhausted(3)
	var seq: Array[String] = []
	for i in range(3):
		wu.end_turn()
		seq.append("%d" % wu.exhausted_turns)
	print("  3 次回合结束后的剩余回合：%s" % " → ".join(seq))
	_check(not wu.exhausted, "3 回合后脱力自动解除")

	# ---------- 5. 挥锤脱力仍是 1 回合（回归：旧机制不能被破坏） ----------
	print("\n---- 5. 武安国挥锤脱力（原有机制回归）----")
	wu.exhausted = false
	wu.exhausted_turns = 0
	var dao = b._unit_by_id("li_bu_fu_1")
	if dao != null:
		wu.cell = Vector2i(dao.cell.x - 1, dao.cell.y)
		var evs: Array = SkillsCore.do_attack(wu, dao)
		print("  攻击后 exhausted=%s，剩余 %d 回合" % [str(wu.exhausted), wu.exhausted_turns])
		_check(wu.exhausted and wu.exhausted_turns == 1, "挥锤后脱力 1 回合（原行为不变）")
		wu.end_turn()
		_check(not wu.exhausted, "1 回合后解除")

	print("\n===== 验收结束：%s =====" % ("全部通过 ✅" if failed == 0 else "失败 %d 项 ❌" % failed))
	SaveCore.save_state(SaveCore.new_state())
	quit(0 if failed == 0 else 1)
