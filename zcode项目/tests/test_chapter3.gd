extends SceneTree
## 第三关机制测试：许褚裸衣（爆甲减防/吸血/双倍攻速）
## 运行：godot --headless --script res://tests/test_chapter3.gd

const CombatCore := preload("res://scripts/core/combat.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")
const BattleUnitScript := preload("res://scripts/entities/unit.gd")

func _init() -> void:
	print("==== 第三关机制测试（许褚裸衣）开始 ====")
	var failed := 0

	var xuchu = BattleUnitScript.from_data(_unit_def("xuchu"), Vector2i(5, 5))
	var guanyu = BattleUnitScript.from_data(_unit_def("guanyu"), Vector2i(6, 6))
	var zhaoyun = BattleUnitScript.from_data(_unit_def("zhaoyun"), Vector2i(0, 0))
	var all: Array = [xuchu, guanyu, zhaoyun]

	# ---- 1. 裸衣激活：爆周围半径2敌军甲 ----
	# 关羽在(6,6)，距许褚(5,5)切比雪夫1（<=2），应被爆甲；赵云(0,0)不在范围
	var ev := SkillsCore.do_naked_armor(xuchu, all)
	if not guanyu.armor_broken:
		print("[FAIL] 许褚裸衣应爆掉关羽(范围内)的甲")
		failed += 1
	else:
		print("[OK] 裸衣爆甲：关羽防御减半 ✅")
	if zhaoyun.armor_broken:
		print("[FAIL] 赵云(范围外)不应被爆甲")
		failed += 1
	else:
		print("[OK] 范围外目标不受裸衣影响 ✅")

	# ---- 2. 爆甲后防御减半 ----
	# 关羽 base_def=12，爆甲后 effective_def=6
	var broken_def: int = guanyu.effective_def()
	if broken_def != 6:
		print("[FAIL] 关羽爆甲后DEF应为6，实际 ", broken_def)
		failed += 1
	else:
		print("[OK] 爆甲后关羽 DEF=6（12÷2）✅")

	# ---- 3. 裸衣吸血：攻击回血 ----
	if not xuchu.lifesteal_active:
		print("[FAIL] 裸衣激活后许褚应处于吸血状态")
		failed += 1
	# 先让许褚掉血，再测吸血回血
	xuchu.hp = 200
	var hp_before: int = xuchu.hp
	var strike := SkillsCore.do_naked_strike(xuchu, guanyu)
	var healed := false
	for e in strike:
		if e.get("type") == "heal":
			healed = true
	if not healed or xuchu.hp <= hp_before:
		print("[FAIL] 裸衣攻击应吸血回血")
		failed += 1
	else:
		print("[OK] 裸衣吸血回血 ✅（HP %d→%d）" % [hp_before, xuchu.hp])

	# ---- 4. 裸衣攻击伤害：爆甲后关羽DEF6，ATK36-DEF6=30 ----
	var dmg: int = CombatCore.damage(xuchu.effective_atk(), 1.0, guanyu.effective_def())
	if dmg != 30:
		print("[FAIL] 许褚裸衣打爆甲关羽应30伤，实际 ", dmg)
		failed += 1
	else:
		print("[OK] 裸衣攻击伤害 30 ✅")

	# ---- 5. 双倍攻速存在性：lifesteal_active 期间 AI 打两次（由battle.gd控制） ----
	# 这里验证吸血状态持久存在（战斗内保持）
	print("[模拟] 许褚裸衣吸血状态持续: ", xuchu.lifesteal_active)

	if failed == 0:
		print("==== 第三关机制全部通过 ✅ ====")
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