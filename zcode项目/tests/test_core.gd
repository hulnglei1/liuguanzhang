extends SceneTree
## 核心纯逻辑无头断言测试
## 运行：godot --headless --script res://tests/test_core.gd
## 注意：--script 单脚本模式不加载全局 class_name，必须 preload 核心脚本

const GridCoreScript = preload("res://scripts/core/grid.gd")
const CombatCoreScript = preload("res://scripts/core/combat.gd")
const TurnCoreScript = preload("res://scripts/core/turn.gd")

func _init() -> void:
	print("==== 核心逻辑测试开始 ====")
	var failed := 0

	# ---- GridCore 测试 ----
	# 1. 移动范围：起点 (0,0)，mov=2，3x3 无障碍（4方向BFS），可达 6 格（含起点）
	var reach := GridCoreScript.reachable(Vector2i(0, 0), 2, 3, 3)
	if reach.size() != 6:
		print("[FAIL] reachable 3x3 mov2 应为6格，实际 ", reach.size())
		failed += 1
	else:
		print("[OK] reachable 3x3 mov2 = 6格")

	# 2. 障碍阻挡：中心 (1,1) 被占，起点 (0,0) mov=1 可达 3 格（含起点）
	var blocked: Array[Vector2i] = [Vector2i(1, 1)]
	var reach2 := GridCoreScript.reachable(Vector2i(0, 0), 1, 3, 3, blocked)
	if reach2.size() != 3:
		print("[FAIL] 带障碍 reachable 应为3格，实际 ", reach2.size())
		failed += 1
	else:
		print("[OK] 障碍阻挡 = 3格")

	# 3. 路径： (0,0)->(2,0)，无障碍，路径应 [(1,0),(2,0)]
	var p := GridCoreScript.path(Vector2i(0, 0), Vector2i(2, 0), 3, 3)
	if p != [Vector2i(1, 0), Vector2i(2, 0)]:
		print("[FAIL] path 应为 [(1,0),(2,0)]，实际 ", p)
		failed += 1
	else:
		print("[OK] path 正确")

	# 4. 不可达：用墙封死 (1,0)(2,0)(2,1)(2,2)，起点 (0,0) 到 (2,2) 不可达
	var wall: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]
	var p2 := GridCoreScript.path(Vector2i(0, 0), Vector2i(2, 2), 3, 3, wall)
	if p2.size() != 0:
		print("[FAIL] 不可达路径应为空，实际 ", p2)
		failed += 1
	else:
		print("[OK] 不可达返回空")

	# 5. 技能范围：中心 (1,1) 半径1，3x3 应 9 格（含自身）
	var r := GridCoreScript.cells_in_radius(Vector2i(1, 1), 1, 3, 3)
	if r.size() != 9:
		print("[FAIL] 半径1范围应为9格，实际 ", r.size())
		failed += 1
	else:
		print("[OK] 半径1范围 = 9格")

	# ---- CombatCore 测试 ----
	# 6. 伤害公式：ATK30 × 倍率1.0 − DEF10 = 20
	var dmg := CombatCoreScript.damage(30, 1.0, 10)
	if dmg != 20:
		print("[FAIL] damage 应为20，实际 ", dmg)
		failed += 1
	else:
		print("[OK] damage = 20")

	# 7. 保底1：ATK5 × 0.1 − DEF10 = 保底1
	var dmg2 := CombatCoreScript.damage(5, 0.1, 10)
	if dmg2 != 1:
		print("[FAIL] 保底伤害应为1，实际 ", dmg2)
		failed += 1
	else:
		print("[OK] 保底伤害 = 1")

	# 8. 关羽蓄力：10格 = 0.5+3.0 = 3.5倍
	if abs(CombatCoreScript.dragon_charge_multiplier(10) - 3.5) > 0.001:
		print("[FAIL] 龙斩10格倍率应为3.5，实际 ", CombatCoreScript.dragon_charge_multiplier(10))
		failed += 1
	else:
		print("[OK] 龙斩10格 = 3.5倍")

	# 9. 龙斩0格 = 0.5倍，上限clamp（15格仍3.5）
	if abs(CombatCoreScript.dragon_charge_multiplier(0) - 0.5) > 0.001:
		print("[FAIL] 龙斩0格应为0.5，实际 ", CombatCoreScript.dragon_charge_multiplier(0))
		failed += 1
	if abs(CombatCoreScript.dragon_charge_multiplier(15) - 3.5) > 0.001:
		print("[FAIL] 龙斩15格应clamp到3.5，实际 ", CombatCoreScript.dragon_charge_multiplier(15))
		failed += 1
	else:
		print("[OK] 龙斩clamp正确")

	# 10. 张飞吼：3轮 = 0.6×4 = 2.4倍
	if abs(CombatCoreScript.roar_charge_multiplier(3) - 2.4) > 0.001:
		print("[FAIL] 怒吼3轮应为2.4，实际 ", CombatCoreScript.roar_charge_multiplier(3))
		failed += 1
	else:
		print("[OK] 怒吼3轮 = 2.4倍")

	# 11. 赵云七进七出：7次 = 2.8倍
	if abs(CombatCoreScript.dash_multiplier(7) - 2.8) > 0.001:
		print("[FAIL] 七进七出7次应为2.8，实际 ", CombatCoreScript.dash_multiplier(7))
		failed += 1
	else:
		print("[OK] 七进七出7次 = 2.8倍")

	# 12. 华雄叠层：5回合 = 1+0.75 = 1.75倍
	if abs(CombatCoreScript.hua_boost_multiplier(5) - 1.75) > 0.001:
		print("[FAIL] 华雄5回合应为1.75，实际 ", CombatCoreScript.hua_boost_multiplier(5))
		failed += 1
	else:
		print("[OK] 华雄5回合 = 1.75倍")

	# 13. 士气修正：80→1.1，20→0.9，50→1.0
	if abs(CombatCoreScript.morale_multiplier(80) - 1.10) > 0.001:
		print("[FAIL] 士气80应为1.1")
		failed += 1
	if abs(CombatCoreScript.morale_multiplier(20) - 0.90) > 0.001:
		print("[FAIL] 士气20应为0.9")
		failed += 1
	if abs(CombatCoreScript.morale_multiplier(50) - 1.0) > 0.001:
		print("[FAIL] 士气50应为1.0")
		failed += 1
	else:
		print("[OK] 士气修正正确")

	# ---- TurnCore 测试 ----
	# 14. 初始状态
	var st := TurnCoreScript.new_state()
	if st.phase != TurnCoreScript.Phase.PLAYER or st.turn != 1:
		print("[FAIL] 初始回合状态不对")
		failed += 1
	else:
		print("[OK] 初始回合状态正确")

	# 15. all_acted
	TurnCoreScript.mark_acted(st, "a")
	TurnCoreScript.mark_acted(st, "b")
	if not TurnCoreScript.all_acted(st, ["a", "b"]):
		print("[FAIL] all_acted 应为true")
		failed += 1
	if TurnCoreScript.all_acted(st, ["a", "b", "c"]):
		print("[FAIL] all_acted 缺c应为false")
		failed += 1
	else:
		print("[OK] all_acted 正确")

	# 16. 回合流转
	TurnCoreScript.to_enemy(st)
	if st.phase != TurnCoreScript.Phase.ENEMY:
		print("[FAIL] 应切到敌方回合")
		failed += 1
	TurnCoreScript.to_player(st)
	if st.phase != TurnCoreScript.Phase.PLAYER or st.turn != 2:
		print("[FAIL] 应切回我方回合且turn=2")
		failed += 1
	else:
		print("[OK] 回合流转正确")

	# ---- 汇总 ----
	if failed == 0:
		print("==== 全部测试通过 ✅ ====")
	else:
		print("==== 失败 ", failed, " 项 ❌ ====")
	quit(failed)
