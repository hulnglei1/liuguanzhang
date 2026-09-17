extends SceneTree
## 将缘（羁绊）系统测试：原著组合在阵即生效
## 运行：Godot_console.exe --headless --path zcode项目 --script res://tests/test_bonds.gd

const BondsCore := preload("res://scripts/systems/bonds.gd")


func _init() -> void:
	print("\n==== 将缘（羁绊）系统测试 ====")
	var failed := 0

	# 1. 桃园结义：刘关张齐
	var full_roster: Array = ["liubei", "guanyu", "zhangfei", "zhaoyun", "gongsunzan", "wuanguo"]
	if not BondsCore.has_bond(full_roster, "taoyuan"):
		printerr("[FAIL] 刘关张同在阵中应激活【桃园结义】")
		failed += 1
	else:
		print("  ✅ [PASS] 刘关张同在阵中 → 激活【桃园结义】")
	if BondsCore.taoyuan_morale_bonus(full_roster) != 10:
		printerr("[FAIL] 桃园结义应给开局士气 +10")
		failed += 1
	else:
		print("  ✅ [PASS] 桃园结义：开局士气 +10")
	if BondsCore.taoyuan_regen(full_roster) != 5:
		printerr("[FAIL] 桃园结义应每回合回复 5")
		failed += 1
	else:
		print("  ✅ [PASS] 桃园结义：每回合全体回复 5 HP")

	# 2. 缺人则不激活
	var partial: Array = ["liubei", "guanyu"]
	if BondsCore.has_bond(partial, "taoyuan") or BondsCore.taoyuan_regen(partial) != 0:
		printerr("[FAIL] 只有刘备关羽时不应激活桃园结义")
		failed += 1
	else:
		print("  ✅ [PASS] 缺张飞 → 桃园结义不激活（组合必须齐全）")

	# 3. 白马义从：公孙瓒 + 刘备
	if not BondsCore.has_bond(full_roster, "baima"):
		printerr("[FAIL] 公孙瓒 + 刘备 应激活【白马义从】")
		failed += 1
	else:
		print("  ✅ [PASS] 公孙瓒 + 刘备 → 激活【白马义从】")
	if absf(BondsCore.baima_atk_mult(full_roster) - 1.15) > 0.001:
		printerr("[FAIL] 白马义从应为攻击 1.15 倍")
		failed += 1
	else:
		print("  ✅ [PASS] 白马义从：公孙瓒攻击 ×1.15")

	# 4. 云长为马（关羽 + 赵云，机制在战斗层）
	if not BondsCore.has_bond(full_roster, "qiji"):
		printerr("[FAIL] 关羽 + 赵云 应激活【云长为马】")
		failed += 1
	else:
		print("  ✅ [PASS] 关羽 + 赵云 → 激活【云长为马】（合体技）")

	# 5. 无组合时不产生任何加成
	var bare: Array = ["wuanguo"]
	if BondsCore.active_bonds(bare).size() != 0:
		printerr("[FAIL] 单人流阵容不应激活任何将缘")
		failed += 1
	else:
		print("  ✅ [PASS] 未凑齐组合时零加成（不做无脑数值膨胀）")

	# 6. 面板摘要可读
	var line: String = BondsCore.summary_line(full_roster)
	if not line.begins_with("将缘："):
		printerr("[FAIL] 摘要行格式错误：", line)
		failed += 1
	else:
		print("  ✅ [PASS] 面板摘要：", line.substr(0, 40), "…")

	print("\n==== 将缘测试%s ====" % ("全部通过 ✅" if failed == 0 else "失败 %d 项 ❌" % failed))
	quit(1 if failed > 0 else 0)
