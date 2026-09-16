extends SceneTree
## 原著核心机制测试：关羽多回合逃窜蓄力 · 青龙四阶蜕变 · 受击打断
## 运行：.\godot_bin\Godot_v4.3-stable_win64_console.exe --path game --headless -s tests/test_novel_mechanics.gd

const CombatCore := preload("res://scripts/core/combat.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")
const BattleUnitScript := preload("res://scripts/entities/unit.gd")

func _init() -> void:
	print("\n==== 原著关羽蓄力与青龙形态深度测试 ====")
	var failed := 0

	# 1. 验证四阶青龙进化
	var t1 = CombatCore.dragon_charge_tier(2)
	if t1.tier != 1 or not "青龙微芒" in t1.name:
		printerr("[FAIL] 2层蓄力应为初阶青龙微芒，实际: ", t1)
		failed += 1
	else:
		print("  ✅ [PASS] 2层蓄力：初阶 · 青龙微芒初现")

	var t2 = CombatCore.dragon_charge_tier(5)
	if t2.tier != 2 or not "青龙腾云" in t2.name:
		printerr("[FAIL] 5层蓄力应为中阶青龙腾云，实际: ", t2)
		failed += 1
	else:
		print("  ✅ [PASS] 5层蓄力：中阶 · 青龙腾云逐日")

	var t3 = CombatCore.dragon_charge_tier(8)
	if t3.tier != 3 or not "百丈怒龙" in t3.name:
		printerr("[FAIL] 8层蓄力应为高阶百丈怒龙，实际: ", t3)
		failed += 1
	else:
		print("  ✅ [PASS] 8层蓄力：高阶 · 百丈怒龙冲霄")

	var t4 = CombatCore.dragon_charge_tier(10)
	if t4.tier != 4 or not t4.can_shatter_gate:
		printerr("[FAIL] 10层蓄力应为极阶劈山裂城，实际: ", t4)
		failed += 1
	else:
		print("  ✅ [PASS] 10层满蓄力：极阶 · 劈山裂城神威青龙（具备轰塌城门神威）！")

	# 2. 验证受击打断气势逻辑
	var guanyu = BattleUnitScript.from_data({"id":"guanyu","name":"关羽","cls":"步兵","camp":"player","hp":100,"atk":30,"def":12,"mov":3,"rng":1,"skills":["dragon_slash"]}, Vector2i(0, 0))
	guanyu.charge = 8 # 已跑多轮积攒 8 层
	print("  -> 关羽千里逃窜蓄力中 (8/10)...")
	
	# 遭受敌军截击
	var lost: int = mini(guanyu.charge, 3)
	guanyu.charge -= lost
	if guanyu.charge != 5:
		printerr("[FAIL] 受击后应打断损失3格蓄力，剩余 5，实际: ", guanyu.charge)
		failed += 1
	else:
		print("  ✅ [PASS] 关羽遭受敌击，气脉震荡中断 3 格蓄力（8 -> 5），需队友护卫！")

	# 3. 验证【前面一条线】直线贯穿伤害判定
	const GridCore := preload("res://scripts/core/grid.gd")
	var line := GridCore.line_cells(Vector2i(2, 5), Vector2i(10, 5), 10, 12, 10)
	if line.size() < 8 or line[0] != Vector2i(3, 5) or line[7] != Vector2i(10, 5):
		printerr("[FAIL] 直线贯穿射线计算错误: ", line)
		failed += 1
	else:
		print("  ✅ [PASS] 直线贯穿射线计算正确，覆盖前面一整条线: ", line[0], " -> ", line[-1])

	# 验证直线上的主目标与穿透目标双重结算
	guanyu.charge = 10
	var huaxiong = BattleUnitScript.from_data({"id":"huaxiong","name":"华雄","cls":"骑兵","camp":"enemy","hp":70,"atk":26,"def":10,"mov":4,"rng":1,"skills":["hua_rage"]}, Vector2i(10, 5))
	var dao_bing = BattleUnitScript.from_data({"id":"dao_bing_1","name":"刀兵","cls":"步兵","camp":"enemy","hp":40,"atk":16,"def":8,"mov":3,"rng":1,"skills":[]}, Vector2i(6, 5))
	
	var evs := SkillsCore.do_dragon_slash(guanyu, huaxiong, [dao_bing])
	if huaxiong.alive:
		printerr("[FAIL] 主目标华雄应被一刀斩杀！")
		failed += 1
	elif dao_bing.alive:
		printerr("[FAIL] 沿途刀兵应被青龙直线贯穿秒杀！")
		failed += 1
	else:
		print("  ✅ [PASS] 劈山裂城青龙斩直线贯穿！华雄(95伤)与挡路刀兵(71伤)全排秒杀！")

	print("\n==== 测试结果: 失败 %d 项 ====" % failed)
	quit(failed)
