extends SceneTree
## 第 5 关「洛阳大火」验收：编成、两阶段军令、通关链路。

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")
const UnitArtCore := preload("res://scripts/ui/unit_art.gd")

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
	print("\n===== 第 5 关「洛阳大火」验收 =====")
	var s: Dictionary = SaveCore.new_state()
	s["prologues_seen"] = ["chapter1", "chapter2", "chapter3", "chapter4", "chapter5"]
	SaveCore.save_state(s)

	BattleScript.chapter_id = "chapter5"
	change_scene_to_file("res://scenes/battle.tscn")
	await _wait(2.5)
	b = current_scene
	await _wait(0.5)
	# 跳过开场对白
	var guard := 0
	while bool(b.dialog_showing) and guard < 30:
		b._on_dialog_btn_pressed()
		await _wait(0.06)
		guard += 1

	var players: Array = b._camp_units("player")
	var enemies: Array = b._camp_units("enemy")
	_check(players.size() == 6, "我方 6 人（刘关张赵 + 许褚 + 公孙瓒），实际 %d" % players.size())
	_check(enemies.size() == 5, "敌方 5 人（徐荣 + 西凉铁骑×2 + 弓手×2），实际 %d" % enemies.size())
	_check(int(b.stages.size()) == 2, "两阶段军令")
	_check(str(b.stages[0].get("win", {}).get("type", "")) == "survive_turns", "阶段 1 = 坚守 3 回合")
	_check(str(b.stages[1].get("win", {}).get("type", "")) == "defeat_commander", "阶段 2 = 击退徐荣")

	var xurong = b._unit_by_id("xurong")
	_check(xurong != null and xurong.is_commander, "徐荣是本关主将")

	# 每个上场单位都有贴图（美术覆盖率单测也会查，这里再确认一次第五关）
	var missing: Array[String] = []
	for u in players + enemies:
		if not UnitArtCore.has_art(u.id):
			missing.append(u.id)
	_check(missing.is_empty(), "第五关上场单位贴图齐全（缺：%s）" % ", ".join(PackedStringArray(missing)))

	# 阶段 1：把回合推到 3
	b.turn_state.turn = 3
	var cleared1: bool = b._check_stages()
	_check(not cleared1 and int(b.stage_idx) == 1, "坚守 3 回合 → 进入阶段 2")

	# 阶段 2：击退徐荣
	xurong.hp = 0
	xurong.alive = false
	var done: bool = b._check_stages()
	_check(done and bool(b.victory), "击退徐荣 → 通关")

	print("\n===== %s =====" % ("全部通过 ✅" if failed == 0 else "失败 %d 项 ❌" % failed))
	SaveCore.save_state(SaveCore.new_state())
	quit(0 if failed == 0 else 1)
