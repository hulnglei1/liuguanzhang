extends SceneTree
## 第四关机制测试：臧霸占山为王（高地攻防+）、昌豨怯战
## 运行：godot --headless --script res://tests/test_chapter4.gd

const CombatCore := preload("res://scripts/core/combat.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")
const BattleUnitScript := preload("res://scripts/entities/unit.gd")

func _init() -> void:
	print("==== 第四关机制测试（臧霸占山/昌豨怯战）开始 ====")
	var failed := 0

	var zangba = BattleUnitScript.from_data(_unit_def("zangba"), Vector2i(5, 5))
	var changxi = BattleUnitScript.from_data(_unit_def("changxi"), Vector2i(3, 5))
	var guanyu = BattleUnitScript.from_data(_unit_def("guanyu"), Vector2i(8, 8))

	# ---- 1. 臧霸不在高地的正常攻防 ----
	var atk_plain: int = zangba.effective_atk()
	var def_plain: int = zangba.effective_def()
	print("[模拟] 臧霸平地 ATK=%d DEF=%d" % [atk_plain, def_plain])
	if atk_plain != 32 or def_plain != 12:
		print("[FAIL] 臧霸平地ATK应为32 DEF应为12，实际 %d/%d" % [atk_plain, def_plain])
		failed += 1

	# ---- 2. 臧霸占山为王（高地）攻防+30% ----
	zangba.on_hill = true
	var atk_hill: int = zangba.effective_atk()
	var def_hill: int = zangba.effective_def()
	print("[模拟] 臧霸高地 ATK=%d DEF=%d" % [atk_hill, def_hill])
	if atk_hill != int(round(32 * 1.3)) or def_hill != int(round(12 * 1.3)):
		print("[FAIL] 臧霸高地应攻防+30%%（ATK=%d DEF=%d）" % [int(round(32*1.3)), int(round(12*1.3))])
		failed += 1
	else:
		print("[OK] 臧霸占山为王：高地攻防+30% ✅")

	# ---- 3. 离开高地恢复 ----
	zangba.on_hill = false
	if zangba.effective_atk() != 32:
		print("[FAIL] 臧霸离开高地应恢复ATK32")
		failed += 1
	else:
		print("[OK] 离开高地恢复 ✅")

	# ---- 4. 昌豨怯战：受击后DEF-30% ----
	var def_before: int = changxi.effective_def()
	changxi.coward_debuff = true
	var def_after: int = changxi.effective_def()
	print("[模拟] 昌豨怯战 DEF %d→%d" % [def_before, def_after])
	if def_after != int(round(10 * 0.7)):
		print("[FAIL] 昌豨怯战DEF应为%d" % int(round(10*0.7)))
		failed += 1
	else:
		print("[OK] 昌豨怯战：DEF-30% ✅")

	if failed == 0:
		print("==== 第四关机制全部通过 ✅ ====")
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