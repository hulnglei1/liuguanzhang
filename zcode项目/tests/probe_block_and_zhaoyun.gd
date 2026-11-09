extends SceneTree
## 格挡系统 + 赵云【常山铁壁】验收
##
## 格挡的原著依据：吕布「连忙格挡」挡张飞蛇矛；张飞「强行格挡」仍倒飞；
## 刘备挡住一击却「双腿瘫软」——**减伤有代价，不是免疫**。
## 关键限制：杂兵（def ≤ 8）永远不会格挡，否则"菜鸡普攻 × 格挡"会把战斗拖成互相挠痒。

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")
const CombatCore := preload("res://scripts/core/combat.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")

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
	print("\n===== 格挡 + 赵云铁壁 =====")

	# ---------- 1. 概率公式边界 ----------
	print("\n[1] block_chance 边界")
	_check(CombatCore.block_chance(32, 4) == 0.0, "打杂兵(def4) 永不格挡 → 0")
	_check(is_equal_approx(CombatCore.block_chance(32, 14), 0.11), "关羽32打吕布14 → 11%")
	_check(is_equal_approx(CombatCore.block_chance(12, 14), 0.21), "刘备12打吕布14 → 21%（弱者更容易被挡）")
	_check(CombatCore.block_chance(20, 60) <= 0.30, "上限不超过 30%")
	_check(CombatCore.block_chance(60, 9) >= 0.03, "下限不低于 3%")
	_check(CombatCore.apply_block(20) == 10, "格挡伤害减半（20→10）")
	_check(CombatCore.apply_block(1) == 1, "保底 1 点")

	# ---------- 2. 赵云铁壁 ----------
	print("\n[2] 赵云【常山铁壁】")
	var s: Dictionary = SaveCore.new_state()
	s["prologues_seen"] = ["chapter1", "chapter2"]
	SaveCore.save_state(s)
	# 赵云与吕布都在第 2 关（第 1 关没有这两个人）
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

	var zy = b._unit_by_id("zhaoyun")
	var lb = b._unit_by_id("liubei")
	_check(zy != null and lb != null, "赵云 / 刘备 就位")

	zy.hp = zy.max_hp
	zy.zhaoyun_guard_used = false
	var hp0: int = zy.hp
	var d1: int = zy.take_damage(100)
	print("  首次受击：扣 %d（HP %d → %d）" % [d1, hp0, zy.hp])
	_check(d1 == 70, "本回合首次受击减伤 30%（100→70）")
	var d2: int = zy.take_damage(100)
	print("  二次受击：扣 %d" % d2)
	_check(d2 == 100, "同回合第二次不再减伤")
	zy.end_turn()
	var d3: int = zy.take_damage(100)
	print("  新回合受击：扣 %d" % d3)
	_check(d3 == 70, "回合刷新后铁壁恢复")

	lb.hp = lb.max_hp
	var d4: int = lb.take_damage(100)
	_check(d4 == 100, "刘备没有铁壁，正常吃 100")

	# ---------- 3. 实战：杂兵打不出格挡，主将能挡 ----------
	print("\n[3] 实战门控（各打 200 次）")
	var gy = b._unit_by_id("guanyu")
	var dao = null
	var boss = null
	for u in b._camp_units("enemy"):
		if u.id.begins_with("li_bu_fu"):
			dao = u          # 吕布亲兵：def 8 → 不该格挡
		if u.id == "lubu":
			boss = u
	_check(gy != null and dao != null, "关羽 / 杂兵(吕布亲兵) 就位")

	var blocked_on_dao := 0
	if dao != null:
		for i in range(200):
			dao.hp = dao.max_hp
			dao.alive = true
			for ev in SkillsCore.do_attack(gy, dao):
				if str(ev.get("type", "")) == "blocked":
					blocked_on_dao += 1
	print("  关羽打杂兵 200 次，格挡 %d 次" % blocked_on_dao)
	_check(blocked_on_dao == 0, "杂兵一次都没挡住（割草不受影响）")

	# 华雄 def 10 → 概率极低；换一个高防单位（吕布 def 14）
	var lubu = boss
	var blocked_on_boss := 0
	var trials := 300
	if lubu != null:
		for i in range(trials):
			lubu.hp = lubu.max_hp
			lubu.alive = true
			for ev in SkillsCore.do_attack(gy, lubu):
				if str(ev.get("type", "")) == "blocked":
					blocked_on_boss += 1
		print("  关羽打高防目标 %d 次，格挡 %d 次（def=%d）" % [trials, blocked_on_boss, lubu.effective_def()])
		var expect := CombatCore.block_chance(gy.effective_atk(), lubu.effective_def())
		if expect > 0.0:
			_check(blocked_on_boss > 0, "高防单位会格挡（期望 %.0f%%）" % (expect * 100))
		else:
			_check(blocked_on_boss == 0, "该目标防御不足以格挡")

	# ---------- 4. 绝技不吃格挡 ----------
	print("\n[4] 绝技不受格挡")
	var zf = b._unit_by_id("zhangfei")
	var roar_blocked := 0
	if zf != null and dao != null:
		for i in range(50):
			dao.hp = dao.max_hp
			dao.alive = true
			for ev in SkillsCore.do_roar(zf, [dao], 6, []):
				if str(ev.get("type", "")) == "blocked":
					roar_blocked += 1
	_check(roar_blocked == 0, "咆哮（绝技）不吃格挡")

	print("\n===== %s =====" % ("全部通过 ✅" if failed == 0 else "失败 %d 项 ❌" % failed))
	SaveCore.save_state(SaveCore.new_state())
	quit(0 if failed == 0 else 1)
