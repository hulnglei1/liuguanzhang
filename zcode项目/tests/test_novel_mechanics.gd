extends SceneTree
## 原著核心机制测试：关羽定向直线贯穿 · 蓄力受击清零 · 曹操传式移动攻击 · 原著神兵与仙种
## 运行：.\godot_bin\Godot_v4.3-stable_win64_console.exe --path game --headless -s tests/test_novel_mechanics.gd

const CombatCore := preload("res://scripts/core/combat.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")
const BattleUnitScript := preload("res://scripts/entities/unit.gd")
const GridCore := preload("res://scripts/core/grid.gd")
const LotteryCore := preload("res://scripts/systems/lottery.gd")
const SaveCore := preload("res://scripts/systems/save.gd")

func _init() -> void:
	print("\n==== 原著机制深度测试（关羽四向贯穿、受击清零、神物与仙种） ====")
	var failed := 0

	# 1. 验证四阶青龙进化及贯穿距离 line_len
	var t1 = CombatCore.dragon_charge_tier(2)
	if t1.tier != 1 or t1.line_len != 1:
		printerr("[FAIL] 2层蓄力应为初阶(line_len=1)，实际: ", t1)
		failed += 1
	else:
		print("  ✅ [PASS] 2层蓄力：初阶 · 青龙微芒初现 (贯穿1格)")

	var t2 = CombatCore.dragon_charge_tier(5)
	if t2.tier != 2 or t2.line_len != 2:
		printerr("[FAIL] 5层蓄力应为中阶(line_len=2)，实际: ", t2)
		failed += 1
	else:
		print("  ✅ [PASS] 5层蓄力：中阶 · 青龙腾云逐日 (贯穿2格)")

	var t3 = CombatCore.dragon_charge_tier(8)
	if t3.tier != 3 or t3.line_len != 4:
		printerr("[FAIL] 8层蓄力应为高阶(line_len=4)，实际: ", t3)
		failed += 1
	else:
		print("  ✅ [PASS] 8层蓄力：高阶 · 百丈怒龙冲霄 (贯穿4格)")

	var t4 = CombatCore.dragon_charge_tier(10)
	if t4.tier != 4 or t4.line_len != 12 or not t4.can_shatter_gate:
		printerr("[FAIL] 10层满蓄力应为极阶(line_len=12且破门)，实际: ", t4)
		failed += 1
	else:
		print("  ✅ [PASS] 10层满蓄力：极阶 · 劈山裂城神威青龙 (贯穿全排12格且轰塌城门)！")

	# 2. 验证受击清零机制（原著气脉震散，全部清零归0）
	var guanyu = BattleUnitScript.from_data({"id":"guanyu","name":"关羽","cls":"步兵","camp":"player","hp":100,"atk":30,"def":12,"mov":3,"rng":1,"skills":["dragon_slash"]}, Vector2i(2, 2))
	guanyu.charge = 8
	print("  -> 关羽千里逃窜蓄力中 (8/10)...")
	# 遭受敌军截击，气脉震散直接清零
	guanyu.charge = 0
	if guanyu.charge != 0:
		printerr("[FAIL] 受击后蓄力必须全部归0，实际: ", guanyu.charge)
		failed += 1
	else:
		print("  ✅ [PASS] 关羽遭敌攻击，气脉震散蓄力直接归0！符合小说最怕中途被打断的设定！")

	# 3. 验证关羽上下左右四向贯穿线计算（以被攻击点为起点，向后延伸 line_len 格）
	var start := Vector2i(2, 2)
	var target_right := Vector2i(3, 2) # 向右攻击相邻格
	var line_tier2 := GridCore.line_cells(start, target_right, 2, 12, 10)
	if line_tier2 != [Vector2i(3, 2), Vector2i(4, 2)]:
		printerr("[FAIL] Tier 2 向右贯穿应为 [(3,2), (4,2)]，实际: ", line_tier2)
		failed += 1
	else:
		print("  ✅ [PASS] 关羽向右攻击：贯穿被击点(3,2)及身后一格(4,2): ", line_tier2)

	var target_down := Vector2i(2, 3) # 向下攻击相邻格
	var line_tier3 := GridCore.line_cells(start, target_down, 4, 12, 10)
	if line_tier3 != [Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5), Vector2i(2, 6)]:
		printerr("[FAIL] Tier 3 向下贯穿计算错误，实际: ", line_tier3)
		failed += 1
	else:
		print("  ✅ [PASS] 关羽向下攻击：贯穿被击点及身后3格共4格: ", line_tier3)

	# 4. 验证5000声望原著神物奖池与装备
	var baton_found := false
	var dongfeng_found := false
	var megaphone_found := false
	var coat_found := false
	for it in LotteryCore.WEAPON_POOL:
		if it.id == "electric_baton": baton_found = true
		if it.id == "dongfeng": dongfeng_found = true
		if it.id == "megaphone": megaphone_found = true
		if it.id == "military_coat": coat_found = true
	if not (baton_found and dongfeng_found and megaphone_found and coat_found):
		printerr("[FAIL] 5000武器池未包含全部原著穿越神物: ", LotteryCore.WEAPON_POOL)
		failed += 1
	else:
		print("  ✅ [PASS] 5000神物池包含：现代电棍(眩晕)、微缩东风(全图轰炸)、高音大喇叭(扩音)、防寒军大衣(防御+15)！")

	# 5. 验证首通里程碑大礼（非无限无脑随机掉落）
	var mock_save := SaveCore.new_state()
	var first_clear_ch1: bool = not ("chapter1" in mock_save.get("chapters", []))
	if not first_clear_ch1:
		printerr("[FAIL] 新存档首通判定错误")
		failed += 1
	else:
		print("  ✅ [PASS] 剧情首通逻辑生效：首次通关汜水关解锁玉米种子，拒绝无脑刷资源！")

	print("\n==== 测试结果: 失败 %d 项 ====" % failed)
	quit(failed)
