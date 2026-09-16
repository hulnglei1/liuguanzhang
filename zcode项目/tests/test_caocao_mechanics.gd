extends SceneTree
## 曹操传兵种机制与张飞原著战吼测试
## 验证：步兵八向（可斜打）、骑兵十字（不可斜打）、斜角白嫖防反击、张飞开局即吼无蓄力

const GridCore := preload("res://scripts/core/grid.gd")
const CombatCore := preload("res://scripts/core/combat.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")
const BattleUnitScript := preload("res://scripts/entities/unit.gd")

var total_fails: int = 0

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ [PASS] %s" % msg)
	else:
		total_fails += 1
		printerr("  ❌ [FAIL] %s" % msg)

func _init() -> void:
	print("\n==== 曹操传兵种攻防几何与张飞原著战吼测试 ====")

	# 1. 骑兵十字四向判定测试 (以 (3, 3) 为例)
	var center := Vector2i(3, 3)
	var cross_cells := [Vector2i(3, 2), Vector2i(3, 4), Vector2i(2, 3), Vector2i(4, 3)]
	var diag_cells := [Vector2i(2, 2), Vector2i(4, 4), Vector2i(2, 4), Vector2i(4, 2)]

	for c in cross_cells:
		_assert(GridCore.can_attack(center, c, true, 1), "骑兵正向十字格子合法: %s" % str(c))
	for c in diag_cells:
		_assert(not GridCore.can_attack(center, c, true, 1), "骑兵斜向格子被严密拦截: %s" % str(c))

	# 2. 步兵九宫八向判定测试
	for c in cross_cells:
		_assert(GridCore.can_attack(center, c, false, 1), "步兵正向格子合法: %s" % str(c))
	for c in diag_cells:
		_assert(GridCore.can_attack(center, c, false, 1), "步兵斜向格子合法（支持斜打）: %s" % str(c))

	var distant_cell := Vector2i(3, 5)
	_assert(not GridCore.can_attack(center, distant_cell, false, 1), "步兵距离超1格被拦截")

	# 3. 攻击高亮范围列表验证
	var cav_cells := GridCore.get_attack_cells(center, true, 1, 12, 10)
	_assert(cav_cells.size() == 4, "骑兵攻击范围列表精确为 4 格十字")
	var inf_cells := GridCore.get_attack_cells(center, false, 1, 12, 10)
	_assert(inf_cells.size() == 8, "步兵攻击范围列表精确为 8 格九宫")

	# 4. 兵种识别测试
	var liubei = BattleUnitScript.from_data({
		"id": "liubei", "name": "刘备", "cls": "统帅", "camp": "player",
		"hp": 100, "atk": 18, "def": 10, "mov": 3, "rng": 1, "skills": []
	}, Vector2i(2, 2))
	var guanyu = BattleUnitScript.from_data({
		"id": "guanyu", "name": "关羽", "cls": "刀骑", "camp": "player",
		"hp": 120, "atk": 30, "def": 12, "mov": 4, "rng": 1, "skills": ["dragon_slash"]
	}, Vector2i(3, 3))
	var huaxiong = BattleUnitScript.from_data({
		"id": "huaxiong", "name": "华雄", "cls": "骑将", "camp": "enemy",
		"hp": 90, "atk": 26, "def": 10, "mov": 3, "rng": 1, "skills": ["hua_rage"], "is_commander": true
	}, Vector2i(3, 3))

	_assert(not liubei.is_cavalry(), "刘备（统帅/双股剑）识别为步兵系")
	_assert(guanyu.is_cavalry(), "关羽（刀骑）识别为骑兵系")
	_assert(huaxiong.is_cavalry(), "华雄（骑将）识别为骑兵系")
	_assert("8 向" in liubei.get_attack_shape_desc(), "刘备攻击范围描述为九宫 8 向")
	_assert("十字 4 向" in guanyu.get_attack_shape_desc(), "关羽攻击范围描述为十字 4 向")

	# 5. 曹操传核心博弈：步兵斜角攻击骑兵，骑兵无法反击
	liubei.cell = Vector2i(2, 2)
	huaxiong.cell = Vector2i(3, 3) # 刘备在华雄西北斜角
	_assert(GridCore.can_attack(liubei.cell, huaxiong.cell, liubei.is_cavalry(), liubei.rng), "刘备可以斜角攻击华雄！")
	_assert(not GridCore.can_attack(huaxiong.cell, liubei.cell, huaxiong.is_cavalry(), huaxiong.rng), "华雄（骑兵）无法对斜角刘备进行反击（曹操传斜角白嫖成立）！")

	# 若刘备移到正西方 (2, 3)，华雄处于十字正向，华雄可反击
	liubei.cell = Vector2i(2, 3)
	_assert(GridCore.can_attack(huaxiong.cell, liubei.cell, huaxiong.is_cavalry(), huaxiong.rng), "刘备若在华雄正十字格，华雄可以阵地反击！")

	# 6. 张飞原著战吼测试：开局即用，无需蓄力，直接眩晕，带CD
	var zhangfei = BattleUnitScript.from_data({
		"id": "zhangfei", "name": "张飞", "cls": "步战", "camp": "player",
		"hp": 140, "atk": 24, "def": 14, "mov": 3, "rng": 1, "skills": ["roar"]
	}, Vector2i(1, 1))
	var enemy = BattleUnitScript.from_data({
		"id": "dao_bing_1", "name": "董卓刀兵", "cls": "刀兵", "camp": "enemy",
		"hp": 60, "atk": 12, "def": 6, "mov": 3, "rng": 1, "skills": []
	}, Vector2i(1, 2))

	_assert(zhangfei.charge == 0, "张飞初始蓄力为0（彻底取消站桩蓄力设定）")
	_assert(zhangfei.skill_ready("roar"), "张飞开局第1回合绝技即处于就绪状态！")

	var roar_events := SkillsCore.do_roar(zhangfei, [enemy])
	var has_stun := false
	for ev in roar_events:
		if ev.get("type") == "stun":
			has_stun = true
	_assert(has_stun, "张飞一声战吼，敌军当场陷入眩晕瘫痪！符合原著失聪目眩设定！")
	_assert(zhangfei.cds.get("roar", 0) == 3, "释放后进入 3 回合 CD 冷却！")
	_assert(not zhangfei.skill_ready("roar"), "冷却期间无法重复使用战吼！")

	print("\n==== 测试完成: 失败 %d 项 ====" % total_fails)
	if total_fails == 0:
		print("🎉【曹操传兵种几何 + 张飞开局战吼】逻辑验证全部通过！")
		quit(0)
	else:
		quit(1)
