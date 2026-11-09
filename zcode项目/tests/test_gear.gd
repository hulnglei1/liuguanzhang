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
	var base_hp: int = guanyu.max_hp          # 期望值从基础属性推算，不写死快照数字
	var base_def: int = guanyu.base_def
	var base_atk: int = guanyu.base_atk
	guanyu.gear_def = 6
	guanyu.gear_hp = 40
	guanyu.apply_hp_gear()
	if guanyu.max_hp != base_hp + 40 or guanyu.hp != base_hp + 40:
		print("[FAIL] 装备+40血后 max_hp 应为%d，实际 %d" % [base_hp + 40, guanyu.max_hp])
		failed += 1
	else:
		print("[OK] 装备+40血生效 ✅")
	# DEF：base 12 + gear 6 = 18
	if guanyu.effective_def() != base_def + 6:
		print("[FAIL] gear_def+6 后 DEF 应为%d，实际 %d" % [base_def + 6, guanyu.effective_def()])
		failed += 1
	else:
		print("[OK] 装备+6防生效 ✅")
	# ATK pct：番薯种子 +10%
	guanyu.atk_pct_bonus = 1.1
	if guanyu.effective_atk() != int(round(base_atk * 1.1)):
		print("[FAIL] atk_pct 1.1 后 ATK 应为%d，实际 %d" % [int(round(base_atk * 1.1)), guanyu.effective_atk()])
		failed += 1
	else:
		print("[OK] 种子攻+10%生效 ✅")

	# ---- 2. 武安国被动「重锤巨力」平准化为 1.5 倍生效 ----
	var wuanguo = BattleUnitScript.from_data(_unit_def("wuanguo"), Vector2i(0, 0))
	var wa_atk: int = wuanguo.effective_atk()
	if wa_atk != int(round(wuanguo.base_atk * 1.5)):  # 被动 1.5 倍（不写死快照值）
		print("[FAIL] 武安国重锤巨力 ATK 应为45，实际 ", wa_atk)
		failed += 1
	else:
		print("[OK] 武安国重锤巨力（1.5倍健康爆发）生效 ✅")

	# ---- 3. 吕布连击跨回合保留（第1、2击跨回合不清零，第3击打完循环重置）----
	var lubu = BattleUnitScript.from_data(_unit_def("lubu"), Vector2i(0, 0))
	SkillsCore.do_lubu_attack(lubu, guanyu)
	SkillsCore.do_lubu_attack(lubu, guanyu)  # combo=2
	lubu.end_turn()
	if lubu.combo_strikes != 2:
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