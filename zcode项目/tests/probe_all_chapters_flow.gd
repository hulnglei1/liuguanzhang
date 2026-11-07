extends SceneTree
## 全关卡通关链路：逐一加载 chapter2~5，按每个阶段的 win 类型把状态推到达成，
## 断言"每一关都能从阶段 1 走到 victory"。
##
## 这不是替代真人试玩，而是保证**数据/条件引擎**这一层没有死路：
## 新加关卡或改军令时，任何条件类型写错都会在这里立刻暴露。

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")

const CHAPTERS := ["chapter2", "chapter3", "chapter4", "chapter5"]

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


## 把当前阶段的条件强行推到达成，返回是否成功
func _force_stage(b: Node, stage: Dictionary) -> bool:
	var win: Dictionary = stage.get("win", {})
	match str(win.get("type", "")):
		"survive_turns":
			b.turn_state.turn = int(win.get("value", 1))
			return true
		"break_gate":
			b.gate_broken = true
			return true
		"kill_all":
			for u in b._camp_units("enemy"):
				u.hp = 0
				u.alive = false
			return true
		"kill_minions":
			for u in b._camp_units("enemy"):
				if not u.is_commander:
					u.hp = 0
					u.alive = false
			return true
		"kill_target":
			var t1 = b._unit_by_id(str(win.get("target", "")))
			if t1 == null:
				return false
			t1.hp = 0
			t1.alive = false
			return true
		"recruit_at_hp":
			var t2 = b._unit_by_id(str(win.get("target", "")))
			if t2 == null:
				return false
			t2.hp = int(float(t2.max_hp) * float(win.get("ratio", 0.3)))
			return true
		"repel_to_edge":
			var t3 = b._unit_by_id(str(win.get("target", "")))
			if t3 == null:
				return false
			var edge: String = str(win.get("edge", "east"))
			match edge:
				"east":
					t3.cell = Vector2i(b.MAP_W - 1, t3.cell.y)
				"west":
					t3.cell = Vector2i(0, t3.cell.y)
				"south":
					t3.cell = Vector2i(t3.cell.x, b.MAP_H - 1)
				"north":
					t3.cell = Vector2i(t3.cell.x, 0)
			return true
		"kill_commander", "defeat_commander":
			var c = b._enemy_commander()
			if c == null:
				return false
			c.hp = 0
			c.alive = false
			return true
	return false


func _run() -> void:
	print("\n===== 全关卡通关链路（chapter2-5）=====")
	for ch in CHAPTERS:
		var s: Dictionary = SaveCore.new_state()
		s["prologues_seen"] = ["chapter1", "chapter2", "chapter3", "chapter4", "chapter5"]
		SaveCore.save_state(s)

		BattleScript.chapter_id = ch
		change_scene_to_file("res://scenes/battle.tscn")
		await _wait(2.2)
		var b: Node = current_scene
		await _wait(0.4)
		var guard := 0
		while bool(b.dialog_showing) and guard < 30:
			b._on_dialog_btn_pressed()
			await _wait(0.05)
			guard += 1

		print("\n[%s] %s（%d 阶段）" % [ch, str(b.chapter.get("title", "")), b.stages.size()])
		_check(b.stages.size() >= 1, "有军令定义")

		var guard2 := 0
		while not bool(b.victory) and guard2 < 10:
			guard2 += 1
			var idx: int = int(b.stage_idx)
			var st: Dictionary = b.stages[clampi(idx, 0, b.stages.size() - 1)]
			var wtype: String = str(st.get("win", {}).get("type", ""))
			var ok: bool = _force_stage(b, st)
			if not ok:
				_check(false, "阶段 %d 条件类型无法驱动：%s" % [idx + 1, wtype])
				break
			b._check_stages()
			await _wait(0.15)
			print("    阶段 %d [%s] → stage_idx=%d victory=%s" % [idx + 1, wtype, int(b.stage_idx), str(b.victory)])

		_check(bool(b.victory), "%s 走到通关" % ch)

	print("\n===== %s =====" % ("全部通过 ✅" if failed == 0 else "失败 %d 项 ❌" % failed))
	SaveCore.save_state(SaveCore.new_state())
	quit(0 if failed == 0 else 1)
