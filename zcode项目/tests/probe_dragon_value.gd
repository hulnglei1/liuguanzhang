extends SceneTree
## 关羽蓄力「价值闭环」验证
##  1. 数值：满档到底能不能定胜负（单独 / 骑赵云合击）
##  2. 嘲讽：关羽蓄力时敌军是否真的会改目标扑他
## 运行：Godot_console.exe --headless --path zcode项目 --script res://tests/probe_dragon_value.gd

const CombatCore := preload("res://scripts/core/combat.gd")
const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")

const ATK := 30          # 关羽攻击
const COMBO := 1.5       # 关羽骑赵云双子合击倍率

var targets := [
	["华雄", 90], ["昌豨", 180], ["徐荣", 220], ["臧霸", 240],
	["吕布", 260], ["许褚", 280], ["典韦", 300],
]


func _initialize() -> void:
	print("\n==== 一、满蓄力价值验证（关羽 atk=30） ====")
	for c in [10, 15, 20]:
		var mult := CombatCore.dragon_charge_multiplier(c)
		print("  %2d 格 · %-22s 倍率 %.2fx → %d 伤害" % [c, CombatCore.dragon_charge_tier(c)["name"], mult, int(ATK * mult)])

	var solo: int = int(ATK * CombatCore.dragon_charge_multiplier(20))
	var combo: int = int(solo * COMBO)
	print("\n  骑赵云 20 格：单独 %d 伤害；双子合击 1.5x → %d 伤害\n" % [solo, combo])
	print("  %-6s %-6s %-16s %-16s" % ["目标", "HP", "单独20格", "骑赵云合击"])
	for t in targets:
		var name: String = t[0]
		var hp: int = t[1]
		print("  %-6s %-6d %-16s %-16s" % [name, hp, _verdict(solo, hp), _verdict(combo, hp)])

	_run_scene_check()


func _verdict(dmg: int, hp: int) -> String:
	if dmg >= hp:
		return "✅ 秒杀"
	return "削 %d%%" % int(float(dmg) / float(hp) * 100.0)


func _run_scene_check() -> void:
	var s: Dictionary = SaveCore.load_state()
	s["chapters"] = ["chapter1"]
	s["prologues_seen"] = ["chapter1", "chapter2"]
	SaveCore.save_state(s)
	BattleScript.chapter_id = "chapter2"
	change_scene_to_file("res://scenes/battle.tscn")
	await create_timer(2.5).timeout

	var b = current_scene
	if b.has_method("_on_dialog_skip_pressed"):
		b._on_dialog_skip_pressed()
	await create_timer(0.6).timeout

	var gy = b._unit_by_id("guanyu")
	var lb = b._unit_by_id("lubu")
	print("\n==== 二、蓄力嘲讽验证（敌军目标选择） ====")
	# 先让关羽躲到角落，制造"他本来不是任何人的最近目标"的局面，才能验证出嘲讽是否生效
	gy.cell = Vector2i(0, 0)
	gy.charge = 0
	var t0 = b._pick_enemy_target(lb)
	print("  [蓄力 0 / 关羽躲远处] 吕布 → %s（应为我方其他人，不该是关羽）" % (t0.id if t0 else "无"))
	gy.charge = 6
	var t2 = b._pick_enemy_target(lb)
	print("  [蓄力 6 / 距离超 6 格] 吕布 → %s（超出吸引半径，仍打最近的）" % (t2.id if t2 else "无"))
	gy.charge = 12
	var all_pull := true
	var detail: Array[String] = []
	for u in b.units:
		if u.camp == "enemy":
			var t = b._pick_enemy_target(u)
			detail.append("%s→%s" % [u.id, t.id if t else "无"])
			if t == null or t.id != "guanyu":
				all_pull = false
	print("  [蓄力 12] 全军目标：", ", ".join(detail))
	print("  [蓄力 12] 全军扑关羽？", "✅ 是（这一刀能清场，所以他们拼命来断）" if all_pull else "❌ 否")

	# 合体护航：首次受击不清零
	print("\n==== 三、合体护航验证 ====")
	var zy = b._unit_by_id("zhaoyun")
	if gy and zy:
		gy.cell = Vector2i(zy.cell.x + 1, zy.cell.y)
		b.selected_id = "guanyu"
		b._cmd_mount(zy)
		await create_timer(0.4).timeout
		print("  合体状态：", gy.is_mounted(), " 蓄力上限：", CombatCore.dragon_charge_cap(gy.is_mounted()))
		gy.charge = 12
		# 模拟第一次挨打
		b._apply_events([{"type": "damage", "target": "guanyu", "value": 10}])
		await create_timer(0.3).timeout
		print("  第 1 次受击后蓄力 = %d（护航生效应为 12）" % gy.charge)
		b._apply_events([{"type": "damage", "target": "guanyu", "value": 10}])
		await create_timer(0.3).timeout
		print("  第 2 次受击后蓄力 = %d（应为 0，每关只保一次）" % gy.charge)

	quit(0)
