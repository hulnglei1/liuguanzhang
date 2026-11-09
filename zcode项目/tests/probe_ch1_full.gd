extends SceneTree
## 第一关完整验收：战败流程 + 胜利链路 + 全部机制
## 运行：Godot_console.exe --headless --path zcode项目 --script res://tests/probe_ch1_full.gd
##
## 与 probe_ch1_check.gd 的分工：
##   probe_ch1_check  —— 公孙瓒飞弹 + 行动状态机（输入层）
##   probe_ch1_full   —— 关卡全链路（军令推进 / 劈门 / 数值 / 战败 / 通关）

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")
const CombatCore := preload("res://scripts/core/combat.gd")

var b: Node
var failed: int = 0


func _initialize() -> void:
	var s: Dictionary = SaveCore.new_state()
	s["prologues_seen"] = ["chapter1", "chapter2", "chapter3", "chapter4"]
	s["prestige"] = 0
	SaveCore.save_state(s)
	_run()


func _wait(x: float) -> void:
	await create_timer(x).timeout


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		failed += 1


func _enter_ch1() -> void:
	BattleScript.chapter_id = "chapter1"
	change_scene_to_file("res://scenes/battle.tscn")
	await _wait(2.5)
	b = current_scene
	if b.has_method("_on_dialog_skip_pressed"):
		b._on_dialog_skip_pressed()
	await _wait(0.5)


func _run() -> void:
	await _enter_ch1()

	print("\n########## 轮 1 / 战败流程 ##########")
	await _test_defeat()

	print("\n########## 轮 2 / 胜利链路与机制 ##########")
	await _enter_ch1()
	await _test_initial_state()
	await _test_opening_event()
	await _test_gate_reach()
	await _test_guanyu_skill_available()
	await _test_gate_too_weak()
	await _test_huaxiong_stack()
	await _test_charge_reset()
	await _test_roar()
	await _test_behead()
	await _test_breach_and_win()

	print("\n########## 汇总 ##########")
	if failed == 0:
		print("第一关验收：全部通过 ✅")
	else:
		print("第一关验收：失败 %d 项 ❌" % failed)
	SaveCore.save_state(SaveCore.new_state())
	quit(0 if failed == 0 else 1)


## ---------- 轮 1 ----------

## 战败必须真的结束关卡（此前只播对白不置标记 → 全灭后回合空转 130 回合）
func _test_defeat() -> void:
	b.pending_dialog = []
	b.dialog_showing = false
	for u in b._camp_units("player"):
		u.hp = 0
		u.alive = false
	var triggered: bool = b._check_defeat()
	await _wait(0.5)
	_check(triggered and bool(b.defeat), "我方全灭 → 置 defeat 标记（关卡真正结束）")
	_check(int(b.input_mode) == 0, "战败后不再接受操作（input_mode = NONE）")
	_check(b.selected_id == "", "战败后清空选中单位")
	_check(b.dialog_showing or b.pending_dialog.size() > 0, "播放失败对白")


## ---------- 轮 2 ----------

func _test_initial_state() -> void:
	print("\n---- 1. 开局状态 ----")
	var n_player: int = b._camp_units("player").size()
	var n_enemy: int = b._camp_units("enemy").size()
	print("  阶段 %d/%d | 我方 %d 人 | 敌方 %d 人 | 士气 %d / %d" % [
		int(b.stage_idx) + 1, int(b.stages.size()), n_player, n_enemy,
		int(b.morale["player"]), int(b.morale["enemy"])])
	_check(int(b.stages.size()) == 2, "第一阶段分两个军令")
	_check(int(b.stage_idx) == 0, "开局停在阶段 1「温酒斩华雄」")
	_check(n_player == 6, "我方 6 人（刘关张 + 公孙瓒 + 2 义军）")
	_check(n_enemy >= 5, "敌方至少 5 人（华雄 + 杂兵群），实际 %d" % n_enemy)
	_check(int(b.morale["player"]) >= 110, "【桃园结义】生效：开局士气 110（100+10）")
	# 小兵血量：张飞 14 字咆哮约 53 伤害，血量太低会被一吼带走（玩家反馈过）
	var dao0 = b._unit_by_id("dao_bing_1")
	var gong0 = b._unit_by_id("gong_bing_1")
	# 咆哮是**控场**不是输出：用"伤害关系"断言，而不是写死血量阈值。
	# （旧写法 hp>=75 只是个代理指标，数值一动就误报，且它验不出真实意图）
	var zf_ref = b._unit_by_id("zhangfei")
	if zf_ref != null:
		var roar6_dao: int = CombatCore.damage(zf_ref.effective_atk(), 0.64, dao0.effective_def())
		var roar6_gong: int = CombatCore.damage(zf_ref.effective_atk(), 0.64, gong0.effective_def())
		_check(roar6_dao < dao0.max_hp, "6 字咆哮(%d 伤) 打不死刀兵(%d 血) —— 控场不是输出" % [roar6_dao, dao0.max_hp])
		_check(roar6_gong < gong0.max_hp, "6 字咆哮(%d 伤) 打不死弓兵(%d 血)" % [roar6_gong, gong0.max_hp])
	var yi = b._unit_by_id("yi_bing_1")
	_check(yi != null and yi.camp == "player", "我方带小兵（义军），可被华雄斩杀来喂他的绝技")


func _test_opening_event() -> void:
	print("\n---- 2. 开局事件对白 ----")
	_check("chapter1_open" in b.queued_events, "第 1 回合事件已触发（chapter1_open）")


## 劈门射程：曾经要求"紧贴城门"，与"12 格直线贯穿"的技能设定自相矛盾
func _test_gate_reach() -> void:
	print("\n---- 3. 劈门射程 ----")
	var gy = b._unit_by_id("guanyu")
	gy.cell = Vector2i(7, 4)          # 华雄原本的位置，与城门 (10,4) 同排、距离 3
	gy.charge = 10
	b.selected_id = "guanyu"
	_check(b._is_in_skill_range(Vector2i(10, 4)),
		"蓄满 10 格可沿直线从 3 格外劈门（旧版要求相邻 1 格，蓄满也劈不到）")
	gy.cell = Vector2i(8, 3)          # 斜向
	_check(not b._is_in_skill_range(Vector2i(10, 4)), "斜向（不同行列）劈不到城门")
	gy.cell = Vector2i(7, 4)


## 蓄力不足点到城门：不能白丢一整回合
## 关羽技能可用性：用户反馈"技能一直灰色点不出来，不管有没有靠近敌人"
## 根因：_has_skill_target 只认"相邻敌人"，没把"可劈的城门"算进去 →
##       华雄一死、周围没敌人时按钮永远灰着，整个阶段 2 劈不了门。
func _test_guanyu_skill_available() -> void:
	print("\n---- 3b. 关羽技能可用性 ----")
	var gy = b._unit_by_id("guanyu")
	var origin: Vector2i = gy.cell
	var charge0: int = gy.charge

	gy.cell = Vector2i(3, 3)                      # 周围无敌人、也与城门不同直线
	gy.charge = 0
	_check(not b._has_skill_target(gy, "dragon_slash"), "孤立无目标时按钮不可用（正常，应显示「无目标」）")

	gy.cell = Vector2i(4, 4)                      # dao_bing_1 在 (5,4)
	_check(b._has_skill_target(gy, "dragon_slash"), "站到敌人相邻格 → 技能可用")

	gy.cell = Vector2i(7, 4)                      # 与城门 (10,4) 同排、距离 3
	gy.charge = 10
	_check(b._has_skill_target(gy, "dragon_slash"), "与城门同排且蓄满 → 技能可用（此前会灰着，阶段 2 卡死）")

	gy.cell = origin
	gy.charge = charge0


func _test_gate_too_weak() -> void:
	print("\n---- 4. 蓄力不足劈门 ----")
	var gy = b._unit_by_id("guanyu")
	gy.cell = Vector2i(9, 4)
	gy.charge = 5
	gy.acted = false
	gy.cds.clear()
	b.selected_id = "guanyu"
	var before: bool = b.gate_broken
	b._do_skill(Vector2i(10, 4))
	await _wait(0.4)
	_check(b.gate_broken == before, "蓄力不足（5/10）时城门劈不开")
	_check(not gy.acted, "蓄力不足**不消耗行动**（旧版会白丢一整回合）")
	_check(gy.charge == 5, "蓄力不会被清空，可继续攒")


## 华雄叠层：军令文案已改为"每拖延 1 回合"
func _test_huaxiong_stack() -> void:
	print("\n---- 5. 华雄叠层 ----")
	var hx = b._unit_by_id("huaxiong")
	var atk0: int = hx.effective_atk()
	for i in range(3):
		hx.end_turn()
	var atk3: int = hx.effective_atk()
	print("  ATK %d → %d（叠层 %d，倍率 %.2fx）" % [
		atk0, atk3, hx.hua_rage_turns, CombatCore.hua_boost_multiplier(hx.hua_rage_turns)])
	_check(hx.hua_rage_turns == 3, "拖 3 回合 = 叠 3 层")
	_check(atk3 > atk0, "拖得越久华雄越强（与面板/军令文案一致）")

	# 斩将叠层：我方小兵阵亡 → 华雄再叠一层（原著"连斩联军数将"）
	var before: int = hx.hua_rage_turns
	var yi = b._unit_by_id("yi_bing_1")
	yi.hp = 0
	yi.alive = false
	b._apply_events([{"type": "death", "target": "yi_bing_1"}])
	await _wait(0.4)
	print("  义军阵亡后叠层：%d → %d" % [before, hx.hua_rage_turns])
	_check(hx.hua_rage_turns == before + 1, "我方阵亡 → 华雄「斩将」再叠一层")


func _test_charge_reset() -> void:
	print("\n---- 6. 关羽受击 → 蓄力清零 ----")
	var gy = b._unit_by_id("guanyu")
	gy.charge = 6
	b._apply_events([{"type": "damage", "target": "guanyu", "value": 10}])
	await _wait(0.4)
	_check(gy.charge == 0, "受击气脉震散、蓄力清零（原著设定）")


func _test_roar() -> void:
	print("\n---- 7. 张飞燕人咆哮（第一关场景）----")
	var zf = b._unit_by_id("zhangfei")
	zf.cell = Vector2i(4, 4)
	zf.acted = false
	zf.cds.clear()
	var dao = b._unit_by_id("dao_bing_1")   # (5,4)，距张飞 1 格
	var stun_before: int = dao.stun_turns
	b.selected_id = "zhangfei"
	b._start_roar_charging(zf)
	b._execute_roar(6)
	await _wait(0.5)
	print("  六字咆哮：刀兵 stun %d → %d" % [stun_before, dao.stun_turns])
	_check(dao.stun_turns >= 1, "六字咆哮眩晕范围内敌军")


func _test_behead() -> void:
	print("\n---- 8. 阶段 1：温酒斩华雄 ----")
	var hx = b._unit_by_id("huaxiong")
	hx.hp = 0
	hx.alive = false
	var won: bool = b._check_victory()
	await _wait(1.2)
	print("  stage_idx=%d，victory=%s" % [int(b.stage_idx), str(b.victory)])
	_check(int(b.stage_idx) == 1, "斩华雄 → 军令推进到阶段 2「劈关夺门」")
	_check(not won and not b.victory, "斩华雄不直接通关（还要劈门）")


func _test_breach_and_win() -> void:
	print("\n---- 9. 阶段 2：劈关夺门 → 通关 ----")
	var gy = b._unit_by_id("guanyu")
	gy.cell = Vector2i(7, 4)
	gy.charge = 10
	gy.acted = false
	b.selected_id = "guanyu"
	var prestige0: int = int(SaveCore.load_state().get("prestige", 0))
	var morale_enemy_before: int = int(b.morale["enemy"])
	b._do_skill(Vector2i(10, 4))          # 从 3 格外直线劈门

	# 破门是同步结算的，先抓现场再等演出
	var debuffed: bool = true
	for e in b._camp_units("enemy"):
		if e.alive and not e.gate_broken_debuff:
			debuffed = false
	var prestige1: int = int(SaveCore.load_state().get("prestige", 0))
	print("  gate_broken=%s | 声望 %d → %d | 敌军士气 %d → %d" % [
		str(b.gate_broken), prestige0, prestige1, morale_enemy_before, int(b.morale["enemy"])])
	_check(b.gate_broken, "从 3 格外直线劈开汜水关城门")
	_check(debuffed, "守军全部挂上「防线溃乱」DEF-20%")
	_check(prestige1 >= prestige0 + 500, "破门夺关即刻 +500 声望（占郡收益）")
	_check(int(b.morale["enemy"]) < morale_enemy_before, "敌军士气暴跌")
	await _wait(1.2)
	_check(bool(b.victory), "两阶段军令全部达成 → 通关")
