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
	# 7. 测试动态士气系统（滚雪球：每 1 点士气 = 1%，范围 0.40 ~ 2.00）
	# ----------------------------------------------------
	var m100 = CombatCore.morale_multiplier(100) # 1.0
	var m130 = CombatCore.morale_multiplier(130) # 1.30
	var m70 = CombatCore.morale_multiplier(70)   # 0.70
	var m0 = CombatCore.morale_multiplier(0)     # 0.40
	var m150 = CombatCore.morale_multiplier(150) # 1.50
	var m200 = CombatCore.morale_multiplier(200) # 2.00（打崩对面 = 全员双倍）
	if is_equal_approx(m100, 1.0) and is_equal_approx(m130, 1.30) and is_equal_approx(m70, 0.70) and is_equal_approx(m0, 0.4) and is_equal_approx(m150, 1.5) and is_equal_approx(m200, 2.0):
		print("  [PASS] 士气滚雪球倍率: 100->1.00, 130->1.30, 70->0.70, 0->0.40, 150->1.50, 200->2.00")
		passed += 1
	else:
		printerr("  [FAIL] 士气倍率计算有偏差: m100=%.2f, m130=%.2f, m70=%.2f" % [m100, m130, m70])
		failed += 1

	# 验证应用士气至单位
	huaxiong.gate_broken_debuff = false
	MoraleCore.apply_morale([huaxiong], 130)
	if huaxiong.effective_atk() == int(round(35.0 * 1.30)) and huaxiong.effective_def() == int(round(20.0 * 1.30)):
		print("  [PASS] 士气动态提升敌军攻防（ATK 35->%d, DEF 20->%d）" % [huaxiong.effective_atk(), huaxiong.effective_def()])
		passed += 1
	else:
		printerr("  [FAIL] 士气修正未能正确改变单位实际攻防")
		failed += 1

	# ----------------------------------------------------
	# 8. 测试武安国【巨力平准化与脱力机制】（杜绝开局单杀吕布）
	# ----------------------------------------------------
	var wuanguo = BattleUnitScript.from_data({
		"id": "wuanguo", "name": "武安国", "cls": "刀将", "camp": "player",
		"hp": 160, "atk": 30, "def": 12, "mov": 3, "rng": 1, "skills": ["wuanguo_power"]
	}, Vector2i(1, 1))
	# 攻击力平准化为 30 * 1.5 = 45（不再是崩坏的 90！）
	if wuanguo.effective_atk() == 45:
		print("  [PASS] 武安国重锤巨力平准化: ATK 30 -> 45 (1.5倍健康爆发，不喧宾夺主)")
		passed += 1
	else:
		printerr("  [FAIL] 武安国攻击力异常: %d" % wuanguo.effective_atk())
		failed += 1
	# 挥锤攻击后陷入脱力力竭状态（DEF -30%）
	SkillsCore.do_attack(wuanguo, dummy_enemy)
	if wuanguo.exhausted and wuanguo.effective_def() == int(round(12.0 * 0.7)): # 8
		print("  [PASS] 武安国挥锤后脱力力竭生效: exhausted=true, DEF 12 -> %d" % wuanguo.effective_def())
		passed += 1
	else:
		printerr("  [FAIL] 武安国脱力未生效: exhausted=%s, def=%d" % [str(wuanguo.exhausted), wuanguo.effective_def()])
		failed += 1
	wuanguo.end_turn()
	if not wuanguo.exhausted and wuanguo.effective_def() == 12:
		print("  [PASS] 武安国回合结束恢复脱力: exhausted=false, DEF恢复为 12")
		passed += 1
	else:
		printerr("  [FAIL] 武安国脱力恢复失败")
		failed += 1

	# ----------------------------------------------------
	# 9. 测试许褚【裸衣死战】双向爆甲机制（原著红裤衩狂暴互秒）
	# ----------------------------------------------------
	var xuchu = BattleUnitScript.from_data({
		"id": "xuchu", "name": "许褚", "cls": "步将", "camp": "enemy",
		"hp": 280, "atk": 36, "def": 16, "mov": 3, "rng": 1, "skills": ["naked_armor"]
	}, Vector2i(5, 5))
	var player_soldier = BattleUnitScript.from_data({
		"id": "p_soldier", "name": "我军盾卫", "cls": "步兵", "camp": "player",
		"hp": 100, "atk": 20, "def": 14, "mov": 3, "rng": 1, "skills": []
	}, Vector2i(5, 6))
	SkillsCore.do_naked_armor(xuchu, [xuchu, player_soldier])
	# 检验双方均爆甲（DEF减半）
	if xuchu.armor_broken and player_soldier.armor_broken and xuchu.effective_def() == 8 and player_soldier.effective_def() == 7:
		print("  [PASS] 许褚裸衣双向爆甲: 许褚自身DEF 16->8，我方DEF 14->7，原著红裤衩狂暴对决成立")
		passed += 1
	else:
		printerr("  [FAIL] 裸衣双向爆甲异常: xuchu_broken=%s, def=%d; p_broken=%s, def=%d" % [
			str(xuchu.armor_broken), xuchu.effective_def(),
			str(player_soldier.armor_broken), player_soldier.effective_def()
		])
		failed += 1

	# ----------------------------------------------------
	# 10. 测试汜水关中轴关隘防线配置（x=10 设立关门，位于华雄身后）
	# ----------------------------------------------------
	var ch1_file = FileAccess.open("res://data/chapters/chapter1.json", FileAccess.READ)
	var ch1_json = JSON.parse_string(ch1_file.get_as_text())
	var has_gate_at_10_4 := false
	for o in ch1_json["map"]["obstacles"]:
		if int(o["x"]) == 10 and int(o["y"]) == 4 and bool(o.get("is_gate", false)):
			has_gate_at_10_4 = true
			break
	if has_gate_at_10_4 and ch1_json["map"]["obstacles"].size() >= 5:
		print("  [PASS] 汜水关关隘配置合规: 设立城门 (10,4) 于华雄身后")
		passed += 1
	else:
		printerr("  [FAIL] 汜水关关门配置不符预期")
		failed += 1

	print("==================================================")
	print("【TEST SUMMARY】通过: %d, 失败: %d" % [passed, failed])
	print("==================================================")
	if failed == 0:
		print(">>> ALL CHAPTER 1~4 AUDITED MECHANICS TESTS PASSED! <<<")
		quit(0)
	else:
		quit(1)
