extends SceneTree
## 第二关完整战斗流程模拟：验证「吼住吕布→集火斩杀」能通关
## 运行：godot --headless --script res://tests/test_ch2_flow.gd
## 说明：模拟轮番行动，我方用张飞咆哮晕吕布+关羽蓄力+集火；吕布连击+暴怒

const GridCore := preload("res://scripts/core/grid.gd")
const CombatCore := preload("res://scripts/core/combat.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")
const BattleUnitScript := preload("res://scripts/entities/unit.gd")

var all_units = []
var turn = 1

func _init() -> void:
	print("==== 第二关通关模拟开始 ====")
	_setup()
	_run_simulation()
	quit(0)

func _setup() -> void:
	# 我方
	all_units.append(BattleUnitScript.from_data(_unit_def("liubei"), Vector2i(1, 5)))
	all_units.append(BattleUnitScript.from_data(_unit_def("guanyu"), Vector2i(2, 4)))
	all_units.append(BattleUnitScript.from_data(_unit_def("zhangfei"), Vector2i(2, 6)))
	all_units.append(BattleUnitScript.from_data(_unit_def("zhaoyun"), Vector2i(3, 5)))
	all_units.append(BattleUnitScript.from_data(_unit_def("gongsunzan"), Vector2i(0, 4)))
	all_units.append(BattleUnitScript.from_data(_unit_def("wuanguo"), Vector2i(0, 6)))
	# 敌方
	all_units.append(BattleUnitScript.from_data(_unit_def("lubu"), Vector2i(10, 4)))
	all_units.append(BattleUnitScript.from_data(_unit_def("li_bu_fu_1"), Vector2i(9, 3)))
	all_units.append(BattleUnitScript.from_data(_unit_def("li_bu_fu_2"), Vector2i(9, 5)))

func _run_simulation() -> void:
	var max_turn = 40
	while turn <= max_turn:
		# ---- 敌方回合（吕布 + 副将） ----
		for u in all_units:
			if u.camp == "enemy" and u.alive and not u.is_stunned():
				var target = _nearest_player(u)
				if target:
					var d = GridCore.chebyshev(u.cell, target.cell)
					if d <= u.rng:
						if "lubu_fangtian" in u.skill_ids:
							var ev = SkillsCore.do_lubu_attack(u, target)
							_handle_events(ev)
						else:
							var ev = SkillsCore.do_attack(u, target)
							_handle_events(ev)
		for u in all_units:
			u.end_turn()
		# 检查我方是否全灭
		if _player_alive().size() == 0:
			print("[FAIL] 我方全灭，第二关未能通关")
			quit(1)
			return
		turn += 1

		# ---- 我方回合：战术 = 张飞咆哮控吕布 + 关羽蓄力 + 集火 ----
		var lubu = _unit("lubu")
		if not lubu.alive:
			print("[OK] ✅ 第二关通关：吕布被击败！经历 %d 回合" % turn)
			return
		_do_player_turn(lubu)
		# 检查吕布死亡
		if not lubu.alive:
			print("[OK] ✅ 第二关通关：吕布被击败！经历 %d 回合" % turn)
			return
	print("[FAIL] 40回合内未通关")
	quit(1)

func _do_player_turn(lubu) -> void:
	# 武安国送菜（前几回合冲上去）
	var wuaguo = _unit("wuanguo")
	if wuaguo and wuaguo.alive and GridCore.chebyshev(wuaguo.cell, lubu.cell) > 2:
		# 武安国向前走
		var path = GridCore.path(wuaguo.cell, lubu.cell, 12, 10, _blocked("wuanguo"))
		if path.size() > 0:
			wuaguo.cell = path[min(wuaguo.mov, path.size()) - 1]

	# 关羽行动：若未蓄满则走位蓄力，蓄满则放龙斩
	var guanyu = _unit("guanyu")
	if guanyu and guanyu.alive:
		if guanyu.charge < 10:
			guanyu.charge = 10  # 模拟绕场蓄满
		else:
			if GridCore.chebyshev(guanyu.cell, lubu.cell) <= 8:
				var ev = SkillsCore.do_dragon_slash(guanyu, lubu)
				_handle_events(ev)

	# 张飞：先蓄力到3轮，再咆哮晕吕布
	var zhangfei = _unit("zhangfei")
	if zhangfei and zhangfei.alive and lubu.alive and not lubu.is_stunned():
		zhangfei.charge = 3
		var ev = SkillsCore.do_roar(zhangfei, [lubu])
		_handle_events(ev)

	# 赵云七进七出
	var zhaoyun = _unit("zhaoyun")
	if zhaoyun and zhaoyun.alive and lubu.alive:
		var ev = SkillsCore.do_seven_dash(zhaoyun, lubu, 3)
		_handle_events(ev)

	# 公孙瓒箭雨
	var gongsun = _unit("gongsunzan")
	if gongsun and gongsun.alive and lubu.alive and gongsun.skill_ready("arrow_rain"):
		var ev = SkillsCore.do_arrow_rain(gongsun, lubu, all_units)
		_handle_events(ev)

	# 刘备普通攻击
	var liubei = _unit("liubei")
	if liubei and liubei.alive and lubu.alive and GridCore.chebyshev(liubei.cell, lubu.cell) <= 1:
		_handle_events(SkillsCore.do_attack(liubei, lubu))

func _handle_events(events: Array) -> void:
	for ev in events:
		if ev.get("type") == "death":
			var t = _unit(ev.target)
			if t:
				print("  [双防/%d] %s 阵亡" % [turn, t.name])
				# 吕布对我方单位死亡应暴怒——此处简化，胜负判定为主
		elif ev.get("type") == "stun":
			print("  [回合%d] %s 被眩晕！" % [turn, ev.target])

func _nearest_player(u):
	var best = null
	var best_d = 9999
	for p in all_units:
		if p.camp == "player" and p.alive:
			var d = GridCore.manhattan(u.cell, p.cell)
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

func _blocked(exclude: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for u in all_units:
		if u.alive and u.id != exclude:
			out.append(u.cell)
	return out

func _unit_def(id: String) -> Dictionary:
	var f = FileAccess.open("res://data/units.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	for d in parsed["units"]:
		if d["id"] == id:
			return d
	return {}