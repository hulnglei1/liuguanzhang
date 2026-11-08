extends SceneTree
## 友军通行规则：**可以穿过，但不能停留**。
##
## 玩家反馈：刘备/张飞站在旁边时把路堵死了，只能绕圈。
## SRPG 通行惯例就是友军可穿不可停，这里用两条断言把规则钉死。

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")
const GridCore := preload("res://scripts/core/grid.gd")

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
	print("\n===== 友军通行（可穿不可停）=====")
	var s: Dictionary = SaveCore.new_state()
	s["prologues_seen"] = ["chapter1"]
	SaveCore.save_state(s)
	BattleScript.chapter_id = "chapter1"
	change_scene_to_file("res://scenes/battle.tscn")
	await _wait(2.2)
	b = current_scene
	await _wait(0.4)
	var guard := 0
	while bool(b.dialog_showing) and guard < 40:
		b._on_dialog_btn_pressed()
		await _wait(0.05)
		guard += 1

	var lb = b._unit_by_id("liubei")
	var gy = b._unit_by_id("guanyu")
	var zf = b._unit_by_id("zhangfei")
	_check(lb != null and gy != null and zf != null, "三名主角在场")

	# 1) 友军格子算"被占用"（不能停留）
	b.selected_id = lb.id
	_check(b._cell_occupied(gy.cell), "友军所在格 = 已占用")
	_check(not b._is_in_reachable(gy.cell), "不能把移动落点选在友军身上")

	# 2) 但如果把友军当障碍，能到的格子会变少 → 说明现在确实能穿过
	var blocked_all: Array = b._blocked_cells(lb.id, "")            # 旧规则：友军也挡路
	var blocked_pass: Array = b._blocked_cells(lb.id, lb.camp)      # 新规则：友军可穿
	var reach_old: Dictionary = GridCore.reachable(lb.cell, b._get_unit_mov(lb), b.MAP_W, b.MAP_H, blocked_all)
	var reach_new: Dictionary = GridCore.reachable(lb.cell, b._get_unit_mov(lb), b.MAP_W, b.MAP_H, blocked_pass)
	print("  可移动格数：旧规则 %d → 新规则 %d" % [reach_old.size(), reach_new.size()])
	_check(reach_new.size() >= reach_old.size(), "新规则不会更窄（友军可穿）")
	_check(reach_new.size() > reach_old.size(), "新规则实际多出可达格（确实穿过去了）")

	# 3) 敌方仍然挡路
	var foe = null
	for u in b._camp_units("enemy"):
		foe = u
		break
	if foe != null:
		_check(b._cell_occupied(foe.cell, ""), "敌方所在格同样算占用（不能叠）")

	print("\n===== %s =====" % ("全部通过 ✅" if failed == 0 else "失败 %d 项 ❌" % failed))
	SaveCore.save_state(SaveCore.new_state())
	quit(0 if failed == 0 else 1)
