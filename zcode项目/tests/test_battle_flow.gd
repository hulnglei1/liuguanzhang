extends SceneTree
## 无头战斗流程模拟测试：验证「蓄力龙斩秒华雄」核心循环
## 运行：godot --headless --script res://tests/test_battle_flow.gd

const GridCore := preload("res://scripts/core/grid.gd")
const CombatCore := preload("res://scripts/core/combat.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")
const BattleUnitScript := preload("res://scripts/entities/unit.gd")

func _init() -> void:
	print("==== 战斗流程模拟开始 ====")
	var failed := 0

	# 1. 构造关羽和华雄
	var guanyu = BattleUnitScript.from_data(_unit_def("guanyu"), Vector2i(0, 0))
	var huaxiong = BattleUnitScript.from_data(_unit_def("huaxiong"), Vector2i(5, 5))

	# 2. 关羽绕场跑 10 格（蓄力）
	for i in range(10):
		guanyu.cell = Vector2i(i, 0)
		guanyu.charge += 1
	print("[模拟] 关羽蓄力: %d/10" % guanyu.charge)
	if guanyu.charge != 10:
		print("[FAIL] 蓄力应为10，实际 ", guanyu.charge)
		failed += 1

	# 3. 华雄叠层（拖了5回合）—— ATK 26×1.75=45.5，round 后 46
	huaxiong.hua_kills = 5
	var hua_atk: int = huaxiong.effective_atk()
	print("[模拟] 华雄斩将 5 层后 攻击 = %d（每层+20%%）" % hua_atk)
	if hua_atk != int(round(huaxiong.base_atk * CombatCore.hua_boost_multiplier(5))):
		print("[FAIL] 华雄斩将 5 层后攻击应为 %d，实际 %d" % [
			int(round(huaxiong.base_atk * CombatCore.hua_boost_multiplier(5))), hua_atk])
		failed += 1

	# 4. 关羽满蓄力龙斩
	var events := SkillsCore.do_dragon_slash(guanyu, huaxiong)
	print("[模拟] 龙斩事件: ", events)
	# 满蓄力应触发 full 特效
	var has_full := false
	var death := false
	for ev in events:
		if ev.get("type") == "fx" and ev.get("fx") == "dragon_full_screen":
			has_full = true
		if ev.get("type") == "death":
			death = true
	if not has_full:
		print("[FAIL] 满蓄力应触发 dragon_full_screen 特效")
		failed += 1
	if not death:
		print("[FAIL] 华雄应被秒杀")
		failed += 1
	else:
		print("[OK] 满蓄力龙斩一刀秒杀华雄 ✅")

	# 5. 满蓄力伤害数值验证：ATK30 × 3.5 − DEF10 = 95
	var dmg: int = CombatCore.damage(30, 3.5, 10)
	if dmg != 95:
		print("[FAIL] 满蓄力伤害应为95，实际 ", dmg)
		failed += 1
	else:
		print("[OK] 满蓄力伤害 95 ✅")

	# 6. 蓄力不足时（charge=3）倍率 0.5+0.9=1.4
	if abs(CombatCore.dragon_charge_multiplier(3) - 1.4) > 0.001:
		print("[FAIL] 蓄力3格倍率应为1.4")
		failed += 1
	else:
		print("[OK] 蓄力3格倍率 1.4 ✅")

	if failed == 0:
		print("==== 战斗流程全部通过 ✅ ====")
	else:
		print("==== 失败 ", failed, " 项 ❌ ====")
	quit(failed)

func _unit_def(id: String) -> Dictionary:
	var f := FileAccess.open("res://data/units.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	for d in parsed["units"]:
		if d["id"] == id:
			return d
	return {}
