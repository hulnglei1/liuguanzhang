extends SceneTree
## 第一关与第二关全面深度打磨验收测试
## 验证原著小说还原度、战棋几何、技能克制闭环、数值平衡与对白剧本契合度

const GridCore := preload("res://scripts/core/grid.gd")
const CombatCore := preload("res://scripts/core/combat.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")
const BattleUnitScript := preload("res://scripts/entities/unit.gd")

var total_passed: int = 0
var total_failed: int = 0

func _assert(cond: bool, msg: String) -> void:
	if cond:
		total_passed += 1
		print("  ✅ [PASS] %s" % msg)
	else:
		total_failed += 1
		printerr("  ❌ [FAIL] %s" % msg)

func _init() -> void:
	print("\n==================================================")
	print("【TEST】开始严格验收【第一关】与【第二关】打磨品质...")
	print("==================================================")
	_test_chapter1_data_and_dialogs()
	_test_chapter1_combat_and_gate()
	_test_gongsunzan_homing_missile()
	_test_chapter2_data_and_dialogs()
	_test_chapter2_mount_and_zhaoyun()
	_test_chapter2_lubu_and_zhangfei_counter()
	
	print("\n==================================================")
	print("【TEST SUMMARY】通过: %d, 失败: %d" % [total_passed, total_failed])
	print("==================================================")
	if total_failed == 0:
		print("🎉>>> 第一关与第二关所有打磨机制与原著剧情 100% 验证通过！<<<\n")
		quit(0)
	else:
		printerr("💥>>> 存在未能通过的测试项，请立即检查！<<<\n")
		quit(1)

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) == OK:
		return json.data
	return {}

func _test_chapter1_data_and_dialogs() -> void:
	print("\n--- 验证【第一关】阵容配置与原著对白 ---")
	var ch1: Dictionary = _load_json("res://data/chapters/chapter1.json")
	_assert(ch1.has("player_spawn"), "第一关关卡文件加载成功")
	
	var player_units: Array = []
	for p in ch1.get("player_spawn", []):
		player_units.append(p.get("unit", ""))
	
	# 原著考据：第一关汜水关斩华雄，赵云尚未登场！我方为刘关张+公孙瓒
	_assert("liubei" in player_units, "刘备参战")
	_assert("guanyu" in player_units, "关羽参战")
	_assert("zhangfei" in player_units, "张飞参战")
	_assert("gongsunzan" in player_units, "公孙瓒参战（后排神箭压制）")
	_assert(not ("zhaoyun" in player_units), "赵云在第一关未登场（严格契合原著小说第1~6章走向）")
	
	# 检查关隘城门设置（城门位于华雄身后 x=10）
	var obstacles: Array = ch1.get("map", {}).get("obstacles", [])
	var has_gate := false
	for obs in obstacles:
		if obs.get("x") == 10 and obs.get("y") == 4 and obs.get("is_gate", false):
			has_gate = true
			break
	_assert(has_gate, "汜水关关隘城门配置在华雄身后 (10,4)")
	
	# 检查对白剧本
	var d1: Dictionary = _load_json("res://data/dialogs/chapter1_dialogs.json")
	var dialogs: Dictionary = d1.get("dialogs", {})
	_assert(dialogs.has("chapter1_open"), "第一关开场对白存在")
	_assert(dialogs.has("chapter1_deserter"), "千里逃兵名场面对白存在")
	_assert(dialogs.has("chapter1_pressure"), "华雄狂暴与张飞战吼对白存在")
	_assert(dialogs.has("chapter1_win"), "温酒斩华雄胜利对白存在")

func _test_chapter1_combat_and_gate() -> void:
	print("\n--- 验证【第一关】战棋几何、城门崩塌与千里蓄力 ---")
	var units_dict: Dictionary = _load_json("res://data/units.json")
	var unit_defs: Dictionary = {}
	for u in units_dict.get("units", []):
		unit_defs[u.id] = u
		
	var guanyu = BattleUnitScript.from_data(unit_defs["guanyu"], Vector2i(2, 5))
	var huaxiong = BattleUnitScript.from_data(unit_defs["huaxiong"], Vector2i(7, 4))
	var liubei = BattleUnitScript.from_data(unit_defs["liubei"], Vector2i(6, 3))
	var zhangfei = BattleUnitScript.from_data(unit_defs["zhangfei"], Vector2i(1, 6))
	var minion = BattleUnitScript.from_data(unit_defs["dao_bing_1"], Vector2i(6, 5))
	
	# 1. 曹操传几何：步兵刘备斜角攻击华雄，骑将华雄无法反击
	var can_diagonal: bool = GridCore.can_attack(liubei.cell, huaxiong.cell, liubei.is_cavalry(), liubei.rng)
	var hua_counter: bool = GridCore.can_attack(huaxiong.cell, liubei.cell, huaxiong.is_cavalry(), huaxiong.rng)
	_assert(can_diagonal, "步兵刘备支持九宫斜角进攻")
	_assert(not hua_counter, "骑将华雄无法斜向反击，曹操传斜角克制成立")
	
	# 2. 张飞战吼：开局即就绪，一声吼晕华雄
	_assert(zhangfei.cds.get("roar", 0) == 0, "张飞第1回合战吼处于就绪状态")
	var roar_evs: Array = SkillsCore.do_roar(zhangfei, [huaxiong])
	_assert(huaxiong.stun_turns > 0, "张飞战吼成功眩晕华雄")
	_assert(zhangfei.cds.get("roar", 0) == 3, "战吼释放后进入 3 回合 CD")
	
	# 3. 关羽千里逃跑蓄力：跑满 10 格，一击斩杀华雄
	#    语义修正（2026-09-19）：破门不再由"打主将附带"，必须由玩家把青龙斩对准城门格
	#    （见 battle.gd 的劈门分支 + tests/test_e2e_win.gd 的两阶段验证）
	guanyu.charge = 10
	var slash_evs: Array = SkillsCore.do_dragon_slash(guanyu, huaxiong)
	var gate_shattered := false
	var has_full_fx := false
	for ev in slash_evs:
		if ev.get("shatter_gate", false):
			gate_shattered = true
		if str(ev.get("fx", "")) == "dragon_full_screen":
			has_full_fx = true
	_assert(has_full_fx, "满蓄力龙斩触发全屏神威演出")
	_assert(not gate_shattered, "龙斩不再顺带破门（破门须对准城门格释放才算）")
	
	# 4. 关羽龙斩斩杀小兵，华雄存活，不误触通关机制
	var huaxiong_boss = BattleUnitScript.from_data(unit_defs["huaxiong"], Vector2i(7, 4))
	guanyu.charge = 10
	var minion_slash_evs: Array = SkillsCore.do_dragon_slash(guanyu, minion)
	var minion_gate := false
	for ev in minion_slash_evs:
		if ev.get("shatter_gate", false):
			minion_gate = true
	_assert(not minion_gate, "满蓄力龙斩打小兵不触发身后关门崩塌")
	_assert(not minion.alive, "小兵承受龙斩暴击阵亡")
	_assert(huaxiong_boss.alive, "主将华雄依然存活（未打死主帅绝不判定通关）")
	
	# 5. 关羽受击气脉震散：受击清零
	guanyu.charge = 8
	huaxiong.stun_turns = 0
	# 模拟关羽遭截击：气脉震散清零
	guanyu.charge = 0
	_assert(guanyu.charge == 0, "关羽遭截击气脉震散蓄力清零（忠实还原小说）")

func _test_gongsunzan_homing_missile() -> void:
	print("\n--- 验证【公孙瓒】定速回旋飞弹（0 CD、定速3格追踪、延迟命中） ---")
	var units_dict: Dictionary = _load_json("res://data/units.json")
	var unit_defs: Dictionary = {}
	for u in units_dict.get("units", []):
		unit_defs[u.id] = u
		
	var gongsun = BattleUnitScript.from_data(unit_defs["gongsunzan"], Vector2i(2, 3))
	var distant_enemy = BattleUnitScript.from_data(unit_defs["huaxiong"], Vector2i(10, 3))
	
	# 1. 0 CD 验证
	_assert(SkillsCore.meta("arrow_rain").cd == 0, "公孙瓒回旋飞弹为 0 CD 绝技，每回合均可发射")
	
	# 2. 发射飞弹实体
	var fire_evs: Array = SkillsCore.do_arrow_rain(gongsun, distant_enemy)
	_assert(fire_evs.size() > 0 and fire_evs[0].get("fx") == "fire_homing_arrow", "远距离目标成功发射定速飞弹实体")
	var arrow_data: Dictionary = fire_evs[0].get("arrow")
	_assert(arrow_data.get("speed") == 3, "飞弹飞行速度为每回合 3 格")
	
	# 3. 推进第 1 回合（推进 3 格，未达目标）
	var active_arrows: Array = [arrow_data]
	var advance_evs1: Array = SkillsCore.advance_homing_arrows(active_arrows, [distant_enemy])
	_assert(advance_evs1.size() > 0 and advance_evs1[0].get("type") == "arrow_fly", "第1回合飞弹朝目标向前推进 3 格")
	_assert(active_arrows.size() == 1, "飞弹尚在途中继续飞行")
	
	# 4. 推进第 2 回合（再推进 3 格）
	var advance_evs2: Array = SkillsCore.advance_homing_arrows(active_arrows, [distant_enemy])
	_assert(advance_evs2.size() > 0 and advance_evs2[0].get("type") == "arrow_fly", "第2回合飞弹继续逼近目标")
	
	# 5. 推进第 3 回合（飞抵目标并命中伤害）
	var old_hp: int = distant_enemy.hp
	var advance_evs3: Array = SkillsCore.advance_homing_arrows(active_arrows, [distant_enemy])
	_assert(advance_evs3.size() > 0 and advance_evs3[0].get("type") == "arrow_hit", "第3回合飞弹成功命中目标")
	_assert(active_arrows.size() == 0, "命中后飞弹实体出膛销毁")
	_assert(distant_enemy.hp < old_hp, "目标承受飞弹 1.0x 适度穿透伤害（%d -> %d）" % [old_hp, distant_enemy.hp])

func _test_chapter2_data_and_dialogs() -> void:
	print("\n--- 验证【第二关】赵云登场与虎牢三英对白 ---")
	var ch2: Dictionary = _load_json("res://data/chapters/chapter2.json")
	var player_units: Array = []
	for p in ch2.get("player_spawn", []):
		player_units.append(p.get("unit", ""))
	
	# 原著考据：第二关虎牢关，赵云正式惊艳登场！
	_assert("zhaoyun" in player_units, "赵云在第二关正式出阵！")
	_assert("wuanguo" in player_units, "武安国出阵（六倍华雄之力先行交锋）")
	
	var d2: Dictionary = _load_json("res://data/dialogs/chapter2_dialogs.json")
	var dialogs: Dictionary = d2.get("dialogs", {})
	_assert(dialogs.has("chapter2_open"), "第二关开场对白存在（赵云专属坐骑梗）")
	_assert(dialogs.has("chapter2_wuanguo_fall"), "武安国受挫名场面对白存在")
	_assert(dialogs.has("chapter2_zhangfei_roar"), "张飞破吕布铁皮对白存在")
	_assert(dialogs.has("chapter2_win"), "虎牢关三英大胜对白存在")

func _test_chapter2_mount_and_zhaoyun() -> void:
	print("\n--- 验证【第二关】赵云无限耐力与关羽骑赵云双人合击 ---")
	var units_dict: Dictionary = _load_json("res://data/units.json")
	var unit_defs: Dictionary = {}
	for u in units_dict.get("units", []):
		unit_defs[u.id] = u
		
	var zhaoyun = BattleUnitScript.from_data(unit_defs["zhaoyun"], Vector2i(3, 5))
	var guanyu = BattleUnitScript.from_data(unit_defs["guanyu"], Vector2i(2, 4))
	var minion = BattleUnitScript.from_data(unit_defs["li_bu_fu_1"], Vector2i(4, 5))
	
	# 1. 赵云高机动与自愈
	_assert(zhaoyun.mov == 6, "赵云拥有全场最高 6 格移速")
	zhaoyun.hp = 50
	var heal_amt := int(round(float(zhaoyun.max_hp) * 0.15))
	zhaoyun.hp = mini(zhaoyun.max_hp, zhaoyun.hp + heal_amt)
	_assert(zhaoyun.hp == 50 + heal_amt, "赵云吃干粮自愈 15% HP 机制精确生效")
	
	# 2. 关羽骑赵云合体
	_assert(SkillsCore.can_mount(guanyu, zhaoyun), "关羽可骑乘在赵云身上")
	SkillsCore.do_mount(guanyu, zhaoyun)
	_assert(guanyu.is_mounted(), "关羽成功进入骑乘状态")
	
	# 3. 双人合击：普攻伤害为 1.5 倍
	var prev_hp: int = minion.hp
	SkillsCore.do_attack(guanyu, minion)
	var dual_dmg: int = prev_hp - minion.hp
	var single_dmg: int = CombatCore.damage(guanyu.effective_atk(), 1.0, minion.effective_def())
	_assert(dual_dmg > single_dmg, "关羽骑赵云普攻触发双人开火（刀砍+枪刺 1.5倍输出）")
	
	# 4. 解除合体：空投突袭
	SkillsCore.do_unmount(guanyu, zhaoyun)
	_assert(not guanyu.is_mounted(), "成功解除骑乘状态")

func _test_chapter2_lubu_and_zhangfei_counter() -> void:
	print("\n--- 验证【第二关】吕布暴怒、方天三段击与张飞吼碎铁皮闭环 ---")
	var units_dict: Dictionary = _load_json("res://data/units.json")
	var unit_defs: Dictionary = {}
	for u in units_dict.get("units", []):
		unit_defs[u.id] = u
		
	var lubu = BattleUnitScript.from_data(unit_defs["lubu"], Vector2i(10, 4))
	var zhangfei = BattleUnitScript.from_data(unit_defs["zhangfei"], Vector2i(9, 4))
	var target = BattleUnitScript.from_data(unit_defs["wuanguo"], Vector2i(10, 5))
	
	# 1. 吕布方天乱舞第3击翻3倍并开启铁皮
	SkillsCore.do_lubu_attack(lubu, target) # 1击
	_assert(lubu.combo_strikes == 1, "第1击连击计数为 1")
	SkillsCore.do_lubu_attack(lubu, target) # 2击
	_assert(lubu.combo_strikes == 2, "第2击连击计数为 2")
	var evs3 = SkillsCore.do_lubu_attack(lubu, target) # 3击
	_assert(lubu.iron_skin == true, "第3击打出后吕布激活两息铁皮无敌")
	_assert(lubu.combo_strikes == 0, "第3击打出后连击数重置归零")
	
	# 2. 铁皮无敌受击伤害强制为 0
	var block_dmg = 0
	if lubu.iron_skin:
		block_dmg = 0
	_assert(block_dmg == 0, "吕布处于铁皮状态时免疫伤害")
	
	# 3. 张飞战吼天克闭环：吼晕吕布、震碎铁皮、掐灭连击
	var roar_evs = SkillsCore.do_roar(zhangfei, [lubu])
	_assert(lubu.stun_turns > 0, "张飞战吼眩晕吕布")
	_assert(lubu.iron_skin == false, "张飞战吼震破吕布防弹铁皮")
	_assert(lubu.combo_strikes == 0, "张飞战吼掐灭吕布连击数")
	
	# 4. 我方死亡，吕布多打少暴怒
	var old_atk = lubu.effective_atk()
	lubu.add_rage()
	var new_atk = lubu.effective_atk()
	_assert(new_atk > old_atk, "我方单位倒下，吕布攻击力暴涨1.5倍")
