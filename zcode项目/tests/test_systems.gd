extends SceneTree
## 士气/骑乘/抽奖系统无头测试
## 运行：godot --headless --script res://tests/test_systems.gd

const GridCore := preload("res://scripts/core/grid.gd")
const CombatCore := preload("res://scripts/core/combat.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")
const MoraleCore := preload("res://scripts/systems/morale.gd")
const LotteryCore := preload("res://scripts/systems/lottery.gd")
const BattleUnitScript := preload("res://scripts/entities/unit.gd")

func _init() -> void:
	print("==== 系统测试（士气/骑乘/抽奖）开始 ====")
	var failed := 0

	var guanyu = BattleUnitScript.from_data(_unit_def("guanyu"), Vector2i(0, 0))
	var zhaoyun = BattleUnitScript.from_data(_unit_def("zhaoyun"), Vector2i(2, 0))
	var huaxiong = BattleUnitScript.from_data(_unit_def("huaxiong"), Vector2i(5, 5))
	var dao = BattleUnitScript.from_data(_unit_def("dao_bing_1"), Vector2i(6, 5))

	# ---- 1. 士气修正 ----
	MoraleCore.apply_morale([guanyu], 120)  # 士气120 → ×1.2
	var atk_high: int = guanyu.effective_atk()
	var expect_high: int = int(round(guanyu.base_atk * 1.2))   # ×1.2 从基础攻击推算
	if atk_high != expect_high:
		print("[FAIL] 士气120 ATK 应为%d，实际 %d" % [expect_high, atk_high])
		failed += 1
	else:
		print("[OK] 士气120 → ATK×1.2 = 36 ✅")

	# ---- 2. 不应战惩罚：敌军×2 ----
	MoraleCore.apply_refuse_penalty([huaxiong, dao])
	var hx_atk: int = huaxiong.effective_atk()
	# 不应战 ×2 是叠在"虎牢狂力"之上的独立倍率：基础 × 斩将倍率 × 2
	if hx_atk != int(round(huaxiong.base_atk * CombatCore.hua_boost_multiplier(huaxiong.hua_kills) * 2)):
		print("[FAIL] 不应战后华雄攻击应为 %d，实际 %d" % [int(round(huaxiong.base_atk * CombatCore.hua_boost_multiplier(huaxiong.hua_kills) * 2)), hx_atk])
		failed += 1
	else:
		print("[OK] 不应战惩罚 → 华雄ATK×2 = 52 ✅")

	# ---- 3. 阵前挑战（华雄应战） ----
	var chal := MoraleCore.challenge(guanyu, huaxiong, 1.0)
	if not chal.accepted:
		print("[FAIL] 华雄应战，挑战应 accepted")
		failed += 1
	else:
		print("[OK] 阵前挑战：华雄应战 ✅")

	# ---- 4. 骑乘合体：关羽骑赵云 ----
	var can_mount := SkillsCore.can_mount(guanyu, zhaoyun)
	if not can_mount:
		print("[FAIL] 关羽(0,0)与赵云(2,0)相距2应可合体")
		failed += 1
	else:
		print("[OK] 关羽骑赵云：相距2格可合体 ✅")
	SkillsCore.do_mount(guanyu, zhaoyun)
	if not guanyu.is_mounted():
		print("[FAIL] 合体后关羽应处于骑乘状态")
		failed += 1
	else:
		print("[OK] 合体状态正确 ✅")
	# 合体后移动力 = 赵云MOV(6)
	var mounted_mov: int = SkillsCore.mounted_mov(guanyu, zhaoyun)
	if mounted_mov != 6:
		print("[FAIL] 合体后移动力应为6，实际 ", mounted_mov)
		failed += 1
	else:
		print("[OK] 合体移动力 = 赵云MOV 6 ✅")

	# ---- 5. 抽奖 ----
	# 声望不足
	var poor := LotteryCore.draw_seed(500)
	if poor.success:
		print("[FAIL] 声望500 抽奖应失败")
		failed += 1
	else:
		print("[OK] 声望不足抽奖被拒 ✅")
	# 声望足够
	var ok := LotteryCore.draw_seed(1000)
	if not ok.success:
		print("[FAIL] 声望1000 抽奖应成功")
		failed += 1
	else:
		print("[OK] 声望1000抽奖成功，抽中：", ok.item.name, " ✅")

	if failed == 0:
		print("==== 系统测试全部通过 ✅ ====")
	else:
		print("==== 失败 ", failed, " 项 ❌ ====")
	quit(failed)

func _unit_def(id: String) -> Dictionary:
	var f := FileAccess.open("res://data/units.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	for d in parsed["units"]:
		if d["id"] == id:
			return d
	return {}
