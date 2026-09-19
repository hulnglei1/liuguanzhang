extends SceneTree
## 复现「公孙瓒飞弹」bug 链：技能是否延迟、释放后能否再动、图标残留、卡死
## 运行：Godot_console.exe --headless --path zcode项目 --script res://tests/probe_arrow_bug.gd

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")
const GridCore := preload("res://scripts/core/grid.gd")

var b: Node


func _initialize() -> void:
	var s: Dictionary = SaveCore.load_state()
	s["chapters"] = []
	s["prologues_seen"] = ["chapter1", "chapter2", "chapter3", "chapter4"]
	SaveCore.save_state(s)
	BattleScript.chapter_id = "chapter1"
	change_scene_to_file("res://scenes/battle.tscn")
	_run()


func _wait(x: float) -> void:
	await create_timer(x).timeout


func _dist(a: Vector2i, c: Vector2i) -> int:
	return maxi(absi(a.x - c.x), absi(a.y - c.y))


func _run() -> void:
	await _wait(2.5)
	b = current_scene
	if b.has_method("_on_dialog_skip_pressed"):
		b._on_dialog_skip_pressed()
	await _wait(0.6)

	var gs = b._unit_by_id("gongsunzan")
	var dao = b._unit_by_id("dao_bing_1")
	if gs == null or dao == null:
		print("❌ 找不到公孙瓒或刀兵")
		quit(1)
		return

	print("\n==== 初始 ====")
	print("  公孙瓒 %s atk=%d | 刀兵 %s hp=%d/%d def=%d | 切比雪夫距离=%d" % [
		str(gs.cell), gs.effective_atk(), str(dao.cell), dao.hp, dao.max_hp, dao.effective_def(),
		_dist(gs.cell, dao.cell)])

	# --- 场景 A：超远距离（>3 格）放技能，应生成飞弹、不应立即掉血 ---
	print("\n==== A. 距离 5 格放技能（应生成飞弹，不该立即命中） ====")
	b.selected_id = "gongsunzan"
	var hp_before: int = dao.hp
	b._do_skill(dao.cell)
	await _wait(0.5)
	print("  刀兵 HP：%d → %d（立即掉血 %d）" % [hp_before, dao.hp, hp_before - dao.hp])
	if dao.hp < hp_before:
		print("  ❌ 飞弹未延迟：目标在 5 格外却立即受到伤害")
	else:
		print("  ✅ 未立即掉血（符合'延迟飞行'设计）")
	print("  战场飞弹数 active_arrows=%d，视觉节点 arrow_nodes=%d" % [
		int(b.active_arrows.size()), int(b.arrow_nodes.size())])
	print("  公孙瓒 acted=%s（释放技能后应为 true，不能再操作）" % str(gs.acted))
	if gs.acted:
		print("  ✅ 技能后已标记 acted")
	else:
		print("  ❌ 技能后 acted 仍为 false —— 玩家可以再选中他，这就是'还能移动'的原因")

	# --- 检查能否再次选中该单位（模拟玩家点他） ---
	var can_reselect: bool = (not gs.acted) and gs.alive
	print("  玩家能否再次操作公孙瓒：%s" % str(can_reselect))
	if can_reselect:
		print("  ❌ 可以再次操作 —— 会导致重复释放、飞弹图标叠加")
	else:
		print("  ✅ 无法再次操作（正常）")

	# --- 场景 B：贴身距离（<=3 格）放技能，设计上立即命中 ---
	print("\n==== B. 把公孙瓒移近到 3 格内再放（设计上立即命中，属正常） ====")
	gs.acted = false
	gs.cds.clear()
	gs.cell = Vector2i(dao.cell.x - 3, dao.cell.y)
	print("  移动到 %s，距离=%d" % [str(gs.cell), _dist(gs.cell, dao.cell)])
	var hp2: int = dao.hp
	b.selected_id = "gongsunzan"
	b._do_skill(dao.cell)
	await _wait(0.5)
	print("  刀兵 HP：%d → %d（掉血 %d）" % [hp2, dao.hp, hp2 - dao.hp])
	print("  说明：距离 ≤3 时立即命中是**设计如此**，不是 bug")

	# --- 场景 C：飞弹推进 3 个回合，验证命中与清理 ---
	print("\n==== C. 飞弹推进与清理（模拟多回合） ====")

	print("  推进前：active_arrows=%d" % b.active_arrows.size())
	for turn in range(5):
		b._update_homing_arrows()
		await _wait(0.3)
		print("  第 %d 次推进后：active_arrows=%d，节点=%d，刀兵 HP=%d" % [
			turn + 1, int(b.active_arrows.size()), int(b.arrow_nodes.size()), dao.hp])
		if b.active_arrows.is_empty():
			break
	if b.active_arrows.is_empty():
		print("  ✅ 飞弹最终被清理（未无限堆积）")
	else:
		print("  ❌ 飞弹残留 %d 个，未清理" % b.active_arrows.size())

	# --- 场景 D：目标提前死亡时飞弹应消散 ---
	print("\n==== D. 目标阵亡后飞弹应消散 ====")
	var dao2 = b._unit_by_id("dao_bing_2")
	if dao2:
		gs.acted = false
		gs.cds.clear()
		gs.cell = Vector2i(dao2.cell.x - 5, dao2.cell.y)
		b.selected_id = "gongsunzan"
		b._do_skill(dao2.cell)
		await _wait(0.3)
		var n_before: int = int(b.active_arrows.size())
		dao2.hp = 0
		dao2.alive = false
		b._update_homing_arrows()
		await _wait(0.3)
		print("  目标阵亡前飞弹=%d，之后=%d" % [n_before, b.active_arrows.size()])
		if b.active_arrows.size() < n_before:
			print("  ✅ 失去目标的飞弹已消散")
		else:
			print("  ⚠ 飞弹未消散（可能仍占位）")

	# --- 场景 E：残留 UI 节点检查 ---
	print("\n==== E. 视觉残留检查 ====")
	print("  飞弹视觉节点残留：%d（应为 0）" % b.arrow_nodes.size())
	if b.arrow_nodes.size() == 0:
		print("  ✅ 无残留图标")
	else:
		print("  ❌ 有 %d 个图标残留在场上" % b.arrow_nodes.size())

	print("\n==== 复现结束 ====")
	SaveCore.save_state(SaveCore.new_state())
	quit(0)
