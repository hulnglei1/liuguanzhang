extends SceneTree

const CombatCore := preload("res://scripts/core/combat.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")
const BattleUnitScript := preload("res://scripts/entities/unit.gd")
const SaveCore := preload("res://scripts/systems/save.gd")

func _init() -> void:
	print("==== V3 新增特性测试（反击/连携/神兵道具/行囊）开始 ====")
	var failed := 0

	# 1. 测试反击伤害公式
	# ATK 30 * 0.7 = 21, DEF 10 -> 11
	var cdmg: int = CombatCore.counter_damage(30, 10)
	if cdmg == 11:
		print("[OK] 反击伤害公式正确 (30x0.7 - 10 = 11) ✅")
	else:
		print("[FAIL] 反击伤害错误，实际=", cdmg)
		failed += 1

	# 2. 测试受击反击事件
	var def_u = BattleUnitScript.new()
	def_u.id = "zhangfei"
	def_u.base_atk = 32
	def_u.base_def = 14
	def_u.max_hp = 140
	def_u.hp = 140
	def_u.alive = true

	var atk_u = BattleUnitScript.new()
	atk_u.id = "huaxiong"
	atk_u.base_atk = 26
	atk_u.base_def = 10
	atk_u.max_hp = 80
	atk_u.hp = 80
	atk_u.alive = true

	var counter_ev: Array = SkillsCore.do_counter_attack(def_u, atk_u)
	# def_u ATK 32 * 0.7 = 22.4 round=22, atk_u DEF 10 -> 12 damage to atk_u
	if atk_u.hp == 68 and counter_ev.size() >= 2:
		print("[OK] 张飞反击华雄成功：华雄 HP 80 -> 68 ✅")
	else:
		print("[FAIL] 反击执行失败，华雄 HP=", atk_u.hp)
		failed += 1

	# 3. 测试眩晕状态下不可反击
	def_u.stun_turns = 1
	var stunned_counter = SkillsCore.do_counter_attack(def_u, atk_u)
	if stunned_counter.size() == 0:
		print("[OK] 眩晕状态下禁止反击 ✅")
	else:
		print("[FAIL] 眩晕状态下仍然反击")
		failed += 1
	def_u.stun_turns = 0

	# 4. 测试步骑分离·空投协力突刺
	var zy = BattleUnitScript.new()
	zy.id = "zhaoyun"
	zy.base_atk = 28
	zy.base_def = 10
	zy.alive = true
	var enemy = BattleUnitScript.new()
	enemy.id = "xiaobing"
	enemy.base_def = 5
	enemy.hp = 40
	enemy.max_hp = 40
	enemy.alive = true
	# 28 * 0.5 = 14 - 5 = 9
	var dual_ev = SkillsCore.do_dismount_strike(zy, enemy)
	if enemy.hp == 31:
		print("[OK] 赵云下马协力突刺成功：敌兵 HP 40 -> 31 (造成9点突袭伤害) ✅")
	else:
		print("[FAIL] 协力突刺失败，敌兵 HP=", enemy.hp)
		failed += 1

	# 5. 测试传世大黄丹：回满生命
	def_u.hp = 20
	var dan_ev = SkillsCore.do_use_dahuangdan(def_u)
	if def_u.hp == def_u.max_hp:
		print("[OK] 传世大黄丹金丹回天：张飞 HP 20 -> 140 回满 ✅")
	else:
		print("[FAIL] 大黄丹使用失败，HP=", def_u.hp)
		failed += 1

	# 6. 测试微缩版东风：周围敌军狂风震退与25点伤害
	zy.camp = "player"
	zy.cell = Vector2i(5, 5)
	enemy.camp = "enemy"
	enemy.cell = Vector2i(6, 5)
	var enemy2 = BattleUnitScript.new()
	enemy2.id = "xiaobing2"
	enemy2.camp = "enemy"
	enemy2.cell = Vector2i(5, 7)
	enemy2.hp = 50
	enemy2.max_hp = 50
	enemy2.alive = true
	var wind_ev = SkillsCore.do_use_dongfeng(zy, [zy, enemy, enemy2])
	if enemy.hp == 6 and enemy2.hp == 25:
		print("[OK] 微缩版东风狂风席卷：周围敌军均受25点伤害并击退 ✅")
	else:
		print("[FAIL] 东风伤害错误，HP1=", enemy.hp, " HP2=", enemy2.hp)
		failed += 1

	if failed == 0:
		print("==== V3 新增特性全部测试通过 ✅ ====")
		quit(0)
	else:
		print("==== V3 测试失败 %d 项 ❌ ====" % failed)
		quit(1)
