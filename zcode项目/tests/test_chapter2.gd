extends SceneTree
## 第二关核心机制无头测试：吕布连击翻倍、暴怒、张飞咆哮控场
## 运行：godot --headless --script res://tests/test_chapter2.gd

const CombatCore := preload("res://scripts/core/combat.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")
const BattleUnitScript := preload("res://scripts/entities/unit.gd")

func _init() -> void:
	print("==== 第二关机制测试（吕布）开始 ====")
	var failed := 0

	var lubu = BattleUnitScript.from_data(_unit_def("lubu"), Vector2i(5, 5))
	var guanyu = BattleUnitScript.from_data(_unit_def("guanyu"), Vector2i(0, 0))
	var zhangfei = BattleUnitScript.from_data(_unit_def("zhangfei"), Vector2i(0, 4))
	var zhaoyun = BattleUnitScript.from_data(_unit_def("zhaoyun"), Vector2i(0, 2))

	# ---- 1. 吕布连击：第1、2击×1，第3击×3 ----
	# 第1击
	SkillsCore.do_lubu_attack(lubu, guanyu)
	print("[模拟] 吕布连击第1击：combo=%d" % lubu.combo_strikes)
	if lubu.combo_strikes != 1:
		print("[FAIL] 第1击 combo 应为1")
		failed += 1
	# 第2击
	SkillsCore.do_lubu_attack(lubu, guanyu)
	# 第3击（应×3）
	SkillsCore.do_lubu_attack(lubu, guanyu)
	print("[模拟] 吕布连击第3击：combo=%d，倍率有效" % lubu.combo_strikes)
	if lubu.combo_strikes != 3:
		print("[FAIL] 第3击 combo 应为3")
		failed += 1
	# 第3击伤害：effective_atk 已含×3。ATK34×3士气1=102-关羽DEF=90
	var third_dmg: int = CombatCore.damage(lubu.effective_atk(), 1.0, guanyu.effective_def())
	print("[模拟] 吕布第3击伤害 = %d（ATK34×3=102 − DEF12 = 90）" % third_dmg)
	if third_dmg != 90:
		print("[FAIL] 吕布第3击伤害应为90，实际 ", third_dmg)
		failed += 1
	else:
		print("[OK] 吕布第3击翻3倍 ✅")

	# ---- 2. 连击跨回合保留（越战越勇），被打晕才重置 ----
	lubu.end_turn()
	if lubu.combo_strikes != 3:
		print("[FAIL] 跨回合连击应保留（不清零），实际 ", lubu.combo_strikes)
		failed += 1
	else:
		print("[OK] 连击跨回合保留 ✅")

	# ---- 3. 张飞咆哮眩晕吕布（控场核心） ----
	var targets: Array = [lubu]
	SkillsCore.do_roar(zhangfei, targets)  # 基础咆哮，charge=0
	# 满蓄力咆哮（charge 3）眩晕吕布
	zhangfei.charge = 3
	var full_roar := SkillsCore.do_roar(zhangfei, targets)
	var lubu_stunned := false
	for ev in full_roar:
		if ev.get("type") == "stun" and ev.get("target") == "lubu":
			lubu_stunned = true
	if not lubu_stunned or not lubu.is_stunned():
		print("[FAIL] 满蓄力咆哮应眩晕吕布")
		failed += 1
	else:
		print("[OK] 张飞咆哮眩晕吕布 ✅（控场成功）")

	# ---- 4. 吕布被眩晕时伤害降低 / 无法连击 ----
	# 眩晕中 disabled：is_stunned 为 true
	if not lubu.is_stunned():
		print("[FAIL] 吕布应处于眩晕")
		failed += 1

	# ---- 5. 多打少暴怒：我方死一人 → 吕布×1.5 ----
	lubu.add_rage()
	print("[模拟] 吕布暴怒：rage_multiplier=%.1f" % lubu.rage_multiplier)
	if abs(lubu.rage_multiplier - 1.5) > 0.001:
		print("[FAIL] 吕布暴怒应×1.5")
		failed += 1
	else:
		print("[OK] 吕布多打少暴怒 ×1.5 ✅")

	# ---- 6. 关羽蓄满龙斩集火吕布 ----
	guanyu.charge = 10
	var slash := SkillsCore.do_dragon_slash(guanyu, lubu)
	var slash_full := false
	for ev in slash:
		if ev.get("type") == "fx" and ev.get("fx") == "dragon_full_screen":
			slash_full = true
	if not slash_full:
		print("[FAIL] 关羽满蓄力龙斩应触发全屏特效")
		failed += 1
	else:
		print("[OK] 关羽青龙斩集火吕布 ✅")

	if failed == 0:
		print("==== 第二关机制全部通过 ✅ ====")
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