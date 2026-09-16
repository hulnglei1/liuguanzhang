extends SceneTree

const BattleUnitScript := preload("res://scripts/entities/unit.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")
const CombatCore := preload("res://scripts/core/combat.gd")
const MoraleCore := preload("res://scripts/systems/morale.gd")

func _init() -> void:
	print("==================================================")
	print("【TEST】开始验证前四关（Chapter 1~4）核心绝技与机制...")
	print("==================================================")
	var passed := 0
	var failed := 0

	# ----------------------------------------------------
	# 1. 测试赵云【无限耐力】：牛马神技自愈 15% HP
	# ----------------------------------------------------
	var zhaoyun = BattleUnitScript.from_data({
		"id": "zhaoyun", "name": "赵云", "cls": "枪骑", "camp": "player",
		"hp": 120, "atk": 25, "def": 12, "mov": 6, "rng": 1, "skills": ["seven_dash"]
	}, Vector2i(2, 3))
	zhaoyun.hp = 60 # 受伤半血
	var healed = zhaoyun.heal_percent(0.15)
	if healed == 18 and zhaoyun.hp == 78:
		print("  [PASS] 赵云无限耐力：成功自愈 15% 最大HP (120*0.15=18, 60->78)")
		passed += 1
	else:
		printerr("  [FAIL] 赵云无限耐力自愈异常: healed=%d, hp=%d" % [healed, zhaoyun.hp])
		failed += 1

	# ----------------------------------------------------
	# 2. 测试关羽骑赵云：移除2x蓄力，普攻双子合击（1.5倍伤害）
	# ----------------------------------------------------
	var guanyu = BattleUnitScript.from_data({
		"id": "guanyu", "name": "关羽", "cls": "骑兵", "camp": "player",
		"hp": 150, "atk": 30, "def": 15, "mov": 5, "rng": 1, "skills": ["dragon_slash"]
	}, Vector2i(2, 5))
	var dummy_enemy = BattleUnitScript.from_data({
		"id": "enemy_1", "name": "董卓军", "cls": "步兵", "camp": "enemy",
		"hp": 100, "atk": 20, "def": 10, "mov": 3, "rng": 1, "skills": []
	}, Vector2i(2, 6))

	# 蓄力效率必须为 1（移除 2x）
	if SkillsCore.mounted_charge_efficiency() == 1:
		print("  [PASS] 关羽骑赵云蓄力效率已平准化为 1:1（移除 2x 超模）")
		passed += 1
	else:
		printerr("  [FAIL] 蓄力效率不为 1: %d" % SkillsCore.mounted_charge_efficiency())
		failed += 1

	# 未合体时普通攻击：30 * 1.0 - 10 = 20 伤害
	var normal_ev = SkillsCore.do_attack(guanyu, dummy_enemy)
	var normal_dmg = normal_ev[0].value
	if normal_dmg == 20 and dummy_enemy.hp == 80:
		print("  [PASS] 未合体关羽普攻：伤害 20 正确")
		passed += 1
	else:
		printerr("  [FAIL] 未合体普攻伤害错误: %d" % normal_dmg)
		failed += 1

	# 合体（关羽骑赵云）：普攻双子合击（1.5倍伤害：30 * 1.5 - 10 = 35 伤害）
	SkillsCore.do_mount(guanyu, zhaoyun)
	var mounted_ev = SkillsCore.do_attack(guanyu, dummy_enemy)
	var mounted_dmg = mounted_ev[0].value
	if mounted_dmg == 35 and dummy_enemy.hp == 45:
		print("  [PASS] 合体双子合击（关羽刀劈+赵云长枪）：伤害 35（1.5倍）正确")
		passed += 1
	else:
		printerr("  [FAIL] 合体双子合击伤害错误: %d, hp=%d" % [mounted_dmg, dummy_enemy.hp])
		failed += 1
	SkillsCore.do_unmount(guanyu, zhaoyun)

	# ----------------------------------------------------
	# 3. 测试吕布【方天乱舞第3击 3倍重击 + 两息铁皮无敌】
	# ----------------------------------------------------
	var lubu = BattleUnitScript.from_data({
		"id": "lubu", "name": "吕布", "cls": "骑兵", "camp": "enemy",
		"hp": 200, "atk": 40, "def": 20, "mov": 5, "rng": 1, "skills": ["lubu_fangtian"],
		"is_commander": true
	}, Vector2i(5, 5))
	var target_hero = BattleUnitScript.from_data({
		"id": "hero", "name": "刘备", "cls": "步兵", "camp": "player",
		"hp": 300, "atk": 25, "def": 10, "mov": 4, "rng": 1, "skills": []
	}, Vector2i(5, 6))

	# 击 1
	SkillsCore.do_lubu_attack(lubu, target_hero)
	# 击 2
	SkillsCore.do_lubu_attack(lubu, target_hero)
	if not lubu.iron_skin and lubu.combo_strikes == 2:
		print("  [PASS] 吕布方天乱舞第 1、2 击正常连击累积")
		passed += 1
	else:
		printerr("  [FAIL] 吕布前两击状态异常")
		failed += 1

	# 击 3：翻3倍并激活铁皮无敌
	var hp_before_3rd = target_hero.hp
	var third_ev = SkillsCore.do_lubu_attack(lubu, target_hero)
	var third_dmg = hp_before_3rd - target_hero.hp
	# 伤害应为 40*3 - 10 = 110
	if third_dmg == 110 and lubu.iron_skin and lubu.combo_strikes == 0:
		print("  [PASS] 吕布方天乱舞第 3 击打出 3 倍重击 (%d)，激活两息铁皮无敌，连击归零" % third_dmg)
		passed += 1
	else:
		printerr("  [FAIL] 吕布第3击异常: dmg=%d, iron_skin=%s, combo=%d" % [third_dmg, str(lubu.iron_skin), lubu.combo_strikes])
		failed += 1

	# ----------------------------------------------------
	# 4. 测试两息铁皮状态：物理攻击伤害判定为 0
	# ----------------------------------------------------
	var lubu_hp_before = lubu.hp
	var attack_on_iron_skin = SkillsCore.do_attack(guanyu, lubu)
	if attack_on_iron_skin[0].value == 0 and lubu.hp == lubu_hp_before:
		print("  [PASS] 吕布铁皮无敌生效：受到伤害强制为 0，生命毫发无损 (%d/%d)" % [lubu.hp, lubu.max_hp])
		passed += 1
	else:
		printerr("  [FAIL] 铁皮无敌未能免疫伤害: ev_val=%d, hp=%d" % [attack_on_iron_skin[0].value, lubu.hp])
		failed += 1

	# ----------------------------------------------------
	# 5. 测试张飞【燕人战吼】克制闭环：吼晕吕布并震碎铁皮无敌
	# ----------------------------------------------------
	var zhangfei = BattleUnitScript.from_data({
		"id": "zhangfei", "name": "张飞", "cls": "骑兵", "camp": "player",
		"hp": 140, "atk": 32, "def": 14, "mov": 5, "rng": 1, "skills": ["roar"]
	}, Vector2i(5, 4))
	var roar_ev = SkillsCore.do_roar(zhangfei, [lubu])
	if lubu.is_stunned() and not lubu.iron_skin and lubu.combo_strikes == 0:
		print("  [PASS] 张飞燕人战吼克制闭环：吕布被眩晕，铁皮被震碎 (iron_skin=false)，连击被掐灭")
		passed += 1
	else:
		printerr("  [FAIL] 战吼破铁皮异常: stunned=%s, iron_skin=%s" % [str(lubu.is_stunned()), str(lubu.iron_skin)])
		failed += 1

	# ----------------------------------------------------
	# 6. 测试汜水关城门崩塌机制（敌军 DEF-20%）
	# ----------------------------------------------------
	var huaxiong = BattleUnitScript.from_data({
		"id": "huaxiong", "name": "华雄", "cls": "骑兵", "camp": "enemy",
		"hp": 180, "atk": 35, "def": 20, "mov": 5, "rng": 1, "skills": ["hua_rage"],
		"is_commander": true
	}, Vector2i(10, 4))
	var base_def_huaxiong = huaxiong.effective_def() # 20
	huaxiong.gate_broken_debuff = true
	var debuffed_def = huaxiong.effective_def() # 20 * 0.8 = 16
	if base_def_huaxiong == 20 and debuffed_def == 16:
		print("  [PASS] 汜水关城门崩塌防线溃乱：华雄防御成功降低 20%% (20 -> 16)")
		passed += 1
	else:
		printerr("  [FAIL] 破门防御减免异常: base=%d, debuffed=%d" % [base_def_huaxiong, debuffed_def])
		failed += 1

	# ----------------------------------------------------
	# 7. 测试动态士气系统（平滑线性修正 0.50 ~ 1.50）
	# ----------------------------------------------------
	var m100 = CombatCore.morale_multiplier(100) # 1.0
	var m130 = CombatCore.morale_multiplier(130) # 1.15
	var m70 = CombatCore.morale_multiplier(70)   # 0.85
	var m0 = CombatCore.morale_multiplier(0)     # 0.50
	var m150 = CombatCore.morale_multiplier(150) # 1.25
	if is_equal_approx(m100, 1.0) and is_equal_approx(m130, 1.15) and is_equal_approx(m70, 0.85) and is_equal_approx(m0, 0.5) and is_equal_approx(m150, 1.25):
		print("  [PASS] 动态士气倍率计算精确: 100->1.00, 130->1.15, 70->0.85, 0->0.50, 150->1.25")
		passed += 1
	else:
		printerr("  [FAIL] 士气倍率计算有偏差: m100=%.2f, m130=%.2f, m70=%.2f" % [m100, m130, m70])
		failed += 1

	# 验证应用士气至单位
	huaxiong.gate_broken_debuff = false
	MoraleCore.apply_morale([huaxiong], 130)
	if huaxiong.effective_atk() == int(round(35.0 * 1.15)) and huaxiong.effective_def() == int(round(20.0 * 1.15)):
		print("  [PASS] 士气动态提升敌军攻防（ATK 35->%d, DEF 20->%d）" % [huaxiong.effective_atk(), huaxiong.effective_def()])
		passed += 1
	else:
		printerr("  [FAIL] 士气修正未能正确改变单位实际攻防")
		failed += 1

	print("==================================================")
	print("【TEST SUMMARY】通过: %d, 失败: %d" % [passed, failed])
	print("==================================================")
	if failed == 0:
		print(">>> ALL CHAPTER 1~4 NOVEL MECHANICS TESTS PASSED! <<<")
		quit(0)
	else:
		quit(1)
