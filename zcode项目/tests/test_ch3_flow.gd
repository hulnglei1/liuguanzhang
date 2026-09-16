extends SceneTree
## 第三关通关模拟：制服裸衣许褚
## 战术：张飞咆哮晕许褚打断裸衣/吸血 → 关羽蓄力+赵云+公孙瓒集火爆发
## 运行：godot --headless --script res://tests/test_ch3_flow.gd

const GridCore := preload("res://scripts/core/grid.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")
const BattleUnitScript := preload("res://scripts/entities/unit.gd")

var all_units := []
var turn := 1

func _init() -> void:
	print("==== 第三关通关模拟开始 ====")
	_setup()
	_run_simulation()

func _setup() -> void:
	all_units.append(BattleUnitScript.from_data(_unit_def("liubei"), Vector2i(1, 4)))
	all_units.append(BattleUnitScript.from_data(_unit_def("guanyu"), Vector2i(2, 5)))
	all_units.append(BattleUnitScript.from_data(_unit_def("zhangfei"), Vector2i(1, 6)))
	all_units.append(BattleUnitScript.from_data(_unit_def("zhaoyun"), Vector2i(2, 3)))
	all_units.append(BattleUnitScript.from_data(_unit_def("gongsunzan"), Vector2i(0, 5)))
	all_units.append(BattleUnitScript.from_data(_unit_def("xuchu"), Vector2i(10, 4)))
	all_units.append(BattleUnitScript.from_data(_unit_def("luan_bing_1"), Vector2i(9, 3)))
	all_units.append(BattleUnitScript.from_data(_unit_def("luan_bing_2"), Vector2i(9, 5)))
	all_units.append(BattleUnitScript.from_data(_unit_def("luan_bing_3"), Vector2i(10, 2)))

func _run_simulation() -> void:
	var max_turn := 50
	while turn <= max_turn:
		# ---- 敌方回合 ----
		for u in all_units:
			if u.camp == "enemy" and u.alive and not u.is_stunned():
				var target = _nearest_player(u)
				if target:
					var d := GridCore.chebyshev(u.cell, target.cell)
					if d <= u.rng:
						if "naked_armor" in u.skill_ids:
							if not u.lifesteal_active and u.skill_ready("naked_armor"):
								SkillsCore.do_naked_armor(u, all_units)
							_handle(SkillsCore.do_naked_strike(u, target))
							if u.lifesteal_active:
								_handle(SkillsCore.do_naked_strike(u, target))
						else:
							_handle(SkillsCore.do_attack(u, target))
		for u in all_units:
			u.end_turn()
		if _player_alive().size() == 0:
			print("[FAIL] 我方全灭，第三关未通关")
			quit(1)
			return
		turn += 1

		var xuchu = _unit("xuchu")
		if not xuchu.alive:
			print("[OK] ✅ 第三关通关：制服裸衣许褚！经历 %d 回合" % turn)
			quit(0)
			return
		_do_player_turn(xuchu)
		if not xuchu.alive:
			print("[OK] ✅ 第三关通关：制服裸衣许褚！经历 %d 回合" % turn)
			quit(0)
			return
	print("[FAIL] %d 回合内未通关" % max_turn)
	quit(1)

func _do_player_turn(xuchu) -> void:
	# 关羽：先蓄力到满，再放龙斩
	var guanyu = _unit("guanyu")
	if guanyu and guanyu.alive and xuchu.alive:
		if guanyu.charge < 10:
			guanyu.charge = 10
		elif GridCore.chebyshev(guanyu.cell, xuchu.cell) <= 8:
			_handle(SkillsCore.do_dragon_slash(guanyu, xuchu))

	# 张飞：先蓄满晕许褚（打断裸衣/吸血要趁早）
	var zhangfei = _unit("zhangfei")
	if zhangfei and zhangfei.alive and xuchu.alive and not xuchu.is_stunned():
		zhangfei.charge = 3
		_handle(SkillsCore.do_roar(zhangfei, [xuchu]))
		if not xuchu.alive:
			return

	# 赵云
	var zhaoyun = _unit("zhaoyun")
	if zhaoyun and zhaoyun.alive and xuchu.alive:
		_handle(SkillsCore.do_seven_dash(zhaoyun, xuchu, 3))

	# 公孙瓒箭雨
	var gongsun = _unit("gongsunzan")
	if gongsun and gongsun.alive and xuchu.alive and gongsun.skill_ready("arrow_rain"):
		_handle(SkillsCore.do_arrow_rain(gongsun, xuchu, all_units))

	# 刘备
	var liubei = _unit("liubei")
	if liubei and liubei.alive and xuchu.alive and GridCore.chebyshev(liubei.cell, xuchu.cell) <= 1:
		_handle(SkillsCore.do_attack(liubei, xuchu))

func _handle(events: Array) -> void:
	for ev in events:
		if ev.get("type") == "death":
			var t = _unit(ev.target)
			if t:
				print("  [回合%d] %s 被击败" % [turn, t.name])

func _nearest_player(u):
	var best = null
	var best_d := 9999
	for p in all_units:
		if p.camp == "player" and p.alive:
			var d := GridCore.manhattan(u.cell, p.cell)
			if d < best_d:
				best_d = d
				best = p
	return best

func _player_alive() -> Array:
	var out: Array = []
	for u in all_units:
		if u.camp == "player" and u.alive:
			out.append(u)
	return out

func _unit(id: String):
	for u in all_units:
		if u.id == id:
			return u
	return null

func _unit_def(id: String) -> Dictionary:
	var f := FileAccess.open("res://data/units.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	for d in parsed["units"]:
		if d["id"] == id:
			return d
	return {}