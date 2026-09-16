extends SceneTree
## 第四关通关模拟：破臧霸占山为王
## 战术：张飞咆哮晕臧霸(破地利) → 许褚裸衣冲阵 → 关羽青龙斩集火
## 运行：godot --headless --script res://tests/test_ch4_flow.gd

const GridCore := preload("res://scripts/core/grid.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")
const BattleUnitScript := preload("res://scripts/entities/unit.gd")

var all_units := []
var turn := 1
var hills: Array[Vector2i] = []

func _init() -> void:
	print("==== 第四关通关模拟开始 ====")
	_setup()
	_run_simulation()

func _setup() -> void:
	# 高地（对应 chapter4）
	for h in [[7,3],[8,3],[9,3],[8,4],[9,4],[10,4]]:
		hills.append(Vector2i(h[0], h[1]))
	all_units.append(BattleUnitScript.from_data(_unit_def("liubei"), Vector2i(1, 4)))
	all_units.append(BattleUnitScript.from_data(_unit_def("guanyu"), Vector2i(2, 5)))
	all_units.append(BattleUnitScript.from_data(_unit_def("zhangfei"), Vector2i(1, 6)))
	all_units.append(BattleUnitScript.from_data(_unit_def("zhaoyun"), Vector2i(2, 3)))
	all_units.append(BattleUnitScript.from_data(_unit_def("xuchu"), Vector2i(0, 5)))
	all_units.append(BattleUnitScript.from_data(_unit_def("gongsunzan"), Vector2i(0, 4)))
	# 敌方
	var zb = BattleUnitScript.from_data(_unit_def("zangba"), Vector2i(9, 3))
	zb.on_hill = true  # 占山
	all_units.append(zb)
	all_units.append(BattleUnitScript.from_data(_unit_def("changxi"), Vector2i(8, 4)))
	all_units.append(BattleUnitScript.from_data(_unit_def("taishan_1"), Vector2i(9, 5)))
	all_units.append(BattleUnitScript.from_data(_unit_def("taishan_2"), Vector2i(7, 2)))
	all_units.append(BattleUnitScript.from_data(_unit_def("taishan_3"), Vector2i(10, 6)))

func _run_simulation() -> void:
	var max_turn := 50
	while turn <= max_turn:
		# 敌方回合
		for u in all_units:
			if u.camp == "enemy" and u.alive and not u.is_stunned():
				var target = _nearest_player(u)
				if target:
					var d := GridCore.chebyshev(u.cell, target.cell)
					if d <= u.rng:
						_handle(SkillsCore.do_attack(u, target))
		for u in all_units:
			u.end_turn()
		if _player_alive().size() == 0:
			print("[FAIL] 我方全灭")
			quit(1); return
		turn += 1
		var zangba = _unit("zangba")
		if not zangba.alive:
			print("[OK] ✅ 第四关通关：泰山贼平！经历 %d 回合" % turn); quit(0); return
		_do_player_turn(zangba)
		if not zangba.alive:
			print("[OK] ✅ 第四关通关：泰山贼平！经历 %d 回合" % turn); quit(0); return
	print("[FAIL] %d回合未通关" % max_turn); quit(1)

func _do_player_turn(zangba) -> void:
	var guanyu = _unit("guanyu")
	if guanyu and guanyu.alive and zangba.alive:
		if guanyu.charge < 10:
			guanyu.charge = 10
		elif GridCore.chebyshev(guanyu.cell, zangba.cell) <= 8:
			_handle(SkillsCore.do_dragon_slash(guanyu, zangba))
	var zhangfei = _unit("zhangfei")
	if zhangfei and zhangfei.alive and zangba.alive and not zangba.is_stunned():
		zhangfei.charge = 3
		_handle(SkillsCore.do_roar(zhangfei, [zangba]))
		if not zangba.alive: return
	var xuchu = _unit("xuchu")
	if xuchu and xuchu.alive and zangba.alive:
		if not xuchu.lifesteal_active:
			SkillsCore.do_naked_armor(xuchu, all_units)
		_handle(SkillsCore.do_naked_strike(xuchu, zangba))
	var zhaoyun = _unit("zhaoyun")
	if zhaoyun and zhaoyun.alive and zangba.alive:
		_handle(SkillsCore.do_seven_dash(zhaoyun, zangba, 3))
	var gongsun = _unit("gongsunzan")
	if gongsun and gongsun.alive and zangba.alive and gongsun.skill_ready("arrow_rain"):
		_handle(SkillsCore.do_arrow_rain(gongsun, zangba, all_units))

func _handle(events: Array) -> void:
	for ev in events:
		if ev.get("type") == "death":
			var t = _unit(ev.target)
			if t: print("  [回合%d] %s 被击败" % [turn, t.name])

func _nearest_player(u):
	var best = null
	var best_d := 9999
	for p in all_units:
		if p.camp == "player" and p.alive:
			var d := GridCore.manhattan(u.cell, p.cell)
			if d < best_d: best_d = d; best = p
	return best

func _player_alive() -> Array:
	var out: Array = []
	for u in all_units:
		if u.camp == "player" and u.alive: out.append(u)
	return out

func _unit(id: String):
	for u in all_units:
		if u.id == id: return u
	return null

func _unit_def(id: String) -> Dictionary:
	var f := FileAccess.open("res://data/units.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	for d in parsed["units"]:
		if d["id"] == id: return d
	return {}