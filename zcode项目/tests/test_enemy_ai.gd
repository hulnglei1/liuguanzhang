extends SceneTree
## 敌方 AI 决策层（scripts/systems/enemy_ai.gd）的纯逻辑测试。
##
## 拆出这一层就是为了能脱离战斗场景单独测——改 AI 不用跑整场战斗。

const EnemyAI := preload("res://scripts/systems/enemy_ai.gd")
const BattleUnitScript := preload("res://scripts/entities/unit.gd")

var failed := 0


func _initialize() -> void:
	_run()


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  ✅ " + msg)
	else:
		printerr("  ❌ " + msg)
		failed += 1


func _unit(id: String, cls: String, hp: int, max_hp: int, cell: Vector2i, rng: int = 1, charge: int = 0):
	var d := {
		"id": id, "name": id, "cls": cls, "camp": "enemy",
		"hp": hp, "max_hp": max_hp, "atk": 20, "def": 10, "mov": 3, "rng": rng, "skills": [],
	}
	var u = BattleUnitScript.from_data(d, cell)
	u.charge = charge
	return u


func _run() -> void:
	print("\n===== 敌方 AI 决策层测试 =====")

	# ---- 1. 嘲讽：关羽蓄力越高越拉仇恨 ----
	var guanyu = _unit("guanyu", "刀将", 100, 100, Vector2i(5, 5), 1, 0)
	var foe = _unit("bowman", "弓兵", 60, 60, Vector2i(6, 5), 3, 0)
	var far_foe = _unit("bowman2", "弓兵", 60, 60, Vector2i(11, 9), 3, 0)

	guanyu.charge = 0
	var t0 = EnemyAI.pick_target(foe, guanyu, func(_u): return foe)
	_check(t0 == foe, "关羽未蓄力 → 打最近的目标")

	guanyu.charge = 6
	var t1 = EnemyAI.pick_target(foe, guanyu, func(_u): return foe)
	_check(t1 == guanyu, "关羽蓄力 6 + 6 格内 → 扑向关羽（嘲讽）")

	var t2 = EnemyAI.pick_target(far_foe, guanyu, func(_u): return far_foe)
	_check(t2 == far_foe, "远处敌人不跨图来凑热闹")

	guanyu.charge = 10
	foe.cell = Vector2i(11, 5)   # 曼哈顿距离 6，在 10 格范围内
	var t3 = EnemyAI.pick_target(foe, guanyu, func(_u): return foe)
	_check(t3 == guanyu, "关羽蓄力 10 → 10 格内都扑过去")

	# ---- 2. 出手意图 ----
	var archer = _unit("archer", "弓兵", 60, 60, Vector2i(1, 1), 3, 0)
	var melee = _unit("soldier", "刀将", 60, 60, Vector2i(1, 1), 1, 0)
	var prey = _unit("liubei", "刀将", 100, 100, Vector2i(1, 1), 1, 0)

	prey.cell = Vector2i(9, 9)
	_check(EnemyAI.attack_intent(archer, prey) == "kite_approach", "弓兵离太远 → 靠近")
	prey.cell = Vector2i(2, 1)
	_check(EnemyAI.attack_intent(archer, prey) == "kite_back", "弓兵被贴脸 → 后撤")
	prey.cell = Vector2i(3, 1)
	_check(EnemyAI.attack_intent(archer, prey) == "attack", "弓兵在射程内 → 直接打")
	prey.cell = Vector2i(9, 9)
	_check(EnemyAI.attack_intent(melee, prey) == "approach", "近战够不着 → 走过去")
	prey.cell = Vector2i(2, 1)
	_check(EnemyAI.attack_intent(melee, prey) == "attack", "近战够得着 → 直接打")

	# ---- 3. 击退到边缘 ----
	var stages := [{
		"id": "repel", "title": "打回琅琊", "objective": "",
		"win": {"type": "repel_to_edge", "target": "zangba", "edge": "east", "ratio": 0.5},
	}]
	var zangba = _unit("zangba", "刀将", 100, 100, Vector2i(6, 3), 1, 0)
	_check(not EnemyAI.should_retreat(stages, 0, zangba), "满血不撤退")
	zangba.hp = 45
	_check(EnemyAI.should_retreat(stages, 0, zangba), "跌破五成 → 撤退")
	var other = _unit("taishan", "刀将", 10, 100, Vector2i(6, 3), 1, 0)
	_check(not EnemyAI.should_retreat(stages, 0, other), "别人不跟着撤")
	_check(EnemyAI.should_retreat([], 0, zangba) == false, "没有阶段时不会撤退")

	var step = EnemyAI.retreat_step(zangba, 12, 10, "east")
	_check(step == Vector2i(7, 3), "撤退方向 = 向东一格（琅琊方向）")
	var step_w = EnemyAI.retreat_step(zangba, 12, 10, "west")
	_check(step_w == Vector2i(5, 3), "撤退方向 = 向西一格")

	print("\n===== %s =====" % ("全部通过 ✅" if failed == 0 else "失败 %d 项 ❌" % failed))
	quit(0 if failed == 0 else 1)
