extends SceneTree
## 两项验收：
##   1. 五关序章数据齐全（漏一章 = 玩家进关前没有背景交代，笑点全落空）
##   2. 武安国第 3 回合"被吕布打飞"后要**真的退场**，而不是满血站在那里还能操作

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")

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
	print("\n===== 序章数据 & 武安国退场 验收 =====")

	# ---------- 1. 序章数据 ----------
	print("\n[1] 序章数据完整性")
	for ch in ["chapter1", "chapter2", "chapter3", "chapter4", "chapter5"]:
		var p := "res://data/prologues/%s.json" % ch
		if not FileAccess.file_exists(p):
			_check(false, "%s 缺少序章数据" % ch)
			continue
		var f := FileAccess.open(p, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(d) != TYPE_DICTIONARY:
			_check(false, "%s 序章 JSON 解析失败" % ch)
			continue
		var card: Dictionary = d.get("title_card", {})
		var lines: Array = d.get("opening", [])
		_check(not str(card.get("name", "")).is_empty() and lines.size() >= 8,
			"%s 序章齐备（%d 行，卡面「%s」）" % [ch, lines.size(), str(card.get("name", ""))])

	# ---------- 2. 武安国退场 ----------
	print("\n[2] 武安国重伤退场")
	var s: Dictionary = SaveCore.new_state()
	s["prologues_seen"] = ["chapter1", "chapter2", "chapter3", "chapter4", "chapter5"]
	SaveCore.save_state(s)

	BattleScript.chapter_id = "chapter2"
	change_scene_to_file("res://scenes/battle.tscn")
	await _wait(2.2)
	var b: Node = current_scene
	await _wait(0.4)
	var guard := 0
	while bool(b.dialog_showing) and guard < 40:
		b._on_dialog_btn_pressed()
		await _wait(0.05)
		guard += 1

	var wa = b._unit_by_id("wuanguo")
	if wa == null:
		printerr("[FAIL] 第 2 关找不到武安国")
		quit(1)
		return

	_check(wa.alive, "出场时武安国在世（编成里有人）")
	var before: int = b._camp_units("player").size()

	b._apply_event_effect({"kind": "retire_unit", "target": "wuanguo"})
	await _wait(0.3)

	_check(not wa.alive, "被打飞后 alive = false（不再参战）")
	var after: int = b._camp_units("player").size()
	_check(after == before - 1, "我方在列人数 -1（%d → %d）" % [before, after])
	_check(wa.hp >= 1, "保留 1 点血（剧情上是重伤，不是战死）")

	print("\n===== %s =====" % ("全部通过 ✅" if failed == 0 else "失败 %d 项 ❌" % failed))
	SaveCore.save_state(SaveCore.new_state())
	quit(0 if failed == 0 else 1)
