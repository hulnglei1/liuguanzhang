extends SceneTree
## P0 修复验证：装备/被动生效 + 吕布连击跨回合 + 武安国三倍
## 运行：godot --headless --script res://tests/test_gear.gd

const BattleUnitScript := preload("res://scripts/entities/unit.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")

func _init() -> void:
	print("==== P0 修复验证（装备/连击/被动）开始 ====")
	var failed := 0

	# ---- 1. 装备加成：gear_def 进 DEF、gear_hp 进 HP、atk_pct ----
	var guanyu = BattleUnitScript.from_data(_unit_def("guanyu"), Vector2i(0, 0))
	guanyu.gear_def = 6
	guanyu.gear_hp = 40
	guanyu.apply_hp_gear()
	if guanyu.max_hp != 160 or guanyu.hp != 160:
		print("[FAIL] 装备+40血后 max_hp 应为160，实际 ", guanyu.max_hp)
		failed += 1
	else:
		print("[OK] 装备+40血生效 ✅")
	# DEF：base 12 + gear 6 = 18
	if guanyu.effective_def() != 18:
		print("[FAIL] gear_def+6 后 DEF 应为18，实际 ", guanyu.effective_def())
		failed += 1
	else:
		print("[OK] 装备+6防生效 ✅")
	# ATK pct：番薯种子 +10%
	guanyu.atk_pct_bonus = 1.1
	if guanyu.effective_atk() != 33:  # 30*1.1=33
		print("[FAIL] atk_pct 1.1 后 ATK 应为33，实际 ", guanyu.effective_atk())
		failed += 1
	else:
		print("[OK] 种子攻+10%生效 ✅")

	# ---- 2. 武安国被动「三倍巨力」生效 ----
	var wuanguo = BattleUnitScript.from_data(_unit_def("wuanguo"), Vector2i(0, 0))
	var wa_atk: int = wuanguo.effective_atk()
	if wa_atk != 90:  # 30*3=90
		print("[FAIL] 武安国三倍巨力 ATK 应为90，实际 ", wa_atk)
		failed += 1
	else:
		print("[OK] 武安国三倍巨力生效 ✅")

	# ---- 3. 吕布连击跨回合保留（不再清零）----
	var lubu = BattleUnitScript.from_data(_unit_def("lubu"), Vector2i(0, 0))
	SkillsCore.do_lubu_attack(lubu, guanyu)
	SkillsCore.do_lubu_attack(lubu, guanyu)
	SkillsCore.do_lubu_attack(lubu, guanyu)  # combo=3
	lubu.end_turn()
	if lubu.combo_strikes != 3:
		print("[FAIL] 连击应跨回合保留，实际 ", lubu.combo_strikes)
		failed += 1
	else:
		print("[OK] 连击跨回合保留（end_turn 不清零）✅")
	# 被打晕才重置
	lubu.fangtian_reset()
	if lubu.combo_strikes != 0:
		print("[FAIL] 被打晕应重置连击")
		failed += 1
	else:
		print("[OK] 被打晕重置连击 ✅")

	if failed == 0:
		print("==== P0 修复全部通过 ✅ ====")
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