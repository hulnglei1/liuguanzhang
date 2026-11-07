extends SceneTree
## 第 4 关"打回琅琊"验收：
##   1) 只有当阶段条件是 repel_to_edge、且臧霸血量跌破五成时，才触发撤退
##   2) 退到地图东边缘（x = MAP_W-1）即判定达成；中途不算
##   3) 其他敌人不会被误触发

const BattleScript := preload("res://scripts/battle.gd")
const ObjectivesCore := preload("res://scripts/core/objectives.gd")
const SaveCore := preload("res://scripts/systems/save.gd")

var b: Node
var failed := 0


func _initialize() -> void:
	_run()


func _wait(x: float) -> void:
	await create_timer(x).timeout


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  ✅ " + msg)
	else:
		printerr("  ❌ " + msg)
		failed += 1


func _run() -> void:
	print("\n===== 第 4 关「打回琅琊」验收 =====")
	SaveCore.save_state(SaveCore.new_state())
	BattleScript.chapter_id = "chapter4"
	change_scene_to_file("res://scenes/battle.tscn")
	await _wait(2.5)
	b = current_scene
	await _wait(0.5)

	var zangba = b._unit_by_id("zangba")
	var changxi = b._unit_by_id("changxi")
	if zangba == null:
		printerr("[FAIL] 找不到臧霸")
		quit(1)
		return

	# 直接跳到阶段 2
	b.stage_idx = 1
	var st: Dictionary = b.stages[1]
	_check(str(st.get("win", {}).get("type", "")) == "repel_to_edge", "阶段 2 条件类型 = repel_to_edge")

	# 满血：不撤退
	zangba.hp = zangba.max_hp
	b.morale = {"player": 100, "enemy": 100}
	_check(not b._should_retreat(zangba), "满血时不撤退")
	_check(not b._should_retreat(changxi), "其他敌人不会触发撤退")

	# 跌破五成：撤退
	zangba.hp = int(zangba.max_hp * 0.45)
	_check(b._should_retreat(zangba), "血量跌破 50% → 开始撤退")

	# 边缘判定
	var ctx: Dictionary = b._build_objective_ctx()
	zangba.cell = Vector2i(9, 3)
	ctx = b._build_objective_ctx()
	_check(not ObjectivesCore.stage_cleared(st, ctx), "还在场内（x=9）→ 未达成")
	zangba.cell = Vector2i(11, 3)
	ctx = b._build_objective_ctx()
	_check(ObjectivesCore.stage_cleared(st, ctx), "退到东边缘（x=11）→ 达成")

	print("\n===== %s =====" % ("全部通过 ✅" if failed == 0 else "失败 %d 项 ❌" % failed))
	SaveCore.save_state(SaveCore.new_state())
	quit(0 if failed == 0 else 1)
